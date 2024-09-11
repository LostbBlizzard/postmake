local build = {}

local shellscript = postmake.loadplugin("internal/shellscript")

local AllowedSettingsFields = {
	"weburl",
	"uploaddir"
}

local programinstalldir = ""
local function resolveoutputpath(path)
	return programinstalldir .. path
end

local indent = "    "
local indent2 = indent .. indent

local function flagtovarable(flagname)
	return "flag_" .. flagname:gsub(" ", "_")
end
local function ostoosvarable(osname)
	if osname == "windows" then
		return "IsWin"
	elseif osname == "linux" then
		return "isLinux"
	elseif osname == "macos" then
		return "isMac"
	else
		print("error unknown os '" .. osname .. "'")
		os.exit(1)
	end
end
local function archtonodearch(arch)
	if arch == "x64" then
		return "x64"
	elseif arch == "x32" then
		return "x32"
	elseif arch == "arm64" then
		return "arm64"
	else
		print("error unknown arch '" .. arch .. "'")
		os.exit(1)
	end
end
local function onconfig(myindent, outputfile, config, weburl, uploaddir, uploadfilecontext)
	for input, output in pairs(config.files) do
		local newout = resolveoutputpath(output)

		local newfilename = shellscript.GetUploadfilePath(input, uploadfilecontext, function(input, newfilename)
			if uploaddir ~= nil then
				postmake.os.cp(input, uploaddir .. newfilename)
			end
		end)

		outputfile:write(myindent ..
			"downloadfile(\"" .. weburl .. "/" .. newfilename .. "\",\"" .. newout .. "\");\n\n")
	end

	for _, output in pairs(config.paths) do
		outputfile:write(myindent .. "addpath(\"" .. resolveoutputpath(output) .. "\");\n")
	end
end

function build.make(postmake, configs, settings)
	-- boring checks
	if settings.weburl == nil then
		print("error settings must have the 'weburl' field set")
		os.exit(1)
	end
	local goterrorinsettings = false
	for key, _ in pairs(settings) do
		local issettingallowed = false

		for _, field in ipairs(AllowedSettingsFields) do
			if key == field then
				issettingallowed = true
				break
			end
		end

		if issettingallowed then
			goto continue
		end
		print("The Key '" .. key .. "' is not an  valid Shellscript Settins. Typo?\n")
		goterrorinsettings = true
		::continue::
	end
	if goterrorinsettings then
		print("Shellscript only allows for ")
		for i, field in ipairs(AllowedSettingsFields) do
			print(field)

			if i ~= #AllowedSettingsFields then
				print(",")
			end
		end
		print(" to be in the setting")
		os.exit(1)
	end

	local outputpathdir = "./" .. postmake.output() .. "/githubaction/"
	print("---building github action to " .. outputpathdir)

	programinstalldir = postmake.appinstalldir();

	local weburl = settings.weburl
	local uploaddir = settings.uploaddir

	postmake.os.mkdirall(outputpathdir)

	local indexjsfilepath = outputpathdir .. "index.js"
	local indexfile = io.open(indexjsfilepath, "w")

	if indexfile == nil then
		print("unable to open file '" .. indexjsfilepath .. "'")
		os.exit(1)
	end

	local hasfiles = true
	local haspath = true

	for _, config in ipairs(configs) do
		if #config.paths ~= 0 then
			haspath = true
		end
		if #config.files ~= 0 then
			hasfiles = true
		end
		for _, subconfig in ipairs(config.ifs) do
			if #subconfig.paths ~= 0 then
				haspath = true
			end
			if #subconfig.files ~= 0 then
				hasfiles = true
			end
		end
	end

	indexfile:write("const core = require('@actions/core');\n")
	indexfile:write("const github = require('@actions/github');\n")

	if hasfiles then
		indexfile:write("const { execSync } = require(\"child_process\");\n")
	end

	indexfile:write("var isWin = process.platform === \"win32\";\n")
	indexfile:write("var isLinux = process.platform === \"linux\";\n")
	indexfile:write("var isMac = process.platform === \"darwin\";\n")
	indexfile:write("var isUnix = isLinux || isMac;\n\n")

	if hasfiles then
		indexfile:write("\nfunction downloadfile(url, outputfile) {\n")
		indexfile:write(indent .. "var command = \"curl -L \" + url + \" -o \" + outputfile\n")

		indexfile:write(indent .. "if (isUnix) {\n")
		indexfile:write(indent2 .. "       command = \"curl -L \" + url + \" -o \" + outputfile\n")
		indexfile:write(indent .. "else {\n")
		indexfile:write(indent2 .. "       command = \"curl.exe -L \" + url + \" -o \" + outputfile\n")
		indexfile:write(indent .. "}\n")

		indexfile:write(indent .. "child = execSync(command, null)\n")
		indexfile:write("}\n")
	end

	if haspath then
		indexfile:write("\nfunction addpath(path) {\n")
		indexfile:write(indent .. "core.addPath(path);\n")
		indexfile:write("}\n")
	end

	local uploadfilecontext = {}

	indexfile:write("\n\n")
	for configindex, config in ipairs(configs) do
		if configindex == 1 then
			indexfile:write("if ")
		else
			indexfile:write("else if ")
		end

		indexfile:write("(" .. ostoosvarable(config.os()))
		indexfile:write(" && process.arch == \"" .. archtonodearch(config.arch()) .. "\"")
		indexfile:write(") {\n")
		onconfig(indent, indexfile, config, weburl, uploaddir, uploadfilecontext)

		for _, output in ipairs(config.ifs) do
			local isfirstiniflistloop = true

			for _, output2 in ipairs(output.iflist) do
				if not isfirstiniflistloop then
					indexfile:write(" &&")
				else
					indexfile:write(indent .. "if (")
				end

				if output2.isflag() then
					indexfile:write(flagtovarable(output2.flagname()))
				else
					indexfile:write(flagtovarable(output2.flagname()) ..
						"\" == \"" .. output2.value() .. "\" ] ")
				end

				isfirstiniflistloop = false
			end
			indexfile:write(") {\n")

			onconfig(indent2, indexfile, output, weburl, uploaddir, uploadfilecontext)

			indexfile:write(indent .. "}\n\n")
		end
		indexfile:write("}\n")
	end
	indexfile:write("else {\n")
	indexfile:write(indent .. "console.log(This Program has cant be Installed on this system);\n")
	indexfile:write(indent .. "process.exit(1)\n")
	indexfile:write("}\n")
	indexfile:close()
end

return build

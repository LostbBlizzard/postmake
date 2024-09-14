local build = {}


local function resolveoutputpath(path)
	return "$Installdir" .. path
end

local function ostounname(oosname)
	if oosname == "linux" then
		return "Linux"
	elseif oosname == "macos" then
		return "Darwin"
	else
		print("unable convert '" .. oosname .. "' to then unix uname string")
		os.exit(1)
	end
end

local function archtounname(archtype)
	if archtype == "x64" then
		return "x86_64"
	elseif archtype == "x32" then
		return "x86_32"
	elseif archtype == "arm64" then
		return "arm64"
	else
		print("unable convert '" .. archtype .. "' to then unix uname machine type string")
		os.exit(1)
	end
end

local function stringtoshellsrciptvarable(varablename)
	return "var" .. varablename:gsub(" ", "_")
end

local function booltoyesorno(bool)
	if bool then
		return "yes"
	else
		return "no"
	end
end

local AllowedSettingsFields =
{
	"weburl",
	"uploaddir"
}

local function has_value_map(tab, val)
	for _, value in pairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end
local function has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end
local function has_key_map(tab, val)
	for key, _ in pairs(tab) do
		if key == val then
			return true
		end
	end

	return false
end

local function get_file_name(file)
	return file:match("^.+/(.+)$")
end

local function GetUploadfilePath(input, uploadfilecontext, onadded)
	local newfilename = ""
	if not has_key_map(uploadfilecontext, input) then
		newfilename = input
		if has_value_map(uploadfilecontext, newfilename) then
			newfilename = input .. "1"
		end

		newfilename = get_file_name(newfilename)
		uploadfilecontext[input] = newfilename

		if onadded ~= nil then
			onadded(input, newfilename)
		end
	else
		newfilename = get_file_name(uploadfilecontext[input])
	end
	return newfilename
end
local function onconfig(outputfile, config, weburl, uploaddir, uploadfilecontext)
	for inputtable, output in pairs(config.files) do
		local input = inputtable.string

		if postmake.match.isbasicmatch(input) then
			local newout = resolveoutputpath(output)

			local newfilename = GetUploadfilePath(input, uploadfilecontext, function(input, newfilename)
				if uploaddir ~= nil then
					postmake.os.cp(input, uploaddir .. newfilename)
				end
			end)


			outputfile:write("curl -LJ " .. weburl .. "/" .. newfilename .. " -o " .. newout .. "\n\n")
		else
			local basepath = postmake.match.getbasepath(input)

			local dirname = string.sub(basepath, 0, #basepath - 1)
			local basezippath = dirname .. ".tar.gz"

			local newout = GetUploadfilePath(basezippath, uploadfilecontext, nil)

			local files = {}

			postmake.match.matchpath(input, function(path)
				local zippath = string.sub(path, #basepath - 1, #path)

				files[path] = zippath
			end)

			if uploaddir ~= nil then
				postmake.archive.make_tar_gx(files, uploaddir .. newout)
			end


			local resolvenewout = resolveoutputpath(output)
			outputfile:write("curl -LJ " ..
				weburl .. "/" .. newout .. " -o " .. resolveoutputpath("/" .. newout) .. "\n")
			outputfile:write("tar -xvzf " ..
			resolveoutputpath("/" .. newout) .. " -C " .. resolveoutputpath(output) .. "\n\n")
		end
	end

	for _, output in pairs(config.paths) do
		outputfile:write("AddPath " .. resolveoutputpath(output) .. " \n")
	end
end

function build.GetUploadfilePath(input, uploadfilecontext, onadded)
	return GetUploadfilePath(input, uploadfilecontext, onadded)
end

function build.make(postmake, configs, settings)
	print("---building shell script")

	--- Boring checks
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


	--- passed in settings
	local weburl = settings.weburl
	local uploaddir = settings.uploaddir

	local outputpath = "./" .. postmake.output() .. ".sh"

	local haspathvarables = false
	local hasflags = false
	local hasenums = false
	for _, config in ipairs(configs) do
		if #config.paths ~= 0 then
			haspathvarables = true
		end

		if #config.flags ~= 0 then
			hasflags = true
		end

		if #config.enumflags ~= 0 then
			hasenums = true
		end


		for _, subconfig in ipairs(config.ifs) do
			if #subconfig.paths ~= 0 then
				haspathvarables = true
			end
			if #subconfig.flags ~= 0 then
				hasflags = true
			end
			if #subconfig.enumflags ~= 0 then
				hasenums = true
			end
		end
	end

	print("writing install file to " .. outputpath)


	local outputfile = io.open(outputpath, "w")
	if outputfile == nil then
		print("unable to open file '" .. outputpath .. "'")
		os.exit(1)
	end

	outputfile:write("#!/usr/bin/env bash\n")
	outputfile:write("set -e\n")

	outputfile:write("\n\n# Script generated by the PostMake Shellscript Plugin.\n")

	outputfile:write("\n\n")


	outputfile:write("Installdir=\"$HOME/." .. postmake.appinstalldir() .. "\" \n")

	outputfile:write("\n")

	outputfile:write("mkdir -p \"$Installdir\" \n")

	if haspathvarables then
		outputfile:write("\nAddPath () {\n")
		outputfile:write("echo trying $1 to PATH\n")
		outputfile:write("}\n\n")
	end

	if hasflags then
		outputfile:write("\nCheckInputYesOrNo () {\n")
		outputfile:write("if [ \"$1\" == \"\" ] \nthen \n\n")
		outputfile:write("echo $2\n\n")
		outputfile:write("elif [ \"$1\" == \"y\" ] || [ \"$1\" == \"yes\" ] \nthen \n\n")
		outputfile:write("echo true\n\n")
		outputfile:write("elif [ \"$1\" == \"n\" ] || [ \"$1\" == \"no\" ] \nthen \n\n")
		outputfile:write("echo false\n\n")
		outputfile:write("else \n\n")
		outputfile:write("echo \"wanted [y]es or [n]o but got '$1' \" > /dev/tty\n")
		outputfile:write("exit 1\n\n")
		outputfile:write("fi\n")
		outputfile:write("}\n\n")
	end

	if hasenums then
		outputfile:write("\nCheckArray () {\n\n")

		outputfile:write("if [ \"$1\" == \"\" ] \nthen \n\n")
		outputfile:write("echo $2\n")
		outputfile:write("exit 0 \n")
		outputfile:write("fi\n")

		outputfile:write("arr=\"$3\" \n")
		outputfile:write("INDEX=1\n")

		outputfile:write("for i in \"${arr[@]}\" \n")
		outputfile:write("do \n")


		outputfile:write("if [ \"$i\" == \"$1\" ] || [ \"$INDEX\" == \"$1\" ]  \nthen \n\n")

		outputfile:write("echo $i\n")
		outputfile:write("exit 0\n")

		outputfile:write("fi\n")

		outputfile:write("let INDEX=${INDEX}+1\n")
		outputfile:write("done \n")

		outputfile:write("echo \"Error: Wanted one of \" > /dev/tty\n")
		outputfile:write("for i in \"${arr[@]}\" \n")
		outputfile:write("do \n")
		outputfile:write("echo \"$i\" > /dev/tty\n")
		outputfile:write("done \n")

		outputfile:write("echo \n")
		outputfile:write("echo \"or the maped number \" > /dev/tty\n")

		outputfile:write("exit 1\n\n")

		outputfile:write("}\n\n")
	end

	if uploaddir ~= nil then
		postmake.os.mkdirall(uploaddir)
	end

	outputfile:write("\n")


	for configindex, config in ipairs(configs) do
		local islast = configindex == #configs


		if config.os() == "windows" then
			print("error cant use config with os set the windows")
			os.exit(1)
		end

		if configindex ~= 0 then
			outputfile:write("\n")
			outputfile:write("if ")
		end
		outputfile:write(" [ \"$(uname)\" = \"" ..
			ostounname(config.os()) ..
			"\" ] && [ \"$(uname -p)\" = \"" .. archtounname(config.arch()) .. "\" ]; \nthen\n")

		outputfile:write("\n")

		if #config.flags ~= 0 then
			outputfile:write("echo Press enter or type nothing for default\n")
			outputfile:write("echo\n")
		end

		for _, flag in ipairs(config.flags) do
			outputfile:write("userinput=\"\"\n")
			outputfile:write("read -p \"" ..
				flag.flagname() ..
				" [y/n] default is " ..
				booltoyesorno(flag.defaultvalue()) .. ":\" userinput\n")

			outputfile:write(stringtoshellsrciptvarable(flag.flagname()) ..
				"=$(CheckInputYesOrNo \"$userinput\" " .. tostring(flag.defaultvalue()) .. ")\n")
		end

		for _, enumflag in ipairs(config.enumflags) do
			outputfile:write("userinput=\"\" \n")
			outputfile:write("echo Options for \"" ..
				enumflag.flagname() .. "\"\n")

			outputfile:write("echo \n")
			outputfile:write("\n")
			for i, value in ipairs(enumflag.values()) do
				outputfile:write("echo \"" .. value .. " " .. tostring(i) .. ") \"\n")
			end

			outputfile:write("echo \n")
			outputfile:write("echo \"Default is " .. enumflag.defaultvalue() .. ") \"\n")
			outputfile:write("echo \n")

			outputfile:write("read -p \"" .. enumflag.flagname() .. ":\" " .. "userinput \n")

			outputfile:write("arr=")
			outputfile:write("(")

			local first = false
			for _, value in ipairs(enumflag.values()) do
				if first == true then
					outputfile:write(" ")
				end
				outputfile:write("\"" .. value .. "\"")

				first = true
			end

			outputfile:write(")\n")

			outputfile:write(stringtoshellsrciptvarable(enumflag.flagname()) ..
				"=$(CheckArray \"$userinput\" ")
			outputfile:write("\"" .. tostring(enumflag.defaultvalue()) .. "\"")
			outputfile:write(" $arr)\n")
		end

		outputfile:write("\n")

		local uploadfilecontext = {}

		onconfig(outputfile, config, weburl, uploaddir, uploadfilecontext)

		for _, output in ipairs(config.ifs) do
			local isfirstiniflistloop = true

			for _, output2 in ipairs(output.iflist) do
				if not isfirstiniflistloop then
					outputfile:write(" &&")
				else
					outputfile:write("if")
				end

				if output2.isflag() then
					outputfile:write(" [ \"$" ..
						stringtoshellsrciptvarable(output2.flagname()) ..
						"\" == " .. output2.value() .. " ] ")
				else
					outputfile:write(" [ \"$" ..
						stringtoshellsrciptvarable(output2.flagname()) ..
						"\" == \"" .. output2.value() .. "\" ] ")
				end

				isfirstiniflistloop = false
			end
			outputfile:write("\nthen\n\n")

			onconfig(outputfile, output, weburl, uploaddir, uploadfilecontext)

			outputfile:write("\nfi\n\n")
		end

		if not islast then
			outputfile:write("elif")
		end
	end
	outputfile:write("else\n\n")
	outputfile:write("echo \"Unable to Install '" ..
		postmake.appname() .. "' There is no configuration for your system\"\n")
	outputfile:write("exit 1\n\n")
	outputfile:write("fi\n\n")

	outputfile:close()
end

return build

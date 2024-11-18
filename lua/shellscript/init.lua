local build = {}

local modern_syle_progress_barmax = 23

---@param path string
---@return string
local function resolveoutputpath(path)
	return "$Installdir" .. path
end

---@param compressiontype shellscriptcompressiontype
local function getzipext(compressiontype)
	if compressiontype == 'tar.gz' then
		return ".tar.gz"
	elseif compressiontype == 'zip' then
		return ".zip"
	end
end

---@param compressiontype shellscriptcompressiontype
---@param outfile string
---@param dirout  string
local function makeunzipcmd(compressiontype, outfile, dirout)
	if compressiontype == 'tar.gz' then
		return "tar -xzf " .. outfile .. " -C " .. dirout .. "\n"
	elseif compressiontype == 'zip' then
		return "unzip -q " .. outfile .. " -d " .. dirout .. "\n"
	end
end

---@param inputfiles { [string]: string }
---@param output string
local function archive(compressiontype, inputfiles, output)
	if compressiontype == "tar.gz" then
		postmake.archive.make_tar_gz(inputfiles, output)
	elseif compressiontype == "zip" then
		postmake.archive.make_zip(inputfiles, output)
	end
end

---@param path string
---@return string
local function resolveoutputpathforinstalldir(path)
	local r = path:gsub("~/", "$HOME/")
	return r
end

---@param oosname ostype
---@return string
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

---@param archtype archtype
---@return string
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

---@param varablename archtype
---@return string
local function stringtoshellsrciptvarable(varablename)
	return "var" .. varablename:gsub(" ", "_")
end

---@param bool boolean
---@return string
local function booltoyesorno(bool)
	if bool then
		return "yes"
	else
		return "no"
	end
end

---@type string[]
local AllowedSettingsFields =
{
	"weburl",
	"uploaddir",
	"uninstallfile",
	"proxy",
	"testmode",
	"singlefile",
	"style",
	"compressiontype",
	"dependencies",
}


local has_value_map = postmake.lua.has_value_map
local has_value = postmake.lua.has_value
local has_key_map = postmake.lua.has_key_map
local shallow_copy = postmake.lua.shallow_copy

local asserttype = postmake.lua.asserttype
local assertnullabletype = postmake.lua.assertnullabletype
-- local ssertenum = postmake.lua.assertenum
local assertnullablenum = postmake.lua.assertnullablenum
local assertpathmustnothaveslash = postmake.lua.assertpathmustnothaveslash

---@param input string
---@param uploadfilecontext { [string]: string }
---@param onadded fun(input : string,newfilename:string)?
---@return string
local function GetUploadfilePath(input, uploadfilecontext, onadded)
	local newfilename = ""

	if not has_key_map(uploadfilecontext, input) then
		newfilename = postmake.path.getfilename(input)
		uploadfilecontext[input] = newfilename

		if onadded ~= nil then
			onadded(input, newfilename)
		end
	else
		newfilename = postmake.path.getfilename(uploadfilecontext[input])
	end
	return newfilename
end


---@param outputfile file*
---@param cmd plugincmd
local function writecomds(outputfile, cmd)
	local function ispath(path)
		return string.find(path, "/", nil, true) or string.find(path, ".", nil, true)
	end

	local stringtowrite = ""

	if ispath(cmd.cmd()) then
		stringtowrite = stringtowrite .. resolveoutputpath(cmd.cmd())
	else
		stringtowrite = stringtowrite .. cmd.cmd()
	end

	for _, value in ipairs(cmd.pars()) do
		stringtowrite = stringtowrite .. " "
		if ispath(value) then
			stringtowrite = stringtowrite .. resolveoutputpath(value)
		else
			stringtowrite = stringtowrite .. value
		end
	end

	outputfile:write(stringtowrite)
end

---@param outputfile file*
---@param config pluginconfig | subconfig
---@param weburl string
---@param uploaddir string
---@param uninstallfile string?
---@param testmode boolean
---@param uploadfilecontext any
---@param compressiontype shellscriptcompressiontype
---@param singlefile string?
---@param dirspit string
local function onconfig(outputfile, config, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext,
			compressiontype, singlefile, dirspit)
	---@type { archivepath: string, files: string[] }[]
	local archivestomake = {}

	local archivefiles = {}

	local singledir
	if singlefile then
		singledir = uploaddir .. singlefile
	end

	for inputtable, output in pairs(config.files) do
		local input = inputtable.string()

		if postmake.match.isbasicmatch(input) then
			local newout = resolveoutputpath(output)

			local newfilename = GetUploadfilePath(input, uploadfilecontext, function(input2, newfilename)
				if singlefile ~= nil then
					local filepathtostore = singledir .. "/" .. dirspit .. output
					postmake.os.mkdirall(postmake.path.getparent(filepathtostore))
					postmake.os.cp(input2, filepathtostore)
				elseif uploaddir ~= nil then
					postmake.os.cp(input2, uploaddir .. newfilename)
				end
			end)

			if singlefile == nil then
				if testmode then
					outputfile:write("echo 'Copying " .. postmake.path.getfilename(newout) .. "'\n")
					outputfile:write("cp " .. input .. " " .. newout .. "\n")
				else
					outputfile:write("echo 'Downloading " ..
						postmake.path.getfilename(newout) .. "'\n")
					outputfile:write("curl -sSLJ " ..
						weburl .. "/" .. newfilename .. " -o " .. newout .. "\n")
				end
			else
				outputfile:write("echo 'moveing " .. postmake.path.getfilename(newout) .. "'\n")
				outputfile:write("mv " ..
					resolveoutputpath("/" .. singlefile) ..
					"/" .. dirspit .. output .. " " .. newout .. "\n")
			end

			if inputtable.isexecutable() then
				outputfile:write("chmod +x " .. newout .. "\n")
			end

			if uninstallfile then
				outputfile:write("ADDEDFILES+=(\"" .. newout .. "\")\n")
			end
			outputfile:write("\n")
		else
			local basepath = postmake.path.absolute(postmake.match.getbasepath(input))

			-- local dirname = string.sub(basepath, 0, #basepath - 1)
			local basezippath = basepath .. getzipext(compressiontype)

			local newout = GetUploadfilePath(basezippath, uploadfilecontext, nil)

			local pathforarchive = newout
			if singlefile ~= nil then
				pathforarchive = output .. getzipext(compressiontype)
			end

			local myarchive
			for _, value in ipairs(archivestomake) do
				if value.archivepath == pathforarchive then
					myarchive = value
					break
				end
			end

			local isfirst = false
			if myarchive == nil then
				myarchive = {
					archivepath = newout,
					files = {}
				}
				if singlefile ~= nil then
					myarchive.archivepath = output .. getzipext(compressiontype)
				end


				table.insert(archivestomake, myarchive)
				isfirst = true
			end

			postmake.match.matchpath(input, function(path)
				local fullpath = postmake.path.absolute(path)
				local zippath = string.sub(fullpath, #basepath + 2, #fullpath)

				myarchive.files[path] = zippath
			end)

			if isfirst then
				local resolvenewout = resolveoutputpath("/" .. newout)

				if singlefile ~= nil then
					outputfile:write("echo 'Unziping " .. newout .. "'\n")

					local ext = "." .. compressiontype
					local file = singledir .. "/" .. dirspit .. output .. ext
					local dirout = resolveoutputpath(output)

					outputfile:write(makeunzipcmd(compressiontype, file, dirout) .. "\n")
				else
					if testmode then
						outputfile:write("echo 'Copying " .. newout .. "'\n")
						outputfile:write("cp " ..
							uploaddir .. newout .. " " .. resolvenewout .. "\n\n")
					else
						outputfile:write("echo 'Downloading " .. newout .. "'\n")
						outputfile:write("curl -sSLJ " ..
							weburl .. "/" .. newout .. " -o " .. resolvenewout .. "\n\n")
					end

					outputfile:write("echo 'Unziping " .. newout .. "'\n")

					outputfile:write(makeunzipcmd(compressiontype, resolvenewout,
						resolveoutputpath(output)) .. "\n")

					outputfile:write("rm -rf " .. resolvenewout .. "\n\n")
				end
			end

			if uninstallfile then
				local hasallinlist = true
				local base = resolveoutputpath(output)

				for _, value in pairs(myarchive.files) do
					local inlist = false

					local val = base .. "/" .. value
					for _, file in ipairs(archivefiles) do
						if val == file then
							inlist = true
							break
						end
					end

					if inlist == false then
						hasallinlist = false
						break
					end
				end

				if hasallinlist == false then
					for _, value in pairs(myarchive.files) do
						local inlist = false
						local val = base .. "/" .. value

						for _, file in ipairs(archivefiles) do
							if val == file then
								inlist = true
								break
							end
						end

						if not inlist then
							table.insert(archivefiles, val)

							outputfile:write("ADDEDFILES+=(\"")
							outputfile:write(val)
							outputfile:write("\")\n")
						end
					end
				end
			end
		end
	end

	for _, output in pairs(config.paths) do
		outputfile:write("AddPath " .. resolveoutputpath(output) .. " \n")

		if uninstallfile then
			outputfile:write("ADDEDPATHS+=('" .. resolveoutputpath(output) .. "')\n")
		end
	end

	for _, cmd in ipairs(config.installcmds) do
		writecomds(outputfile, cmd)
		outputfile:write("\n")
	end


	if uninstallfile then
		for _, cmd in ipairs(config.uninstallcmds) do
			outputfile:write("ADDEDUNINSTALLCMDS+=(\"")
			writecomds(outputfile, cmd)
			outputfile:write("\")\n")
		end
	end

	if uploaddir ~= nil then
		for _, value in ipairs(archivestomake) do
			local outpath = ""

			if singlefile then
				outpath = singledir .. "/" .. dirspit .. "/" .. value.archivepath

				local parent = postmake.path.getparent(outpath);
				if not postmake.os.exist(parent) then
					postmake.os.mkdirall(parent)
				end
			else
				outpath = uploaddir .. value.archivepath
			end

			archive(compressiontype, value.files, outpath)
		end
	end
end

function build.GetUploadfilePath(input, uploadfilecontext, onadded)
	return GetUploadfilePath(input, uploadfilecontext, onadded)
end

---@param postmake pluginpostmake
---@param configs pluginconfig[]
---@param settings ShellScriptConfig
function build.make(postmake, configs, settings)
	print("---building shell script")

	--- Boring checks
	if settings.weburl == nil then
		print("error settings must have the 'weburl' field set")
		os.exit(1)
	end
	if settings.uninstallfile == nil then
		if settings.proxy ~= nil then
			print("to use 'proxy' on settings. uninstallfile field must be set")
			os.exit(1)
		end
	end
	if settings.proxy ~= nil then
		if settings.proxy.uninstallcmd == nil then
			print("proxy setting is missing the uninstallcmd field")
		end
		if settings.proxy.program == nil then
			print("proxy setting is missing the program field")
		end

		if settings.proxy.uninstallcmd == nil or settings.proxy.program == nil then
			os.exit(1)
		end
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


	assertnullabletype(settings.weburl, "settings.weburl", "string")
	assertnullabletype(settings.uploaddir, "settings.uploaddir", "string")
	assertnullabletype(settings.singlefile, "settings.singlefile", "string")
	assertnullabletype(settings.uninstallfile, "settings.uninstallfile", "string")
	if settings.proxy ~= nil then
		asserttype(settings.proxy.program, "settings.proxy.program", "string")
		asserttype(settings.proxy.uninstallcmd, "settings.proxy.program", "string")
	end
	assertnullablenum(settings.style, "settings.style", { "classic", "modern", "hypermodern" })
	assertnullablenum(settings.compressiontype, "settings.style", { "zip", "tar.gz" })

	assertpathmustnothaveslash(postmake.appinstalldir(), "postmake.appinstalldir")
	assertpathmustnothaveslash(settings.uploaddir, "settings.uploaddir")
	--- passed in settings
	local weburl = settings.weburl
	local uploaddir = settings.uploaddir
	local uninstallfile = settings.uninstallfile
	local proxy = settings.proxy
	local singlefile = settings.singlefile
	local testmode = false
	local style = settings.style
	local compressiontype = settings.compressiontype
	if style == nil then
		style = 'classic'
	end
	if compressiontype == nil then
		compressiontype = "tar.gz"
	end


	if style == 'hypermodern' then
		print("Style hypermodern has not be been added yet.")
		os.exit(1)
	end


	if settings.testmode then
		testmode = true
	end

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


	outputfile:write("Installdir=\"" .. resolveoutputpathforinstalldir(postmake.appinstalldir()) .. "\" \n")

	outputfile:write("\n\n")


	if uninstallfile then
		outputfile:write("ADDEDFILES=()\n")
		outputfile:write("ADDEDMATCHS=()\n")
		outputfile:write("ADDEDDIRS=()\n")
	end

	local hasuninstallcmds = true
	if uninstallfile and hasuninstallcmds then
		outputfile:write("ADDEDUNINSTALLCMDS=()\n")
	end

	if uninstallfile or haspathvarables then
		outputfile:write("ADDPATHS=()\n\n")
	end


	if haspathvarables then
		outputfile:write("# Add export if it does not exist\n")
		outputfile:write("AddPath () {\n")
		outputfile:write("if ! grep -q -F \"export PATH=\\\"\\$PATH:$1\\\"\" ~/.bashrc; then\n")
		outputfile:write("echo \"export PATH=\\\"\\$PATH:$1\\\"\" >> ~/.bashrc \n")
		outputfile:write("echo added line \\\"export PATH=\\\"\\$PATH:$1\\\"\\\" to ~/.bashrc \n")
		outputfile:write("ADDPATHS+=('$1')\n")
		outputfile:write("fi\n")
		outputfile:write("}\n\n")
	end

	if hasflags then
		outputfile:write("\nCheckInputYesOrNo () {\n")
		outputfile:write("if [ \"$1\" == \"\" ] \nthen \n\n")
		outputfile:write("echo $2\n\n")
		outputfile:write("elif [ \"$1\" == \"y\" ] || [ \"$1\" == \"yes\" ]; \nthen \n\n")
		outputfile:write("echo true\n\n")
		outputfile:write("elif [ \"$1\" == \"n\" ] || [ \"$1\" == \"no\" ]; \nthen \n\n")
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

	if uninstallfile then
		local uninstallprogramprogram = resolveoutputpath(uninstallfile)
		outputfile:write("RunUnInstaller () {\n\n")
		outputfile:write("if [ -x " .. uninstallprogramprogram .. " ] \nthen\n")
		outputfile:write("echo uninstalling last version of " .. postmake.appname() .. "\n")


		if proxy then
			outputfile:write(uninstallprogramprogram .. " " .. proxy.uninstallcmd .. "\n")
		else
			outputfile:write(uninstallprogramprogram .. " --uninstall\n")
		end
		outputfile:write("fi\n")
		outputfile:write("}\n\n")
	end
	if proxy then
		outputfile:write("MakeProxyProgram () {\n\n")

		---@cast uninstallfile string
		local newuninstallp = resolveoutputpath(uninstallfile)
		outputfile:write("cp /dev/null " .. newuninstallp .. "\n")
		outputfile:write("echo '#!/usr/bin/env bash' >> " ..
			newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")

		outputfile:write("echo 'Installdir=\"" ..
			resolveoutputpathforinstalldir(postmake.appinstalldir()) ..
			"\"' >> " .. newuninstallp .. "\n\n")

		outputfile:write("echo >> " .. newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")

		outputfile:write("echo 'if [ \"$1\" != \"" ..
			proxy.uninstallcmd .. "\" ] ' >> " .. newuninstallp .. "\n")

		outputfile:write("echo then >> " .. newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")
		outputfile:write("echo '" ..
			resolveoutputpath(proxy.program) .. " \"$@\"" .. "' >> " .. newuninstallp .. "\n")
		outputfile:write("echo >> exit $?" .. newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")
		outputfile:write("echo 'else' >> " .. newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")
		outputfile:write("\n")
		outputfile:write("}\n\n")
	end
	if not postmake.os.exist(uploaddir) then
		postmake.os.mkdirall(uploaddir)
	end

	if singlefile ~= nil then
		local ext = getzipext(compressiontype)
		local mainfile = uploaddir .. singlefile .. ext
		local maindir = uploaddir .. singlefile


		if not postmake.os.exist(maindir) then
			postmake.os.mkdirall(maindir)
		end

		postmake.os.ls(maindir, function(path)
			postmake.os.rmall(path)
		end)

		if postmake.os.exist(mainfile) then
			postmake.os.rm(mainfile)
		end
	end

	outputfile:write("\n")

	local uploadfilecontext = {}

	for configindex, config in ipairs(configs) do
		local islast = configindex == #configs


		if config.os() == "windows" then
			print("error cant use config with os set the windows")
			os.exit(1)
		end

		if configindex == 1 then
			outputfile:write("\n")
			outputfile:write("if ")
		end

		outputfile:write(" [ \"$(uname)\" = \"" .. ostounname(config.os()) .. "\" ]")

		if config.arch() ~= "universal" then
			outputfile:write("  && [ \"$(uname -p)\" = \"" .. archtounname(config.arch()) .. "\" ]")
		end
		outputfile:write("; \nthen\n")

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

		if uninstallfile then
			outputfile:write("RunUnInstaller\n\n")
		end

		outputfile:write("mkdir -p \"$Installdir\" \n\n")


		local dirtomake = {}

		local subdirtomake = {}
		for inputvalue, output in pairs(config.files) do
			local input = inputvalue.string()
			local f

			local isbasicmatch = postmake.match.isbasicmatch(input)
			if isbasicmatch then
				f = postmake.path.getparent(resolveoutputpath(output))
			else
				f = resolveoutputpath(output)
			end

			if not has_value(dirtomake, f) then
				table.insert(dirtomake, f)
				outputfile:write("mkdir -p " .. f .. "\n")
			end



			if uninstallfile and not isbasicmatch then
				local basepath = postmake.match.getbasepath(input)

				if true then
					local p = output
					while p ~= "" and p ~= "/" do
						local val = resolveoutputpath(p)
						if not has_value(subdirtomake, val) then
							table.insert(subdirtomake, val)
						end
						p = postmake.path.getparent(p)
					end
				end
				postmake.match.matchpath(input, function(path)
					local subpath = string.sub(path, #basepath + 1, #path)

					local p = postmake.path.getparent(subpath)

					while p ~= "" and p ~= "." do
						local dir = f .. "/" .. p
						if not has_value(subdirtomake, dir) then
							table.insert(subdirtomake, dir)
						end
						p = postmake.path.getparent(p)
					end
				end)
			end
		end

		if uninstallfile then
			table.sort(subdirtomake, function(a, b)
				return #a > #b
			end)

			if #subdirtomake ~= 0 then
				outputfile:write("#made by sub directorys\n")
			end

			for _, value in ipairs(subdirtomake) do
				outputfile:write("ADDEDDIRS+=(\"" .. value .. "\")\n")
			end

			if #dirtomake ~= 0 then
				outputfile:write("#made by main files\n")
			end
			for _, value in ipairs(dirtomake) do
				if not has_value(subdirtomake, value) then
					outputfile:write("ADDEDDIRS+=(\"" .. value .. "\")\n")
				end
			end
		end

		if proxy then
			outputfile:write("\nMakeProxyProgram \n\n")
		end

		if #dirtomake ~= 0 then
			outputfile:write("\n")
		end


		if singlefile ~= nil then
			local ext = getzipext(compressiontype)
			local mainfile = uploaddir .. singlefile .. ext

			local outfile = resolveoutputpath("/" .. singlefile)
			local outfilewithext = outfile .. ext

			if testmode then
				outputfile:write("echo 'Copying " .. singlefile .. "'\n")
				outputfile:write("cp " .. mainfile .. " " .. outfilewithext .. "\n")
			else
				outputfile:write("echo 'Downloading " .. singlefile .. "'\n")
				outputfile:write("curl -sSLJ " ..
					weburl .. "/" .. singlefile .. ext .. " -o " .. outfilewithext .. "\n")
			end

			outputfile:write("mkdir -p " .. outfile .. "\n")
			outputfile:write(makeunzipcmd(compressiontype, outfilewithext, outfile) .. "\n")

			outputfile:write("rm " .. outfilewithext .. "\n")

			outputfile:write("\n\n")
		end

		local dirspit = config.os() .. "-" .. config.arch()
		onconfig(outputfile, config, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext,
			compressiontype, singlefile, dirspit)

		for _, subconfig in ipairs(config.ifs) do
			local isfirstiniflistloop = true

			for _, ifinfo in ipairs(subconfig.iflist) do
				if not isfirstiniflistloop then
					outputfile:write(" &&")
				else
					outputfile:write("if")
				end

				if ifinfo.isflag() then
					outputfile:write(" [ \"$" ..
						stringtoshellsrciptvarable(ifinfo.flagname()) ..
						"\" == " .. ifinfo.value() .. " ] ")
				else
					outputfile:write(" [ \"$" ..
						stringtoshellsrciptvarable(ifinfo.flagname()) ..
						"\" == \"" .. ifinfo.value() .. "\" ] ")
				end

				isfirstiniflistloop = false
			end
			outputfile:write("\nthen\n\n")

			local copyofdir = shallow_copy(dirtomake)
			for _, file in pairs(subconfig.files) do
				local f = postmake.path.getparent(resolveoutputpath(file))

				if not has_value(copyofdir, f) then
					table.insert(copyofdir, f)
					outputfile:write("mkdir -p " .. f .. "\n")
				end
				outputfile:write("\n")
				outputfile:write("\n")
			end

			onconfig(outputfile, subconfig, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext,
				compressiontype
				, singlefile, dirspit)


			outputfile:write("\nfi\n\n")
		end

		if singlefile then
			local outfile = resolveoutputpath("/" .. singlefile)
			outputfile:write("rm -rf " .. outfile .. "\n")
		end
		outputfile:write("echo Successfully Installed " .. postmake.appname() .. "\n")

		if not islast then
			outputfile:write("elif")
		end
	end
	outputfile:write("else\n\n")
	outputfile:write("echo \"Unable to Install '" ..
		postmake.appname() .. "' There is no configuration for your system\"\n")
	outputfile:write("exit 1\n\n")
	outputfile:write("fi\n\n")


	if uninstallfile ~= nil then
		local resolvefile = resolveoutputpath(uninstallfile)

		outputfile:write("# This code makes the uninstall program based on the installed items\n\n")
		if proxy == nil then
			outputfile:write("cp /dev/null " .. resolvefile .. "\n")
			outputfile:write("echo '#!/usr/bin/env bash' >> " .. resolvefile .. "\n")
			outputfile:write("echo >> " .. resolvefile .. "\n")

			outputfile:write("echo 'Installdir=\"" ..
				resolveoutputpathforinstalldir(postmake.appinstalldir()) ..
				"\"' >> " .. resolvefile .. "\n\n")
			outputfile:write("echo >> " .. resolvefile .. "\n\n")
		end
		outputfile:write("echo 'removepath () {' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")
		outputfile:write("echo 'linetoremove=\"export PATH=\\\"\\$PATH:$1\\\"\"' >> " ..
			resolvefile .. " \n")
		outputfile:write("echo 'if grep -q -F \"$linetoremove\" ~/.bashrc; then' >> " ..
			resolvefile .. " \n")
		--outputfile:write("echo 'if [ ! \"$(ls -A $1)\" ]; then' >> " .. resolvefile .. " \n")
		outputfile:write("echo 'grep -v \"$linetoremove\" ~/.bashrc > /tmp/tmp' >> " ..
			resolvefile .. " \n")
		outputfile:write("echo 'mv /tmp/tmp ~/.bashrc' >> " ..
			resolvefile .. " \n")
		outputfile:write("echo 'echo removed line \"$linetoremove\" from ~/.bashrc' >> " ..
			resolvefile .. " \n")
		--outputfile:write("echo 'fi' >> " .. resolvefile .. " \n")
		outputfile:write("echo 'fi' >> " .. resolvefile .. " \n")
		outputfile:write("echo '}' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")

		outputfile:write("echo 'tryremovedir () {' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")
		outputfile:write("echo 'if [ ! \"$(ls -A $1)\" ]; then' >> " .. resolvefile .. " \n")
		outputfile:write("echo 'rmdir $1' >> " .. resolvefile .. " \n")
		if style == 'classic' then
			outputfile:write("echo 'echo removed directory $1' >> " .. resolvefile .. " \n")
		end
		outputfile:write("echo 'fi' >> " .. resolvefile .. " \n")
		outputfile:write("echo '}' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")


		if hasuninstallcmds then
			outputfile:write("echo >> " .. resolvefile .. " \n")
			outputfile:write("for i in \"${ADDEDUNINSTALLCMDS[@]}\"\n")
			outputfile:write("do\n\n")
			outputfile:write("echo \"${i}\" >> " .. resolvefile .. " \n")

			outputfile:write("done\n\n")
			outputfile:write("echo >> " .. resolvefile .. " \n")
		end

		if style == 'modern' then
			outputfile:write("echo \"ADDEDFILESCOUNT=${#ADDEDFILES[@]}\" >> " ..
				resolvefile .. " \n")

			outputfile:write("echo 'BAR=\'")
			local barcount = math.max(2, modern_syle_progress_barmax)

			for _ = 1, barcount, 1 do
				outputfile:write("#")
			end

			outputfile:write("\'' >> " .. resolvefile .. " \n")

			outputfile:write("echo 'ADDEDFILESINDEX=0' >> " ..
				resolvefile .. " \n")
		end


		outputfile:write("for i in \"${ADDEDFILES[@]}\"\n")
		outputfile:write("do\n\n")

		local cleanline = "\\\\033[0K\\\\r"

		if style == 'classic' then
			outputfile:write("echo echo removeing \"${i}\" >> " .. resolvefile .. " \n")
			outputfile:write("echo rm \"\\\"${i}\\\"\" >> " .. resolvefile .. " \n")
		else
			outputfile:write("echo 'Num=$(( (ADDEDFILESINDEX * 100/ADDEDFILESCOUNT * 100) / 100))' >> " ..
				resolvefile .. " \n")

			-- outputfile:write("echo \"echo -ne \\\"(\\$Num)% | removeing ${i} \\\\r\"\\\" >> " ..
			-- resolvefile .. " \n")
			--
			outputfile:write("echo \"echo -ne \\\"(\\$Num)% | removeing ${i} " ..
				cleanline .. "\\\"\" >> " ..
				resolvefile .. " \n")

			outputfile:write("echo rm \"\\\"${i}\\\"\" >> " .. resolvefile .. " \n")
			outputfile:write("echo 'ADDEDFILESINDEX=$(expr $ADDEDFILESINDEX + 1)' >> " ..
				resolvefile .. " \n")
		end
		outputfile:write("done\n\n")



		outputfile:write("echo >> " .. resolvefile .. "\n")

		if style == 'classic' then
			outputfile:write("echo echo removeing " .. resolvefile .. " >> " .. resolvefile .. " \n")
		elseif style == 'modern' then
		end

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("echo \"rm " .. resolvefile .. "\" >> " .. resolvefile .. " \n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("for i in \"${ADDEDPATHS[@]}\"\n")
		outputfile:write("do\n\n")
		if style == 'classic' then
			outputfile:write("echo removepath \"${i}\" >> " .. resolvefile .. " \n")
		else
			outputfile:write(" :\n")
		end
		outputfile:write("done\n\n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("for i in \"${ADDEDDIRS[@]}\"\n")
		outputfile:write("do\n\n")
		outputfile:write("echo tryremovedir \"${i}\" >> " .. resolvefile .. " \n")
		outputfile:write("done\n\n")

		outputfile:write("echo tryremovedir '$Installdir' >> " .. resolvefile .. " \n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")



		if style == 'classic' then
			outputfile:write("echo echo Successfully Removed " ..
				postmake.appname() .. " >> " .. resolvefile .. " \n")
		elseif style == 'modern' then
			outputfile:write("echo echo -ne \\\"" .. cleanline .. "\\\" >> " .. resolvefile .. " \n")
			outputfile:write("echo echo \"Successfully Removed " ..
				postmake.appname() .. "\" >> " .. resolvefile .. " \n")
		end

		if proxy then
			outputfile:write("echo fi >> " .. resolvefile .. " \n")
		end

		outputfile:write("chmod +x " .. resolvefile .. "\n")
	end


	if singlefile ~= nil then
		local ext = getzipext(compressiontype)
		local mainfile = uploaddir .. singlefile .. ext
		local maindir = uploaddir .. singlefile

		---@type { [string]: string }
		local inputfiles = {}

		postmake.os.tree(maindir, function(path)
			local relpath = string.sub(path, maindir:len())

			if not postmake.os.IsDir(path) then
				inputfiles[path] = relpath
			end
		end)

		archive(compressiontype, inputfiles, mainfile)

		postmake.os.rmall(maindir)
	end

	outputfile:close()
end

return build

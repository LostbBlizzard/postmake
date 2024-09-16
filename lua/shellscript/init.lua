local build = {}


local function resolveoutputpath(path)
	return "$Installdir" .. path
end

local function resolveoutputpathforinstalldir(path)
	return path:gsub("~/", "")
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
	"uploaddir",
	"uninstallfile",
	"proxy",
	"testmode"
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
local function shallow_copy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end


local function GetUploadfilePath(input, uploadfilecontext, onadded)
	local newfilename = ""

	if not has_key_map(uploadfilecontext, input) then
		newfilename = input
		if has_value_map(uploadfilecontext, newfilename) then
			newfilename = input .. "1"
		end

		newfilename = postmake.path.getfilename(newfilename)
		uploadfilecontext[input] = newfilename

		if onadded ~= nil then
			onadded(input, newfilename)
		end
	else
		newfilename = postmake.path.getfilename(uploadfilecontext[input])
	end
	return newfilename
end
local function onconfig(outputfile, config, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext)
	for inputtable, output in pairs(config.files) do
		local input = inputtable.string

		if postmake.match.isbasicmatch(input) then
			local newout = resolveoutputpath(output)

			local newfilename = GetUploadfilePath(input, uploadfilecontext, function(input, newfilename)
				if uploaddir ~= nil then
					postmake.os.cp(input, uploaddir .. newfilename)
				end
			end)

			if testmode then
				outputfile:write("echo 'Copying " .. postmake.path.getfilename(newout) .. "'\n")
				outputfile:write("cp " .. input .. " " .. newout .. "\n")
			else
				outputfile:write("echo 'Downloading " .. postmake.path.getfilename(newout) .. "'\n")
				outputfile:write("curl -sSLJ " ..
					weburl .. "/" .. newfilename .. " -o " .. newout .. "\n")
			end

			if inputtable.isexecutable then
				outputfile:write("chmod +x " .. newout .. "\n")
			end

			if uninstallfile then
				outputfile:write("ADDEDFILES+=('" .. newout .. "')\n")
			end
			outputfile:write("\n")
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


			local resolvenewout = resolveoutputpath("/" .. newout)

			if testmode then
				outputfile:write("echo 'Copying " .. newout .. "'\n")
				outputfile:write("cp " .. input .. " " .. resolvenewout .. "\n")
			else
				outputfile:write("echo 'Downloading " .. newout .. "'\n")
				outputfile:write("curl -sSLJ " ..
					weburl .. "/" .. newout .. " -o " .. resolvenewout .. "\n")
			end

			outputfile:write("echo 'Unziping " .. newout .. "'\n")
			outputfile:write("tar -xvzf " ..
				resolvenewout .. " -C " .. resolveoutputpath(output) .. "\n\n")

			if uninstallfile then
				outputfile:write("ADDEDFILES+=(")
				for _, value in pairs(files) do
					outputfile:write(value .. " ")
				end
				outputfile:write("')\n")
			end
		end
	end

	for _, output in pairs(config.paths) do
		outputfile:write("AddPath " .. resolveoutputpath(output) .. " \n")

		if uninstallfile then
			outputfile:write("ADDEDPATHS+=('" .. resolveoutputpath(output) .. "')\n")
		end
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


	--- passed in settings
	local weburl = settings.weburl
	local uploaddir = settings.uploaddir
	local uninstallfile = settings.uninstallfile
	local proxy = settings.proxy
	local testmode = false

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


	outputfile:write("Installdir=\"$HOME/" .. resolveoutputpathforinstalldir(postmake.appinstalldir()) .. "\" \n")

	outputfile:write("\n\n")


	if uninstallfile then
		outputfile:write("ADDEDFILES=()\n")
		outputfile:write("ADDEDMATCHS=()\n")
		outputfile:write("ADDEDDIRS=()\n")
	end

	if uninstallfile or haspathvarables then
		outputfile:write("ADDPATHS=()\n\n")
	end


	if haspathvarables then
		outputfile:write("# Add export if it does not exist\n")
		outputfile:write("AddPath () {\n")
		outputfile:write("if ! grep -q -F \"export PATH=\\\"PATH:$1\\\"\" ~/.bashrc; then\n")
		outputfile:write("echo \"export PATH=\\\"PATH:$1\\\"\" >> ~/.bashrc \n")
		outputfile:write("echo added line \\\"export PATH=\\\"PATH:$1\\\"\\\" to ~/.bashrc \n")
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

		local newuninstallp = resolveoutputpath(uninstallfile)
		outputfile:write("cp /dev/null " .. newuninstallp .. "\n")
		outputfile:write("echo '#!/usr/bin/env bash' >> " ..
			newuninstallp .. "\n")
		outputfile:write("echo >> " .. newuninstallp .. "\n")

		outputfile:write("echo 'Installdir=\"$HOME/" ..
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
	if uploaddir ~= nil then
		postmake.os.mkdirall(uploaddir)
	end

	outputfile:write("\n")

	local installerfile
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

		if uninstallfile then
			outputfile:write("RunUnInstaller\n\n")
		end

		outputfile:write("mkdir -p \"$Installdir\" \n\n")

		if proxy then
			outputfile:write("MakeProxyProgram \n\n")
		end

		local dirtomake = {}
		for _, output in pairs(config.files) do
			local f = postmake.path.getparent(resolveoutputpath(output))

			if not has_value(dirtomake, f) then
				table.insert(dirtomake, f)
				outputfile:write("mkdir -p " .. f .. "\n")
				if uninstallfile then
					outputfile:write("ADDEDDIRS+=(' " .. f .. "')\n")
				end
			end
			outputfile:write("\n")
			outputfile:write("\n")
		end

		onconfig(outputfile, config, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext)

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

			onconfig(outputfile, subconfig, weburl, uploaddir, uninstallfile, testmode, uploadfilecontext)


			outputfile:write("\nfi\n\n")
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

			outputfile:write("echo 'Installdir=\"$HOME/" ..
				resolveoutputpathforinstalldir(postmake.appinstalldir()) ..
				"\"' >> " .. resolvefile .. "\n\n")
			outputfile:write("echo >> " .. resolvefile .. "\n\n")
		end
		outputfile:write("echo 'removepath () {' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")
		outputfile:write("echo 'linetoremove=\"export PATH=\\\"PATH:$1\\\"\"' >> " ..
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
		outputfile:write("echo 'echo removed directory $1' >> " .. resolvefile .. " \n")
		outputfile:write("echo 'fi' >> " .. resolvefile .. " \n")
		outputfile:write("echo '}' >> " .. resolvefile .. " \n")
		outputfile:write("echo >> " .. resolvefile .. " \n")

		outputfile:write("for i in \"${ADDEDFILES[@]}\"\n")
		outputfile:write("do\n\n")
		outputfile:write("echo echo removeing \"${i}\" >> " .. resolvefile .. " \n")
		outputfile:write("echo rm \"${i}\" >> " .. resolvefile .. " \n")
		outputfile:write("done\n\n")



		outputfile:write("echo >> " .. resolvefile .. "\n")
		outputfile:write("echo echo removeing " .. resolvefile .. " >> " .. resolvefile .. " \n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("echo \"rm " .. resolvefile .. "\" >> " .. resolvefile .. " \n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("for i in \"${ADDEDPATHS[@]}\"\n")
		outputfile:write("do\n\n")
		outputfile:write("echo removepath \"${i}\" >> " .. resolvefile .. " \n")
		outputfile:write("done\n\n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")
		outputfile:write("for i in \"${ADDEDDIRS[@]}\"\n")
		outputfile:write("do\n\n")
		outputfile:write("echo tryremovedir \"${i}\" >> " .. resolvefile .. " \n")
		outputfile:write("done\n\n")

		outputfile:write("echo tryremovedir '$Installdir' >> " .. resolvefile .. " \n")

		outputfile:write("echo  >> " .. resolvefile .. "\n")


		outputfile:write("echo echo Successfully Removed " ..
			postmake.appname() .. " >> " .. resolvefile .. " \n")

		if proxy then
			outputfile:write("echo fi >> " .. resolvefile .. " \n")
		end

		outputfile:write("chmod +x " .. resolvefile .. "\n")
	end

	outputfile:close()
end

return build

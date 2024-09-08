local build = {}


function resolveoutputpath(path)
	return "$Installdir" .. path
end

function ostounname(oosname)
	if oosname == "linux" then
		return "Linux"
	elseif oosname == "macos" then
		return "Darwin"
	else
		print("unable convert '" .. oosname .. "' to then unix uname string")
		exit(1)
	end
end

function archtounname(archtype)
	if archtype == "x64" then
		return "x86_64"
	elseif archtype == "x32" then
		return "x86_32"
	elseif archtype == "arm64" then
		return "arm64"
	else
		print("unable convert '" .. archtype .. "' to then unix uname machine type string")
		exit(1)
	end
end

function stringtoshellsrciptvarable(varablename)
	return "var" .. varablename:gsub(" ", "_")
end

function booltoyesorno(bool)
	if bool then
		return "yes"
	else
		return "no"
	end
end

AllowedSettingsFields =
{
	"weburl",
	"uploaddir"
}

function onconfig(outputfile, config, weburl, uploaddir)
	for input, output in pairs(config.files) do
		local newout = resolveoutputpath(output)
		outputfile:write("curl -LJ " .. weburl .. output .. " -o " .. newout .. "\n\n")

		if uploaddir ~= nil then
			postmake.os.cp(input, uploaddir .. "/" .. output)
		end
	end

	for _, output in pairs(config.paths) do
		outputfile:write("AddPath " .. resolveoutputpath(output) .. " \n")
	end
end

function build.make(postmake, configs, settings)
	print("---building shell script")

	--- Boring checks
	if settings.weburl == nil then
		print("error settings must have the 'weburl' field set")
		exit(1)
	end
	goterrorinsettings = false
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
		exit(1)
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


	outputfile = io.open(outputpath, "w")

	outputfile:write("#!/usr/bin/env bash\n")
	outputfile:write("set -e\n")

	outputfile:write("\n\n# Script generated by the PostMake Shellscript Plugin.\n")

	outputfile:write("\n\n")


	outputfile:write("Installdir=\"$HOME/." .. postmake.appname() .. "\" \n")

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

	if configindex ~= 0 then
		outputfile:write("\n")
		outputfile:write("if ")
	end

	for configindex, config in ipairs(configs) do
		local islast = configindex == #configs

		if config.os() == "windows" then
			print("error cant use config with os set the windows")
			exit(1)
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


		onconfig(outputfile, config, weburl, uploaddir)

		for _, output in ipairs(config.ifs) do
			local isfirstiniflistloop = true

			for _, output2 in ipairs(output.iflist) do
				if not isfirstiniflistloop then
					outputfile:write(" ||")
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

			onconfig(outputfile, output, weburl, uploaddir)

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

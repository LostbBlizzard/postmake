local util = postmake.require("util.lua")

local function writeconfigcode(outputfile, indent, config)
	for _, output in ipairs(config.paths) do
		outputfile:write(indent .. "EnvAddPath(" .. util.expandpostmakepathtoinnoapppath(output) .. "); \n")
	end
end

local function has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end
return function(outputfile, config)
	local hasaddpath = true
	outputfile:write("\n[Code]\n")

	if hasaddpath then
		outputfile:write(
			"const EnvironmentKey = \'SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\';")
		outputfile:write("\n")
		outputfile:write("procedure EnvAddPath(Path: string);\n")
		outputfile:write("var\n")
		outputfile:write("    Paths: string;\n")
		outputfile:write("begin\n")
		outputfile:write("    { Retrieve current path (use empty string if entry not exists) }\n")
		outputfile:write("    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)\n")
		outputfile:write("    then Paths := '';\n")
		outputfile:write("\n")
		outputfile:write("    { Skip if string already found in path }\n")
		outputfile:write(
			"    if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then exit;\n")
		outputfile:write("\n")
		outputfile:write("    { App string to the end of the path variable }\n")
		outputfile:write("    Paths := Paths + ';'+ Path +';'\n")
		outputfile:write("\n")
		outputfile:write("    { Overwrite (or create if missing) path environment variable }\n")
		outputfile:write("    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)\n")
		outputfile:write("    then Log(Format('The [%s] added to PATH: [%s]', [Path, Paths]))\n")
		outputfile:write("    else Log(Format('Error while adding the [%s] to PATH: [%s]', [Path, Paths]));\n")
		outputfile:write("end;\n")
		outputfile:write("\n")
		outputfile:write("procedure EnvRemovePath(Path: string);\n")
		outputfile:write("var\n")
		outputfile:write("    Paths: string;\n")
		outputfile:write("    P: Integer;\n")
		outputfile:write("begin\n")
		outputfile:write("    { Skip if registry entry not exists }\n")
		outputfile:write(
			"    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then\n")
		outputfile:write("        exit;\n")
		outputfile:write("\n")
		outputfile:write("    { Skip if string not found in path }\n")
		outputfile:write("    P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');\n")
		outputfile:write("    if P = 0 then exit;\n")
		outputfile:write("\n")
		outputfile:write("    { Update path variable }\n")
		outputfile:write("    Delete(Paths, P - 1, Length(Path) + 1);\n")
		outputfile:write("\n")
		outputfile:write("    { Overwrite path environment variable }\n")
		outputfile:write("    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)\n")
		outputfile:write("    then Log(Format('The [%s] removed from PATH: [%s]', [Path, Paths]))\n")
		outputfile:write(
			"    else Log(Format('Error while removing the [%s] from PATH: [%s]', [Path, Paths]));\n")
		outputfile:write("end;\n\n")
	end

	outputfile:write("procedure CurStepChanged(CurStep: TSetupStep);\n")
	outputfile:write("begin\n")
	outputfile:write("if (CurStep = ssPostInstall) then\n")
	local indent = "  "
	writeconfigcode(outputfile, indent, config)

	for _, output in ipairs(config.ifs) do
		indent = "  "

		outputfile:write(indent)
		local isfirstiniflistloop = true
		for _, output2 in ipairs(output.iflist) do
			if not isfirstiniflistloop then
				outputfile:write(" and")
			else
				outputfile:write("if")
			end

			if output2.isflag() then
				outputfile:write(" WizardIsTaskSelected('" ..
					util.flagnametovarable(output2.flagname()) .. "')")
			else
				--outputfile:write(" \"$" ..
				--	stringtoshellsrciptvarable(output2.flagname()) ..
				--	"\" == \"" .. output2.value() .. "\" ] ")
			end

			isfirstiniflistloop = false
		end

		indent = "  " .. indent
		outputfile:write(" then\n")
		writeconfigcode(outputfile, indent, output)
	end

	outputfile:write("end;\n")
	outputfile:write("\n")
	outputfile:write("procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);\n")
	outputfile:write("begin\n")
	outputfile:write("if CurUninstallStep = usPostUninstall then\n")


	local pathstoremove = {}
	for _, path in ipairs(config.paths) do
		if not has_value(pathstoremove, path) then
			table.insert(pathstoremove, path)
		end
	end
	for _, fig in ipairs(config.ifs) do
		for _, path in ipairs(fig.paths) do
			if not has_value(pathstoremove, path) then
				table.insert(pathstoremove, path)
			end
		end
	end

	indent = "  "
	for _, path in ipairs(pathstoremove) do
		outputfile:write(indent .. "EnvRemovePath(" .. util.expandpostmakepathtoinnoapppath(path) .. "); \n")
	end

	outputfile:write("end;\n")
end

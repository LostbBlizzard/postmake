local build = {}

-- using postmake require and not built in require because we are using go:embed and not a real file
local util = postmake.require("./util.lua")
local makecodesecion = postmake.require("./secions/code.lua")

local asserttype = postmake.lua.asserttype
local assertnullabletype = postmake.lua.assertnullabletype
-- local assertenum = postmake.lua.assertenum
-- local assertnullablenum = postmake.lua.assertnullablenum
local asserttypearray = postmake.lua.asserttypearray
local assertpathmustnothaveslash = postmake.lua.assertpathmustnothaveslash

local valueor = postmake.lua.valueor
local plua = postmake.lua

-- Theres more but I wil add them when I Need them.
local DefaultInnoSettinsList =
{
	DisableDirPage = "yes",
	DisableProgramGroupPage = "yes",
	Compression = "lzma",
	SolidCompression = "yes",
	WizardStyle = "modern",
	PrivilegesRequired = "lowest"
}
local OptionalInnoSettinsList =
{
	"SetupIconFile",
	"WizardStyle"
}
local ContextBasedDefaultsSettinsList =
{
	"DefaultGroupName",
	"OutputBaseFilename",
	"AppId",
	"LaunchProgram",
	"MyAppExeName",
	"MyAppName",
	"MyAppVersion",
	"MyAppPublish",
	"MyAppURL",
	"MyAppExeName"
}
local Othersettings = {
	"proxy",
	"UninstallDelete"
}

---@param postmake pluginpostmake
---@param configs pluginconfig[]
---@param settings InnoSetConfig
function build.make(postmake, configs, settings)
	--- Boring checks
	for _, value in ipairs(configs) do
		if value.os() ~= 'windows' then
			print("innoSetup only allows windows configs." .. #configs .. " was given")
			os.exit(1)
		end
	end
	-- if #configs ~= 1 then
	-- 	print("innoSetup only allows one windows config." .. #configs .. " was given")
	-- 	os.exit(1)
	-- end

	local config = configs[1]
	local issingleconfig = #configs == 1

	if config == nil then
		print("config is nil")
		os.exit(1)
	end

	if config.os() ~= "windows" then
		print("config os is not windows innoSetup only allows to .iss make for windows")
		os.exit(1)
	end

	if settings.AppId == nil then
		print("Set the Missing AppId varable on the settings object")
		os.exit(1)
	end

	--- checking settings

	local goterrorinsettings = false
	for key, _ in pairs(settings) do
		local issettingallowed = false

		for Defaultkey, _ in pairs(DefaultInnoSettinsList) do
			if key == Defaultkey then
				issettingallowed = true
				break
			end
		end

		if issettingallowed then
			goto continue
		end

		for _, SettingName in ipairs(OptionalInnoSettinsList) do
			if key == SettingName then
				issettingallowed = true
				break
			end
		end

		if issettingallowed then
			goto continue
		end


		for _, SettingName in ipairs(ContextBasedDefaultsSettinsList) do
			if key == SettingName then
				issettingallowed = true
				break
			end
		end

		if issettingallowed then
			goto continue
		end

		for _, SettingName in ipairs(Othersettings) do
			if key == SettingName then
				issettingallowed = true
				break
			end
		end
		if issettingallowed then
			goto continue
		end

		print("The Key '" .. key .. "' is not an  valid inno Settins. Typo?")
		goterrorinsettings = true
		::continue::
	end

	if goterrorinsettings then
		print(
			"\nCheck the Inno Setup Docs https://jrsoftware.org/ishelp/index.php?topic=iconssection\nif The setting exist help add it on https://github.com/LostbBlizzard/postmake\n\n")
		os.exit(1)
	end


	if settings.proxy then
		if settings.proxy.uninstallcmd == nil then
			print("proxy setting is missing the uninstallcmd field")
		end
		if settings.proxy.program == nil then
			print("proxy setting is missing the program field")
		end
		if settings.proxy.path == nil then
			print("proxy setting is missing the path field")
		end

		if settings.proxy.uninstallcmd == nil or settings.proxy.program == nil then
			os.exit(1)
		end
	end


	asserttype(settings.AppId, "settings.AppId", "string")
	assertnullabletype(settings.DefaultGroupName, "settings.DefaultGroupName", "string")
	assertnullabletype(settings.OutputBaseFilename, "settings.OutputBaseFilename", "string")
	assertnullabletype(settings.LaunchProgram, "settings.LaunchProgram", "string")
	if settings.proxy ~= nil then
		asserttype(settings.proxy.uninstallcmd, "settings.proxy.uninstallcmd", "string")
		asserttype(settings.proxy.program, "settings.proxy.program", "string")
		asserttype(settings.proxy.path, "settings.proxy.program", "string")
	end
	assertnullabletype(settings.MyAppExeName, "settings.MyAppExeName", "string")
	assertnullabletype(settings.MyAppPublisher, "settings.MyAppPublisher", "string")
	assertnullabletype(settings.MyAppVersion, "settings.MyAppVersion", "string")

	if settings.UninstallDelete ~= nil then
		asserttypearray(settings.UninstallDelete, "settings.UninstallDelete", "string")
	end


	assertpathmustnothaveslash(postmake.appinstalldir(), "postmake.appinstalldir")
	--- end of boring checks

	--- InnoSettings with context based Defaults
	local Inno_DefaultGroupName = valueor(settings.DefaultGroupName, postmake.appname())
	local Inno_OutputBaseFilename = valueor(settings.OutputBaseFilename, postmake.appname() .. "Setup")
	---Other Settings

	---
	print("---building inno script")

	local outputpath = "./" .. postmake.output() .. ".iss"

	print("writing install file to " .. outputpath)

	local outputfile = io.open(outputpath, "w")
	if outputfile == nil then
		print("unable to open file '" .. outputpath .. "'")
		os.exit(1)
	end

	outputfile:write("; Script generated by the PostMake InnoSetup Plugin.\n")
	outputfile:write(
		"; When using PostMake InnoSetup you can add or override any of value below. By adding values to the setings table Ex\n")
	outputfile:write(
		"; postmake.make(innosetup, { windows_64 }, { OutputBaseFilename = \"coolbasefile\", DefaultGroupName = \"test\" });\n\n")


	outputfile:write("#define MyAppName \"" .. valueor(settings.MyAppVersion, postmake.appname()) .. "\"\n")
	outputfile:write("#define MyAppVersion \"" ..
		valueor(settings.MyAppVersion, postmake.appversion()) .. "\"\n")
	outputfile:write("#define MyAppPublisher \"" ..
		valueor(settings.MyAppPublisher, postmake.apppublisher()) .. "\"\n")
	outputfile:write("#define MyAppURL \"" .. valueor(settings.MyAppURL, postmake.appwebsite()) .. "\"\n")
	outputfile:write("#define MyAppExeName \"" ..
		valueor(settings.MyAppExeName, postmake.appname() .. ".exe") .. "\"\n\n")

	outputfile:write("[Setup]\n")
	outputfile:write(
		"; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.\n")
	outputfile:write("; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)\n")


	outputfile:write("AppId={{" .. settings.AppId .. "}\n")
	outputfile:write("AppName={#MyAppName}\n")
	outputfile:write("AppVersion={#MyAppVersion}\n")
	outputfile:write("AppVerName={#MyAppName} {#MyAppVersion}\n")
	outputfile:write("AppPublisher={#MyAppPublisher}\n")
	outputfile:write("AppPublisherURL={#MyAppURL}\n")
	outputfile:write("AppSupportURL={#MyAppURL}\n")
	outputfile:write("AppUpdatesURL={#MyAppURL}\n")

	outputfile:write("DefaultDirName=" .. util.postmakepathtoinnopath(postmake.appinstalldir()) .. "\n")
	outputfile:write("DefaultGroupName=" .. Inno_DefaultGroupName .. "\n")

	if postmake.applicensefile() == nil then
		outputfile:write("LicenseFile= \"" .. postmake.applicensefile() .. "\"\n")
	end

	outputfile:write("OutputBaseFilename=" .. Inno_OutputBaseFilename .. "\n")

	---@type string[]
	local archlist = {}

	for _, value in ipairs(configs) do
		local archallowed = ""

		if value.arch() == 'x64' then
			archallowed = "x64compatible"
		elseif value.arch() == 'x32' then
			archallowed = "x86compatible"
		elseif value.arch() == 'arm64' then
			archallowed = "arm64"
		else
			archlist = {}
			break
		end

		local isinlist = false
		for _, architem in ipairs(archlist) do
			if architem == archallowed then
				isinlist = true
				break
			end

			if not isinlist then
				table.insert(archlist, archallowed)
			end
		end
	end

	if #archlist ~= 0 then
		outputfile:write("ArchitecturesAllowed=")

		for ind, arch in ipairs(archlist) do
			outputfile:write(arch)

			if ind ~= 1 then
				outputfile:write(" ")
			end
		end
		outputfile:write("\n")
	end

	local hasaddeddefault = false
	for key, value in pairs(settings) do
		for SettingName, _ in pairs(DefaultInnoSettinsList) do
			if key == SettingName then
				if hasaddeddefault == false then
					outputfile:write("; Boring Default Settings \n")
				end
				outputfile:write(key .. "=" .. value .. "\n")
				hasaddeddefault = true
				break
			end
		end
	end

	for SettingName, Value in pairs(DefaultInnoSettinsList) do
		local hassetting = false
		for key, _ in pairs(settings) do
			if key == SettingName then
				hassetting = true
				break
			end
		end
		if not hassetting then
			if hasaddeddefault == false then
				outputfile:write("; Boring Default Settings \n")
			end
			outputfile:write(SettingName .. "=" .. Value .. "\n")
			hasaddeddefault = true
		end
	end
	local hasaddedoptional = false
	for key, value in pairs(settings) do
		for _, SettingName in ipairs(OptionalInnoSettinsList) do
			if key == SettingName then
				if hasaddedoptional == false then
					outputfile:write("; Boring Optional Settins \n")
				end
				outputfile:write(key .. "=" .. value .. "\n")
				break
			end
		end
	end


	outputfile:write("\n[Languages]\n")
	outputfile:write("Name: \"english\"; MessagesFile: \"compiler:Default.isl\"\n")

	outputfile:write("\n[Files]\n")

	if settings.proxy then
		local proxdirpath = postmake.output() .. "/innosetup"
		local proxyfilepath = proxdirpath .. "/" .. postmake.appname() .. ".exe"
		local proxyscriptfilepath = proxdirpath .. "/main.lua"

		postmake.os.mkdirall(proxdirpath)

		local proxyfile = io.open(proxyscriptfilepath, "w")
		if proxyfile == nil then
			print("unable to open file '" .. proxyfile .. "'")
			os.exit(1)
		end

		proxyfile:write("print(\"hello world\")")

		postmake.compile.luaprogram(proxyfilepath, "windows")

		local destdir = util.postmakepathtoinnoapppath(
			postmake.path.getparent(settings
				.proxy.path))

		outputfile:write("Source: \"" ..
			proxyfilepath ..
			"\"; DestDir: \"" .. destdir
			.. "\";\n")

		outputfile:write("Source: \"" ..
			proxyfilepath ..
			"\"; DestDir: \"" .. destdir
			.. "\";\n")

		proxyfile:close()
	end


	local function test(input, Src, Dest, Check)
		outputfile:write("Source: \"" .. Src .. "\"; DestDir: \"" .. Dest .. "\";")
		if Check ~= nil then
			outputfile:write(" Check: " .. Check)
		end

		outputfile:write(" Flags: ignoreversion ")

		local isrecurse = string.find(input, "%*%*")
		if isrecurse then
			outputfile:write("recursesubdirs ")
		end
	end
	if not issingleconfig then
		---@class configfileinfo
		---@field output string
		---@field input string
		---@field arch archtype[]

		---@type configfileinfo[]
		local files = {}

		for _, configvalue in ipairs(configs) do
			for inputval, output in pairs(configvalue.files) do
				local hasvalue = nil
				for ind, value in ipairs(files) do
					if value.output == output and value.input == inputval.string() then
						hasvalue = ind
						break
					end
				end

				if hasvalue == nil then
					---@type configfileinfo
					local newitem = {
						output = output,
						input = inputval.string(),
						arch = { configvalue.arch() }
					}

					table.insert(files, newitem)
				else
					table.insert(files[hasvalue].arch, configvalue.arch())
				end
			end
		end

		for _, value in ipairs(files) do
			local reltoinnofile = util.innoinputapppath(value.input)
			local newout = util.postmakepathtoinnoapppath(value.output)

			if not string.find(value.input, "%*") then
				newout = util.getdir(newout)
			end


			if #value.arch ~= #configs then
				for _, arch in ipairs(value.arch) do
					local archfuncition = ""
					if arch == 'x64' then
						archfuncition = "onlyon_x64"
					elseif arch == 'x32' then
						archfuncition = "onlyon_x32"
					elseif arch == 'arm64' then
						archfuncition = "onlyon_arm64"
					end

					test(value.input, reltoinnofile, newout, archfuncition)
				end
			else
				test(value.input, reltoinnofile, newout, nil)
			end


			outputfile:write("\n")
		end
	else
		for inputval, output in pairs(config.files) do
			local input = inputval.string()

			local reltoinnofile = util.innoinputapppath(input)
			local newout = util.postmakepathtoinnoapppath(output)

			if not string.find(input, "%*") then
				newout = util.getdir(newout)
			end

			test(input, reltoinnofile, newout, nil)

			outputfile:write("\n")
		end
	end

	outputfile:write("\n[Tasks]\n")
	for _, flag in ipairs(config.flags) do
		outputfile:write("Name: " ..
			util.flagnametovarable(flag.flagname()) .. "; Description: \"" .. flag.flagname() .. "\"\n")
	end

	makecodesecion(outputfile, config)

	local hasrunsection = #config.installcmds ~= 0 or settings.LaunchProgram ~= nil
	local hasuninstallsection = #config.uninstallcmds ~= 0

	if hasrunsection then
		outputfile:write("\n[Run]\n")
		if settings.LaunchProgram ~= nil then
			local torun = util.postmakepathtoinnoapppath(settings.LaunchProgram)

			outputfile:write("Filename: \"" .. torun ..
				"\"; Description: \"{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}\"; Flags: nowait postinstall skipifsilent\n")
		end

		for _, cmd in ipairs(config.installcmds) do
			outputfile:write("Filename: \"" ..
				util.postmakepathtoinnoapppathcmd(cmd.cmd()) .. "\"; Parameters: \"")

			for i, item in ipairs(cmd.pars()) do
				if i ~= 1 then
					outputfile:write(" ")
				end

				outputfile:write(util.postmakepathtoinnoapppathcmd(item))
			end
			outputfile:write("\"")
			outputfile:write("\n")
		end
	end

	if settings.UninstallDelete ~= nil then
		if #settings.UninstallDelete ~= 0 then
			outputfile:write("\n[UninstallDelete]\n")

			for _, value in ipairs(settings.UninstallDelete) do
				outputfile:write("Type: files; Name: \"" ..
					util.postmakepathtoinnoapppathcmd(value) .. "\" \n")
			end
		end
	end

	if hasuninstallsection then
		outputfile:write("\n[UninstallRun]\n")
		for _, cmd in ipairs(config.uninstallcmds) do
			outputfile:write("Filename: \"" ..
				util.postmakepathtoinnoapppathcmd(cmd.cmd()) .. "\"; Parameters: ")
			for _, item in ipairs(cmd.pars()) do
				outputfile:write("\"" .. util.postmakepathtoinnoapppathcmd(item) .. "\"")
			end
			outputfile:write("\n")
		end
	end
	outputfile:close()
end

return build

local build = {}

-- using postmake require and not built in require because we are using go:embed and not a real file
local util = postmake.require("./util.lua")
local makecodesecion = postmake.require("./secions/code.lua")

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
	"AppId"
}

function build.make(postmake, configs, settings)
	--- Boring checks
	if #configs ~= 1 then
		print("innoSetup only allows one windows config." .. #configs .. " was given")
		os.exit(1)
	end

	config = configs[1]

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

	goterrorinsettings = false
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


		print("The Key '" .. key .. "' is not an  valid inno Settins. Typo?")
		goterrorinsettings = true
		::continue::
	end

	if goterrorinsettings then
		print(
			"\nCheck the Inno Setup Docs https://jrsoftware.org/ishelp/index.php?topic=iconssection\nif The setting exist help add it on https://github.com/LostbBlizzard/postmake\n\n")
		os.exit(1)
	end
	--- end of boring checks

	--- InnoSettings with context based Defaults
	Inno_DefaultGroupName = util.UseOrDefault(settings.DefaultGroupName, postmake.appname())
	Inno_OutputBaseFilename = util.UseOrDefault(settings.OutputBaseFilename, postmake.appname() .. "Setup")
	---
	print("---building inno script")

	local outputpath = "./" .. postmake.output() .. ".iss"

	print("writing install file to " .. outputpath)

	outputfile = io.open(outputpath, "w")
	outputfile:write("; Script generated by the PostMake InnoSetup Plugin.\n")
	outputfile:write(
		"; When using PostMake InnoSetup you can add or override any of value below. By adding values to the setings table Ex\n")
	outputfile:write(
		"; postmake.make(innosetup, { windows_64 }, { OutputBaseFilename = \"coolbasefile\", DefaultGroupName = \"test\" });\n\n")


	outputfile:write("#define MyAppName \"" .. postmake.appname() .. "\"\n")
	outputfile:write("#define MyAppVersion \"" .. postmake.appversion() .. "\"\n")
	outputfile:write("#define MyAppPublisher \"" .. postmake.apppublisher() .. "\"\n")
	outputfile:write("#define MyAppURL \"" .. postmake.appwebsite() .. "\"\n")
	outputfile:write("#define MyAppExeName \"" .. config.mainfile().name() .. "\"\n\n")

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
	for input, output in pairs(config.files) do
		local reltoinnofile = input
		local newout = util.getdir(util.postmakepathtoinnoapppath(output))
		outputfile:write("Source: \"" .. reltoinnofile .. "\"; DestDir: \"" .. newout .. "\";\n")
	end

	outputfile:write("\n[Tasks]\n")
	for _, flag in ipairs(config.flags) do
		outputfile:write("Name: " ..
			util.flagnametovarable(flag.flagname()) .. "; Description: \"" .. flag.flagname() .. "\"\n")
	end

	makecodesecion(config)

	outputfile:close()
end

return build

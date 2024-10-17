local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")
local githubaction = postmake.loadplugin("internal/githubaction")

local appversionenv = os.getenv("POSTMAKEVERSION")
-- App Settings
postmake.appname = "postmake"
postmake.appversion = "0.0.1"

if appversionenv ~= nil then
	postmake.appversion = appversionenv
end

postmake.appinstalldir = "~/.postmake"

postmake.output = "./output/install"
-- Short Hands
local all = postmake.allconfig

--- Configs
local win = postmake.newconfig("windows", "x64")
local gnu = postmake.newconfig("linux", "x64")
local mac = postmake.newconfig("macos", "arm64")

--- flags
local addpathflag = all.newflag("Add Path", true)
--- Add Your files
local winsmainprogram = postmake.installdir() .. "bin/" .. postmake.appname .. ".exe"
win.addxfile("output/postmake.exe", winsmainprogram)
gnu.addxfile("output/postmake", postmake.installdir() .. "bin/" .. postmake.appname)
mac.addxfile("output/postmake_macos", postmake.installdir() .. "bin/" .. postmake.appname)

all.addfile("lua/api/**.lua", postmake.installdir() .. "lua/definitions")
all.If(addpathflag).addpath(postmake.installdir())

local installwebsite = "https://github.com/LostbBlizzard/postmake/releases/tag/Release-" .. postmake.appversion

postmake.make(shellscript, { gnu, mac },
	---@type ShellScriptConfig
	{
		weburl = installwebsite,
		uploaddir = "./output/upload/",
		uninstallfile = postmake.installdir() .. "postmake",
		proxy = {
			uninstallcmd = "uninstall",
			program = postmake.installdir() .. "bin/" .. postmake.appname
		},
		singlefile = "shellscriptinstalldata",
		testmode = true
	});
postmake.make(innosetup, { win },
	---@type InnoSetConfig
	{
		AppId = "x1miKP6buq3AuaLlXa7jsDZnMpPYz3vYm8dSJZyMcahk3A3AlNAJYFuXlfFJXbXemGeEoMBwvZi",
		LaunchProgram = postmake.installdir() .. postmake.appname,
		proxy = {
			path = postmake.installdir() .. postmake.appname,
			uninstallcmd = "uninstall",
			program = winsmainprogram
		},
	});

postmake.make(githubaction, { win, gnu, mac },
	---@type GitHubActionConfig
	{
		weburl = installwebsite
	});

local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

---@type testpostmakemodule
local postmaketest = dofile("../testutils/init.lua")

-- This variable has generated for you can get a new one using inno setup or using 'postmake generate-inno-id'
local InnoAppID = "cQ74UQ4tkqoyd9idylKXHc7PDdrTFN6rSXmVdWfI5mnZLFOdPBML4dWqJLDRS7BeKL10aRnrNg"

-- App Settings
postmake.appname = "app"
postmake.appversion = "0.0.1"
postmake.output = "./output/install"
postmake.appinstalldir = "./output"

-- Short Hands
local all = postmake.allconfig


--- Configs
local win = postmake.newconfig("windows", "universal")
local gnu = postmake.newconfig("linux", "universal")
local mac = postmake.newconfig("macos", "universal")

--- Add Your files

postmaketest.addfile(all, "./testfile", postmake.installdir() .. "testfile")
postmaketest.addfile(all, "./somedir/coolfiles**.md", postmake.installdir() .. "coolfiles")

if not postmake.os.exist(postmake.appinstalldir) then
	postmake.os.mkdir(postmake.appinstalldir)
end

postmake.lua.assert(postmaketest.make(shellscript, { gnu, mac },
	---@type ShellScriptConfig
	{
		weburl = "website.com",
		uploaddir = "./uploadir"
	}), "shellscript setup failed");
postmake.lua.assert(postmaketest.make(innosetup, { win }, { AppId = InnoAppID, }), "inno setup failed");
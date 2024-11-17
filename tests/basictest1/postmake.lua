local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")
local githubaction = postmake.loadplugin("internal/githubaction")

---@type testpostmakemodule
local postmaketest = dofile("../testutils/init.lua")

-- This variable has generated for you can get a new one using inno setup or using 'postmake generate-inno-id'
local InnoAppID = "cQ74UQ4tkqoyd9idylKXHc7PDdrTFN6rSXmVdWfI5mnZLFOdPBML4dWqJLDRS7BeKL10aRnrNg"

-- App Settings
postmake.appname = "app"
postmake.appversion = "0.0.1"
postmake.output = "./output/install"
postmake.appinstalldir = "./installedapp"

-- Short Hands
local all = postmake.allconfig


--- Configs
local win = postmaketest.newconfig("windows", "universal")
local gnu = postmaketest.newconfig("linux", "universal")
local mac = postmaketest.newconfig("macos", "universal")

--- Add Your files

postmaketest.addfile(all, "./testfile", postmake.installdir() .. "testfile")
postmaketest.addfile(all, "./somedir/**.md", postmake.installdir() .. "coolfiles")

if not postmake.os.exist(postmake.appinstalldir) then
	postmake.os.mkdir(postmake.appinstalldir)
end

-- postmake.lua.assert(postmaketest.make(shellscript, { gnu, mac },
-- 	---@type ShellScriptConfig
-- 	{
-- 		weburl = "website.com",
-- 		uploaddir = "./uploadir/"
-- 	}), "shellscript setup failed");
-- postmake.lua.assert(postmaketest.make(innosetup, { win }, { AppId = InnoAppID, }), "inno setup failed");

-- postmake.lua.assert(postmaketest.make(githubaction, { gnu, mac, win }, {
-- 	weburl = "website.com",
-- 	uploaddir = "./output/githubactionupload/",
-- }), "githubaction setup failed");

postmake.make(githubaction, { gnu, mac, win }, {
	testmode = true,
	weburl = "website.com",
	uploaddir = "./output/githubactionupload/",
	version = {}
})

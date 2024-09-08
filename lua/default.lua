local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

-- App Settings
postmake.appname = "app"
postmake.appversion = "0.0.1"
postmake.output = "./output/install"

postmake.appinstalldir = "~/.postmake"
-- Short Hands
local all = postmake.allconfig
--local unix = postmake.foros("unix")

--local winodows = postmake.foros("winodws")
--local linux = postmake.foros("linux")
--local macos = postmake.foros("macos")

--- Configs
local win = postmake.newconfig("windows", "x64")
local gnu = postmake.newconfig("linux", "x64")
local mac = postmake.newconfig("macos", "x64")
--local unix = postmake.newconfig("macos", "x64")

--- Add Your files

win.addfile("main.exe", postmake.installdir() .. "./" .. postmake.appname + ".exe")
gnu.addfile("main", postmake.installdir() .. "./" .. postmake.appname)
mac.addfile("main.app", postmake.installdir() .. "./" .. postmake.appname + ".app")

all.addfile("README.md", postmake.installdir() .. "./testlua")

postmake.make(shellscript, { gnu, mac }, {});
postmake.make(innosetup, { win }, {});

local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

-- App Settings
postmake.appname = "postmake"
postmake.appversion = "0.0.1"
postmake.appid = "abcd"

postmake.output = "./output/install"
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

win.addmainfile("./output/postmake.exe", postmake.installdir() .. postmake.appname .. ".exe")
gnu.addmainfile("./output/postmake", postmake.installdir() .. postmake.appname)
mac.addmainfile("./output/postmake_macos", postmake.installdir() .. postmake.appname)

all.addfile("README.md", postmake.installdir() .. "README.md")

postmake.make(shellscript, { gnu, mac }, { weburl = "https//dot.com", uploaddir = "./output/upload" });
postmake.make(innosetup, { win }, {});

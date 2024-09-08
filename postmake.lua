local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

-- App Settings
postmake.appname = "postmake"
postmake.appversion = "0.0.1"
postmake.appinstalldir = "~/.postmake"

postmake.output = "./output/install"
-- Short Hands
local all = postmake.allconfig

--- Configs
local win = postmake.newconfig("windows", "x64")
local gnu = postmake.newconfig("linux", "x64")
local mac = postmake.newconfig("macos", "x64")

--- flags
local testflag = all.newflag("Add Path", true)
--- Add Your files
local winsmainprogram = postmake.installdir() .. postmake.appname .. ".exe"
win.addmainfile("./output/postmake.exe", winsmainprogram)
gnu.addmainfile("./output/postmake", postmake.installdir() .. postmake.appname)
mac.addmainfile("./output/postmake_macos", postmake.installdir() .. postmake.appname)

all.If(testflag).addpath(postmake.installdir())

postmake.make(shellscript, { gnu, mac }, { weburl = "https//dot.com", uploaddir = "./output/upload/" });
postmake.make(innosetup, { win }, { AppId = "abcd", LaunchProgram = winsmainprogram });

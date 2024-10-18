local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

-- The InnoAppID of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
-- See https://jrsoftware.org/ishelp/index.php?topic=setup_appid

-- This variable has generated for you can get a new one using inno setup or using 'postmake generate-inno-id'
local InnoAppID = "###{INNOAPPID}###"

--postmake.target() is the target installer you can change this by doing 'postmake --target winodows"
-- App Settings
postmake.appname = "app"
postmake.appversion = "0.0.1"
postmake.output = "./output/install"

postmake.appinstalldir = "~/.app"

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

--- Add Your files

local winsmainprogram = postmake.installdir() .. "./" .. postmake.appname .. ".exe"

win.addfile("main.exe", winsmainprogram)
gnu.addfile("main", postmake.installdir() .. "./" .. postmake.appname)
mac.addfile("main_macos", postmake.installdir() .. "./" .. postmake.appname)

all.addfile("License.md", postmake.installdir() .. "./License.md")

postmake.make(shellscript, { gnu, mac }, {});
postmake.make(innosetup, { win },
	---@type InnoSetConfig
	{
		AppId = InnoAppID, LaunchProgram = winsmainprogram, LicenseFile = "License.md"
	});

local dpkg = postmake.loadplugin("internal/dpkg")

postmake.appname = "test"
postmake.appversion = "0.0.1"
postmake.appinstalldir = "~/.postmake"
postmake.output = "./output/install"

--- Configs
local gnu64 = postmake.newconfig("linux", "x64")
local gnu32 = postmake.newconfig("linux", "x32")
local gnuarm = postmake.newconfig("linux", "arm64")


postmake.make(dpkg, { gnu64 },
	---@type DpkgConfig
	{
	});

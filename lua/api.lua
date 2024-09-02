---@nodoc
---@diagnostic disable-next-line: lowercase-global
postmake = {
	appname = "app",
	appversion = "0.0.1"
}


--- @param input string
--- @param output string
--- Add a file to be part of installer
--- with 'output' being were it placed after the user runs the installer.
function postmake.addfile(input, output) end

---@nodoc
---@diagnostic disable: lowercase-global
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-field

---@class postmake
---@field appname string
---@field appversion string
---@field apppublisher string
---@field appwebsite string
---@field applicensefile string
---@field appinstalldir string
---@field output string
---@field allconfig Config  a that is reference to all other current configs
---@field os osmodule  a utility table with os funcions
---@field path pathmodule  a utility table with path funcions
---@field match matchmodule  a utility table with string matching funcions
---@field archive archivemodule  a utility table with archiveing files funcions
---@field compile compilemodule  a utility table with archiveing files funcions
---@field lua luamodule
---@field json jsonmodule
postmake = {
	appname = "app",
	appversion = "0.0.1",
	apppublisher = "publisher",
	appwebsite = "https://github.com/LostbBlizzard/postmake",
	applicensefile = "",
	appinstalldir = "",
	output = "",
}


--- Add a file to be part of installer
--- with 'output' being were it placed after the user runs the installer.
--- @param input string
--- @param output string
function postmake.addfile(input, output) end

--- Add a file to be part of installer
--- with 'output' being were it placed after the user runs the installer.
--- this file will also executable when in unix.
--- @param input string
--- @param output string
function postmake.addxfile(input, output) end

--- Returns the target installer this value is set when passing - target flag when using postmake
--- @return string
function postmake.target() end

--- Returns constant installdir path represents.
--- @return string
function postmake.installdir() end

--- Returns constant home path that represents.
--- @return string
function postmake.homedir() end

--- Makes a newconfig
--- @param os ostype
--- @param arch archtype
--- @return Config
function postmake.newconfig(os, arch) end

---@class Plugin
local Plugin = {

}
--- Loads a Plugin
--- @param path string path can be weblink,a local path, or a "internal/[PluginName]"
--- @return Plugin
function postmake.loadplugin(path) end

--- Builds an Installer Scripts
--- @param plugin Plugin
--- @param configs Config[]
--- @param pluginconfig any
function postmake.make(plugin, configs, pluginconfig) end

--- Only used toe internal plugins
--- @param path string
--- @return unknown
function postmake.require(path) end

--- get all cofigs only for an os
--- @param os ostype|'unix'
--- @return Config
function postmake.foros(os) end

--- get all cofigs only for an cpu arch
--- @param os archtype
--- @return Config
function postmake.forarch(os) end

---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class Config
local Config = {}

---@class FlagObject
local FlagObject = {}

---@class EnumFlagObject
local EnumFlagObject = {}

--- Add a file to be part of installer
--- with 'output' being were it placed after the user runs the installer.
--- @param input string
--- @param output string
function Config.addfile(input, output) end

--- Add a file to be part of installer
--- with 'output' being were it placed after the user runs the installer.
--- this file will also executable when in unix.
--- @param input string
--- @param output string
function Config.addxfile(input, output) end

--- Add to PATH varable after install
--- @param path string
function Config.addpath(path) end

--- Makes a new flag that the user can select
--- @param name string
--- @param default boolean
--- @return FlagObject
function Config.newflag(name, default) end

--- Makes a new enum that the user can pick one of.
--- @param name string
--- @param values string[]
--- @param default string
--- @return EnumFlagObject
function Config.newenum(name, values, default) end

--- Checks the flag object is true the Config thats returns
--- Is What should happen when the flag is true
--- @param flag FlagObject
--- @return Config
function Config.If(flag) end

--- Checks the flag object is false the Config thats returns
--- Is What should happen when the flag is false
--- @param flag FlagObject
--- @return Config
function Config.IfNot(flag) end

--- Checks the flag object is the enumvalue the Config thats returns
--- Is What should happen when the flag is the enumvalue
--- @param flag EnumFlagObject
--- @param enumvalue string
--- @return Config
function Config.IfEnum(flag, enumvalue) end

--- A command to run after the install is done
--- @param cmd string
--- @param pars string[]
function Config.addinstallcmd(cmd, pars) end

--- A command to run when the program is being uninstalled before any files are removed
--- @param cmd string
--- @param pars string[]
function Config.adduninstallcmd(cmd, pars) end

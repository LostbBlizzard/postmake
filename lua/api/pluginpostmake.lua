---@nodoc
---@diagnostic disable: lowercase-global
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return
---@diagnostic disable: duplicate-doc-field

---@class pluginpostmake
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
local pluginpostmake = {}

---@class plugincmd
local plugincmd = {}

---@return string[]
function plugincmd.pars() end

---@return string
function plugincmd.cmd() end

---@class pluginfile
local pluginfile = {}

---@return boolean
function pluginfile.isexecutable() end

---@return string
function pluginfile.string() end

---@class subconfig
---@field string string
---@field paths  string[]
---@field files  table<pluginfile, string>
---@field flags  pluginflag[]
---@field iflist  pluginif[]
---@field enumflags  pluginenum[]
---@field installcmds  plugincmd[]
---@field uninstallcmds  plugincmd[]
local subconfig = {}

---@class pluginif
local pluginif = {}

---@return boolean
function pluginif.isflag() end

---@return string
function pluginif.flagname() end

---@return string
function pluginif.value() end

---@class pluginconfig
---@field files  table<pluginfile, string>
---@field flags  pluginflag[]
---@field enumflags  pluginenum[]
---@field paths  string[]
---@field ifs  subconfig[]
---@field installcmds  plugincmd[]
---@field uninstallcmds  plugincmd[]
local pluginconfig = {}

---@class pluginenum
local pluginenum = {}

---@return string
function pluginenum.flagname() end

---@return string
function pluginenum.defaultvalue() end

---@return string[]
function pluginenum.values() end

---@class pluginflag
local pluginflag = {}

---@return string
function pluginflag.flagname() end

---@return boolean
function pluginflag.defaultvalue() end

---@return ostype
function pluginconfig.os() end

---@return archtype
function pluginconfig.arch() end

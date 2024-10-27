---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class unamemodule
local unamemodule = {}

---@return archtype|'unknown'
function unamemodule.machine() end

---@return ostype|'unknown'
function unamemodule.os() end

---@return boolean
function unamemodule.isunix() end

---@class osmodule
---@field uname unamemodule
local osmodule = {}

---@param input string
---@param output string
function osmodule.cp(input, output) end

---@param path string
function osmodule.mkdir(path) end

---@param path string
function osmodule.mkdirall(path) end

---@param path string
function osmodule.exist(path) end

---@param path string
function osmodule.rm(path) end

---@param path string
function osmodule.rmall(path) end

---@param path string
---@param callback fun(filepath:string)
function osmodule.ls(path, callback) end

---@param path string
---@param callback fun(filepath:string)
function osmodule.tree(path, callback) end

---@param path string
---@return boolean
function osmodule.IsFile(path, callback) end

---@param path string
---@return boolean
function osmodule.IsDir(path) end

---@param input string
---@param output string
function osmodule.ln(input, output) end

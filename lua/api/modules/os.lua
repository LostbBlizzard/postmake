---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class osmodule
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

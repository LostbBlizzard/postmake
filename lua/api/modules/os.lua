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

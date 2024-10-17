---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class matchmodule
local matchmodule = {}


---@param string string
function matchmodule.isbasicmatch(string) end

---@param patten string
---@param stringtocheck string
function matchmodule.match(patten, stringtocheck) end

---@param string string
---@param callback fun(file: string)
function matchmodule.matchpath(string, callback) end

---@param patten string
---@return string
function matchmodule.getbasepath(patten, stringtocheck) end

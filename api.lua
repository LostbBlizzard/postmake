---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class luadoc
luadoc = {}

---@class fieldinfo
---@field name string
---@field type string
---@field description string

---@class classinfo
---@field name string
---@field description string
---@field fields fieldinfo[]

---@class parinfo
---@field name string
---@field type string
---@field description string

---@class memberobjectinfo
---@field Ismembercall boolean
---@field ObjectName string

---@class funcinfo
---@field name string
---@field description string
---@field memberobject memberobjectinfo?
---@field pars parinfo[]
---@field ret string

---@param callback fun(info:classinfo)
function luadoc.onclass(callback) end

---@param callback fun(info:funcinfo)
function luadoc.onfunc(callback) end

---@param callback fun()
function luadoc.ondone(callback) end

---@param callback fun(filepath:string)
function luadoc.onfile(callback) end

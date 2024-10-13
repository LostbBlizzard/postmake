---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return


---@class archivemodule
local archivemodule = {}

---@param inputfiles { [string]: string }
---@param output string
function archivemodule.make_tar_gx(inputfiles, output) end

---@param inputfiles string[]
---@param output string
function archivemodule.make_zip(inputfiles, output) end

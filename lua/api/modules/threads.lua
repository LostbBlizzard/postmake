---@nodoc
---@diagnostic disable: unused-local
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: missing-return

---@class threadsmodule
local threadsmodule = {}

---@class channel
local channel = {}

function channel.select(case:table [, case:table, case:table ...]) -> {index:int, recv:any, ok}

---@return channel
function threadsmodule.newthread() end

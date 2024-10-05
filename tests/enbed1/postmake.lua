---@type EnbedPlugin
---@diagnostic disable-next-line: assign-type-mismatch
local enbed = postmake.loadplugin("internal/enbed")

enbed.enbed("./internalfiles.h", "./internalfiles.c", "c")

os.execute("g++ main.c internalfiles.c -o main")

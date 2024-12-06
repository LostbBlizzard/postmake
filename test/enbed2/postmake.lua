---@type EnbedPlugin
---@diagnostic disable-next-line: assign-type-mismatch
local enbed = postmake.loadplugin("internal/enbed")

enbed.maketypedef("./internalfiles_type.h", "c")
enbed.enbed("./internalfiles.h", "./internalfiles.c", "c")

local cmd = "g++ main.c internalfiles.c -o main"
os.execute(cmd)

local handle = io.popen("./main")

if handle == nil then
	os.exit(1)
end

local result = handle:read("*a")
handle:close()



local isworked = string.find(result, "Blue") and string.find(result, "Red") and string.find(result, "Blue")

local code;

if isworked then
	code = 0
else
	code = 1
end

os.exit(code)

---@type EnbedPlugin
---@diagnostic disable-next-line: assign-type-mismatch
local enbed = postmake.loadplugin("internal/enbed")

enbed.enbed("./internalfiles.h", "./internalfiles.c", "c")

local cmd = "g++ main.c internalfiles.c -o main"
os.execute(cmd)

local handle = io.popen("./main")

if handle == nil then
	os.exit(1)
end

local result = handle:read("*a")
handle:close()


local isworked = result == "Test: some cool file\n"

local code;

if isworked then
	code = 0
else
	code = 1
end

os.exit(code)

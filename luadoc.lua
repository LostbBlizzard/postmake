local apidoc = "./doc/src/lua/"

local Template_SUMMARY = "./doc/src/Template_SUMMARY.md"
local SUMMARY = "./doc/src/SUMMARY.md"

local function read_file(path)
	local file = io.open(path, "rb") -- r read mode and b binary mode
	if not file then return nil end
	local content = file:read "*a" -- *a or *all reads the whole file
	file:close()
	return content
end

local function replace_string(string, match, newstring)
	return string:gsub(match, newstring)
end
---@type classinfo[]
local classes = {}

function Resolvetype(type)
	if type == "string" then
		return "[string](https://www.lua.org/pil/2.4.html)"
	end
	if type == "integer" then
		return "[integer](https://www.lua.org/pil/2.3.html)"
	end

	if type == "booleans" then
		return "[integer](https://www.lua.org/pil/2.2.html)"
	end

	if type == "number" then
		return "[number](https://www.lua.org/pil/2.3.html)"
	end

	local link = "./../lua/"
	for _, value in ipairs(classes) do
		if value.name == type then
			return "[" .. type .. "](" .. link .. value.name .. ".md" .. ")"
		end
	end
	return type
end

luadoc.onclass(function(classinfo)
	table.insert(classes, classinfo)

	local filename = apidoc .. classinfo.name .. ".md"

	--print("writeing to file " .. filename)

	local file = io.open(filename, "w")
	if file == nil then
		return
	end
	file:write("# " .. classinfo.name .. "(table/struct)\n")
	file:write(classinfo.description .. "\n")


	if #classinfo.fields ~= 0 then
		file:write("## Table Fields\n")
		file:write("|  Name | Type | Description\n")
		file:write(" --- | --- | --- |\n")
	end
	for _, value in ipairs(classinfo.fields) do
		file:write(value.name .. " | " .. Resolvetype(value.type) .. " | " .. value.description .. "\n")
	end


	file:write(classinfo.description)
	file:close()
end)

luadoc.onfunc(function(funcinfo)
	if funcinfo.memberobject ~= nil then
		print(funcinfo.memberobject.ObjectName)
	end
end)

luadoc.ondone(function()
	local apisummary = ""

	local link = "./lua/"
	for _, value in ipairs(classes) do
		apisummary = apisummary .. "    - [" .. value.name .. "](" .. link .. value.name .. ".md" .. ")\n"
	end


	local Template_SUMMARYText = read_file(Template_SUMMARY)
	local newtext = replace_string(Template_SUMMARYText, "###LUAAPI###", apisummary)

	local file = io.open(SUMMARY, "w")
	if file == nil then
		return
	end

	file:write(newtext)
	file:close()
end)

luadoc.onfile(function(filepath)
end)

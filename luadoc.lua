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

---@class ClassData
---@field info Classinfo
---@field funcs Funcinfo[]

---@type ClassData[]
local classes = {}

---@type Aliasinfo[]
local aliases = {}

function Resolvetype(type)
	if type == "string" then
		return "[string](https://www.lua.org/pil/2.4.html)"
	end
	if type == "integer" then
		return "[integer](https://www.lua.org/pil/2.3.html)"
	end

	if type == "boolean" then
		return "[boolean](https://www.lua.org/pil/2.2.html)"
	end

	if type == "number" then
		return "[number](https://www.lua.org/pil/2.3.html)"
	end

	local link = "./../lua/"
	for _, value in ipairs(classes) do
		if value.info.name == type then
			return "[" .. type .. "](" .. link .. value.info.name .. ".md" .. ")"
		end
	end
	for _, value in ipairs(aliases) do
		if value.type == type then
			return "[" .. type .. "](" .. link .. value.name .. ".md" .. ")"
		end
	end
	return type
end

---@param classdata ClassData
local function onclassdata(classdata)
	local classinfo = classdata.info
	local filename = apidoc .. classinfo.name .. ".md"

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
		file:write(value.name)

		if value.optional then
			file:write("[?]()")
		end
		file:write(" | " .. Resolvetype(value.type) .. " | " .. value.description .. "\n")
	end

	if #classdata.funcs ~= 0 then
		file:write("## Table Functions\n")
		file:write("|  Signature | Description\n")
		file:write(" --- | --- |\n")
	end

	for _, value in ipairs(classdata.funcs) do
		file:write(value.name)

		file:write("(")
		for index, par in ipairs(value.pars) do
			file:write(par.name)
			file:write(":")
			file:write(Resolvetype(par.type))

			local islast = index == #value.pars

			if not islast then
				file:write(",")
			end
		end
		file:write(")")

		if value.ret ~= "" then
			file:write(":")
			file:write(Resolvetype(value.ret))
		end

		file:write(" | " .. value.description .. "\n")
	end


	file:write(classinfo.description)
	file:close()
end
function makealias(aliasinfo)
	local filename = apidoc .. aliasinfo.name .. ".md"

	local file = io.open(filename, "w")
	if file == nil then
		return
	end
	file:write("# " .. aliasinfo.name .. "(alias)\n")
	file:write(aliasinfo.description .. "\n")

	file:write("```lua\n\n\n")
	file:write("")
	file:write("```")

	file:close()
end

Luadoc.onalias(function(aliasinfo)
	table.insert(aliases, aliasinfo)
end)

Luadoc.onclass(function(classinfo)
	local newclassinfo = {}
	newclassinfo.info = classinfo
	newclassinfo.funcs = {}
	table.insert(classes, newclassinfo)
end)

Luadoc.onfunc(function(funcinfo)
	if funcinfo.memberobject ~= nil then
		for _, value in ipairs(classes) do
			if value.info.name == funcinfo.memberobject.classname then
				table.insert(value.funcs, funcinfo)
			end
		end
	end
end)

Luadoc.ondone(function()
	local apisummary = ""

	local link = "./lua/"
	for _, item in ipairs(classes) do
		apisummary = apisummary ..
		    "    - [" .. item.info.name .. "](" .. link .. item.info.name .. ".md" .. ")\n"
		onclassdata(item)
	end


	for _, item in ipairs(aliases) do
		apisummary = apisummary ..
		    "    - [" .. item.name .. "](" .. link .. item.name .. ".md" .. ")\n"
		makealias(item)
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

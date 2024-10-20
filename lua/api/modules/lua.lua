---@class luamodule
local luamodule = {}


---@generic T : any
--- @param boolean boolean
--- @param OnTrue T
--- @param OnFalse T
--- @return T
function luamodule.valueif(boolean, OnTrue, OnFalse)
	if boolean then
		return OnTrue
	else
		return OnFalse
	end
end

function luamodule.valueor(value, default)
	if value ~= nil then
		return value
	else
		return default
	end
end

---@generic K
---@generic V
---@param tab table<K, V>
---@param val K
---@return boolean
function luamodule.has_key_map(tab, val)
	for key, _ in pairs(tab) do
		if key == val then
			return true
		end
	end

	return false
end

---@generic K
---@generic V
---@param tab table<K, V>
---@param val V
---@return boolean
function luamodule.has_value_map(tab, val)
	for _, value in pairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

---@generic T
---@param tab T[]
---@param val T
---@return boolean
function luamodule.has_value(tab, val)
	for _, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

---@generic T
---@param t T
---@return T
function luamodule.shallow_copy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

---@generic T
---@param o T
---@return T
---// from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value by slet8
function luamodule.deep_copy(o, seen)
	seen = seen or {}
	if o == nil then return nil end
	if seen[o] then return seen[o] end


	local no = {}
	seen[o] = no
	setmetatable(no, luamodule.deep_copy(getmetatable(o), seen))

	for k, v in next, o, nil do
		k = (type(k) == 'table') and k:deepcopy(seen) or k
		v = (type(v) == 'table') and v:deepcopy(seen) or v
		no[k] = v
	end
	return no
end

---@param msg string
function luamodule.panic(msg)
	error(msg, 2)
end

---@param bool boolean
---@param msg string
function luamodule.assert(bool, msg)
	if bool == false then
		luamodule.panic(msg)
	end
end

---@param value any
---@param varablename string
---@param typevarable type
function luamodule.asserttype(value, varablename, typevarable)
	local typeinf = type(value)
	if typeinf ~= typevarable then
		luamodule.panic("the varable " ..
			varablename .. " is not the type " .. typevarable .. ". It was the type " .. typeinf)
	end
end

---@param value any
---@param varablename string
---@param typevarable type
function luamodule.assertnullabletype(value, varablename, typevarable)
	if value ~= nil then
		luamodule.asserttype(value, varablename, typevarable)
	end
end

---@generic T
---@param value any
---@param varablename string
---@param possableenumvalues T[]
function luamodule.assertenum(value, varablename, possableenumvalues)
	if #possableenumvalues ~= 0 then
		luamodule.asserttype(value, varablename, type(possableenumvalues[1]))
	end

	local hasvalue = false
	for _, itemvalue in ipairs(possableenumvalues) do
		if itemvalue ~= value then
			hasvalue = true
			break
		end
	end

	if hasvalue == false then
		local errmsg = "the varable " .. varablename .. " is not one of the possable values "

		for _, itemvalue in ipairs(possableenumvalues) do
			errmsg = errmsg .. itemvalue

			if itemvalue ~= #possableenumvalues then
				errmsg = errmsg .. ","
			end
		end
		errmsg = errmsg .. ". It had the value of " .. varablename

		luamodule.panic(errmsg)
	end
end

---@generic T
---@param value T
---@param varablename string
---@param possableenumvalues T[]
function luamodule.assertnullablenum(value, varablename, possableenumvalues)
	if value ~= nil then
		luamodule.assertenum(value, varablename, possableenumvalues)
	end
end

---@param value any[]
---@param varablename string
---@param typevarable type
function luamodule.asserttypearray(value, varablename, typevarable)
	for index, item in ipairs(value) do
		luamodule.asserttype(item, varablename .. " at index " + tostring(index), typevarable)
	end
end

return luamodule

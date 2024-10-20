---@class testpostmakemodule
local m = {}

local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")

local valueif = postmake.lua.valueif
-- local shallow_copy = postmake.lua.shallow_copy
local deep_copy = postmake.lua.deep_copy
local asserttype = postmake.lua.asserttype

---@class testconfigfile
---@field input string
---@field output string
---@field isexutable boolean
local testconfigfile = {}

---@class testconfigdata
---@field files testconfigfile[]
local testconfigdata = {
}

---@type table<Config,testconfigdata>
local configinfo = {}


---@param config Config
---@return testconfigdata
local function getconfig(config)
	if not postmake.lua.has_value(configinfo, config) then
		---@type testconfigdata
		local newconfig = {
			files = {}
		}

		configinfo[config] = newconfig

		return configinfo[config]
	end
	return configinfo[config]
end

---@param config Config
---@param fileinput string
---@param fileout string
function m.addxfile(config, fileinput, fileout)
	asserttype(config, "fileinput", "string")
	asserttype(config, "fileout", "string")

	---@type testconfigfile
	local newfile = {
		input = fileinput,
		output = fileout,
		isexutable = false
	}

	local configdata = getconfig(config)
	table.insert(configdata.files, newfile)
end

---@param config Config
---@param fileinput string
---@param fileout string
function m.addfile(config, fileinput, fileout)
	asserttype(fileinput, "fileinput", "string")
	asserttype(fileout, "fileout", "string")

	---@type testconfigfile
	local newfile = {
		input = fileinput,
		output = fileout,
		isexutable = false
	}

	local configdata = getconfig(config)
	table.insert(configdata.files, newfile)
end

--- @param configs Config[]
--- @param pluginconfig ShellScriptConfig
--- @return boolean
local function shellscriptcheck(configs, pluginconfig)
	local outputfiles = postmake.output
	if postmake.os.exist(outputfiles) then
		postmake.os.rmall(outputfiles)
	end

	postmake.make(shellscript, configs, pluginconfig)

	return true
end



--- @param configs Config[]
--- @param pluginconfig ShellScriptConfig
--- @return boolean
local function runtest(configs, pluginconfig)
	---
	---@type shellscriptcompressiontype[]
	local listcompressiontypes = { 'tar.gz', 'zip' }

	---@type (string?)[]
	local listofsinglefile = { nil, "singlefile" }

	---@type shellscriptstyle[]
	local liststyles = { 'classic', 'modern' }
	---
	local copy = deep_copy(pluginconfig)

	print("runing basic test")
	local basic = shellscriptcheck(configs, pluginconfig)
	if basic == false then
		print("failed basic test")
		return false
	end
	print("passed basic test")


	for _, value in ipairs(listcompressiontypes) do
		print("")
		print("runing compression type " .. value)

		local configcopy = deep_copy(copy)
		configcopy.compressiontype = value

		local test = shellscriptcheck(configs, configcopy)
		if test == false then
			print("failed compression test " .. value)
			return false
		end
		print("passed compression test " .. value)
	end


	for _, value in ipairs(listofsinglefile) do
		print("")
		print("runing single type " .. value)

		local configcopy = deep_copy(copy)

		if value then
			configcopy.singlefile = value
		end

		local test = shellscriptcheck(configs, configcopy)
		if test == false then
			print("-- failed compression test " .. value)
			return false
		end
		print("passed compression test " .. value)
	end

	for _, value in ipairs(liststyles) do
		print("")
		print("runing style type " .. value)

		local configcopy = deep_copy(copy)
		configcopy.style = value

		local test = shellscriptcheck(configs, pluginconfig)
		if test == false then
			print("failed style test " .. value)
			return false
		end
		print("passed style test " .. value)
	end

	print("runing matrices")
	print("")
	for _, compression in ipairs(listcompressiontypes) do
		for _, singlefile in ipairs(listofsinglefile) do
			for _, sytle in ipairs(liststyles) do
				local configcopy = deep_copy(copy)

				if singlefile ~= nil then
					configcopy.singlefile = singlefile
				end
				configcopy.style = sytle
				configcopy.compressiontype = compression

				local test = shellscriptcheck(configs, configcopy)
				if test == false then
					local outputstring = "failed matric test [style:" .. sytle .. ",";
					outputstring = outputstring ..
					    "singlefile:" .. valueif(singlefile == nil, "true", "false") .. ","
					outputstring = outputstring .. "compressiontype:" .. compression .. ","

					print(outputstring)
					return false
				end
				print("")
			end
		end
	end

	print("passed runing matrices")

	return true
end
--- @param plugin Plugin
--- @param configs Config[]
--- @param pluginconfig any
--- @return boolean
function m.make(plugin, configs, pluginconfig)
	if plugin == shellscript then
		print("trying to run all config test")
		local alltests = runtest(configs, pluginconfig)
		if alltests == false then
			print("allconfig test failed for shellscript")

			return false
		end
		print("")

		local hasfailed = false
		for index, value in ipairs(configs) do
			print("trying to single config test")
			local onetest = runtest({ value }, pluginconfig)

			if onetest == false then
				hasfailed = true
				print("single test at index " .. tostring(index) .. " failed for shellscript")
			end
			print("")
		end

		return not hasfailed
	elseif plugin == innosetup then
		return true
	end
	return false
end

return m

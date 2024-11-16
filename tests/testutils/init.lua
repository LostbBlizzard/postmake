---@class testpostmakemodule
local m = {}

local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")
local githubaction = postmake.loadplugin("internal/githubaction")

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
---@return testconfigdata[]
local function getconfig(config)
	---@type testconfigdata[]
	local r = {}
	if config == postmake.allconfig then
		for _, value in pairs(configinfo) do
			table.insert(r, value)
		end
	else
		table.insert(r, configinfo[config])
	end
	return r
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
	for _, value in ipairs(configdata) do
		table.insert(value.files, newfile)
	end
	config.addxfile(fileinput, fileout)
end

---@param ostype ostype
---@param archtype archtype
---@return Config
function m.newconfig(ostype, archtype)
	asserttype(ostype, "ostype", "string")
	asserttype(archtype, "archtype", "string")

	local config = postmake.newconfig(ostype, archtype)

	local newconfig = {
		files = {}
	}

	configinfo[config] = newconfig

	return config
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
	for _, value in ipairs(configdata) do
		table.insert(value.files, newfile)
	end
	config.addfile(fileinput, fileout)
end

---@param path string
---@param configdata testconfigdata
---@return boolean
local function checkforfiles(path, configdata)
	local isbad = false
	for _, value in ipairs(configdata.files) do
		if postmake.match.isbasicmatch(value.input) then
			local outfile = path .. value.output

			print("checking for " .. outfile)
			---TODO check if file the current file is the same
			if not postmake.os.exist(outfile) then
				print("file is missing at " .. outfile .. "")
				isbad = true
			end
		else
			local basepath = postmake.path.absolute(postmake.match.getbasepath(value.input))
			local dir = path .. value.output


			postmake.match.matchpath(value.input, function(filepath)
				local fullpath = postmake.path.absolute(filepath)
				local filename = string.sub(fullpath, #basepath + 1, #fullpath)
				local outfile = dir .. filename

				print("checking for " .. outfile)
				---TODO check if file the current file is the same
				if not postmake.os.exist(outfile) then
					print("file is missing at " .. outfile .. " cause by " .. value.input)
					isbad = true
				end
			end)
		end
	end
	return not isbad
end

--- @param configs Config[]
--- @param pluginconfig ShellScriptConfig
--- @return boolean
local function shellscriptcheck(configs, pluginconfig)
	local outputfiles = postmake.output

	if postmake.os.exist(outputfiles) then
		postmake.os.rmall(outputfiles)
	end
	if postmake.os.exist(postmake.appinstalldir) then
		postmake.os.rmall(postmake.appinstalldir)
	end
	if postmake.os.exist(pluginconfig.uploaddir) then
		postmake.os.rmall(pluginconfig.uploaddir)
	end

	postmake.os.mkdirall(outputfiles)
	postmake.os.mkdirall(postmake.appinstalldir)
	postmake.os.mkdirall(pluginconfig.uploaddir)

	local localconfig = deep_copy(pluginconfig)
	if pluginconfig.testmode == nil then
		localconfig.testmode = true
	end

	postmake.make(shellscript, configs, localconfig)

	if postmake.os.uname.isunix() then
		local srcpath = postmake.output .. ".sh"
		os.execute("chmod +x " .. srcpath)


		---@type integer?
		local hascurrentconfig = nil

		for index, value in ipairs(configs) do
			if value.os() == postmake.os.uname.os() then
				hascurrentconfig = index
				break
			end
		end

		if hascurrentconfig then
			local exitcode = os.execute(srcpath)
			if exitcode ~= 0 then
				return false
			end

			local config = getconfig(configs[hascurrentconfig])[1]
			if not checkforfiles(postmake.appinstalldir, config) then
				return false
			end
		else
			print("skiped bacuase it does not have os")
		end

		return true
	end
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

	---@type boolean[]
	local liststaticservermode = { false, true }
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


	---@return boolean
	local function dostaticsevercheck(configs, config)
		local localseverport = "3000"
		local weburl = "http://localhost:" .. localseverport .. "/"

		local configcopy = deep_copy(config)
		configcopy.weburl = weburl
		configcopy.testmode = false

		local exitcode = os.execute("cd ../../staticserver && go build")
		if exitcode ~= 0 then
			print("go build failed with bad exit code")
			return false
		end

		local dir = postmake.path.absolute(configcopy.uploaddir)
		print("makeing staticserver on " .. weburl .. " on directory " .. dir)

		local serverproc = postmake.os.exec("../../staticserver/staticserver",
			{ localseverport, configcopy.uploaddir })
		serverproc.start()
		print("started server")

		postmake.os.sleep(1) -- wait a bit for the sever to start up.

		local test = shellscriptcheck(configs, configcopy)

		serverproc.kill()
		return test
	end

	if true then
		print("")
		print("runing uploaddir and weburl download test")

		local didok = dostaticsevercheck(configs, copy)
		if didok == false then
			print("failed uploaddir and weburl download test")
			return false
		end
		print("passed style test uploaddir and weburl")
	end

	print("runing matrices")
	print("")
	for _, compression in ipairs(listcompressiontypes) do
		for _, singlefile in ipairs(listofsinglefile) do
			for _, sytle in ipairs(liststyles) do
				for _, istaticserver in ipairs(liststaticservermode) do
					local configcopy = deep_copy(copy)

					if singlefile ~= nil then
						configcopy.singlefile = singlefile
					end
					configcopy.style = sytle
					configcopy.compressiontype = compression

					local test
					if istaticserver then
						test = shellscriptcheck(configs, configcopy)
					else
						test = dostaticsevercheck(configs, configcopy)
					end
					if test == false then
						local outputstring = "failed matric test [style:" .. sytle .. ",";
						outputstring = outputstring ..
						    "singlefile:" .. valueif(singlefile == nil, "true", "false") .. ","
						outputstring = outputstring .. "compressiontype:" .. compression .. ","
						outputstring = outputstring ..
						    "isstaticserver:" .. tostring(istaticserver) .. ","


						print(outputstring)
						return false
					end
					print("")
				end
			end
		end
	end

	print("passed runing matrices")

	return true
end

--- @param configs Config[]
--- @param pluginconfig GitHubActionConfig
--- @return boolean
local function githubcheck(configs, pluginconfig)
	local outputfiles = postmake.output

	if postmake.os.exist(outputfiles) then
		postmake.os.rmall(outputfiles)
	end
	if postmake.os.exist(postmake.appinstalldir) then
		postmake.os.rmall(postmake.appinstalldir)
	end
	if postmake.os.exist(pluginconfig.uploaddir) then
		postmake.os.rmall(pluginconfig.uploaddir)
	end

	postmake.os.mkdirall(outputfiles)
	postmake.os.mkdirall(postmake.appinstalldir)
	postmake.os.mkdirall(pluginconfig.uploaddir)

	local localseverport = "3000"
	local weburl = "http://localhost:" .. localseverport .. "/"

	local localconfig = deep_copy(pluginconfig)
	localconfig.testmode = true
	localconfig.weburl = weburl

	local oldp = postmake.appinstalldir
	postmake.appinstalldir = postmake.path.absolute(oldp)
	print(oldp)
	print(postmake.appinstalldir)

	postmake.make(githubaction, configs, localconfig)

	local actionpath = postmake.path.absolute(postmake.output .. "/githubaction")


	local function onfuncexit()
		postmake.appinstalldir = oldp
	end

	if true then
		---@type integer?
		local hascurrentconfig = nil

		for index, value in ipairs(configs) do
			if value.os() == postmake.os.uname.os() then
				hascurrentconfig = index
				break
			end
		end

		if hascurrentconfig then
			local exitcode = os.execute("cd " .. actionpath .. " && make")
			if exitcode ~= 0 then
				onfuncexit()
				return false
			end

			local dir = postmake.path.absolute(pluginconfig.uploaddir)
			print("makeing staticserver on " .. weburl .. " on directory " .. dir)

			local serverproc = postmake.os.exec("../../staticserver/staticserver",
				{ localseverport, pluginconfig.uploaddir })
			serverproc.start()
			print("started server")

			postmake.os.sleep(1) -- wait a bit for the sever to start up.

			exitcode = os.execute("cd " .. actionpath .. " && node ./dist/index.js")
			serverproc.kill()

			if exitcode ~= 0 then
				onfuncexit()
				return false
			end

			local config = getconfig(configs[hascurrentconfig])[1]
			if not checkforfiles(postmake.appinstalldir, config) then
				onfuncexit()
				return false
			end
		else
			print("skiped bacuase it does not have os")
		end

		onfuncexit()
		return true
	end

	onfuncexit()
	return true
end
--- @param configs Config[]
--- @param pluginconfig GitHubActionConfig
--- @return boolean
local function runtestgithubaction(configs, pluginconfig)
	---@type shellscriptcompressiontype[]
	local listcompressiontypes = { 'tar.gz', 'zip' }

	---@type string[]
	local listsinglefile = { "", "singlefile" }

	---@type boolean[]
	local listversion = { false, true }
	---
	local copy = deep_copy(pluginconfig)

	print("runing basic test")
	local basic = githubcheck(configs, pluginconfig)
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

		local test = githubcheck(configs, configcopy)
		if test == false then
			print("failed compression test " .. value)
			return false
		end
		print("passed compression test " .. value)
	end


	for _, value in ipairs(listsinglefile) do
		print("")
		print("runing single type " .. tostring(value))

		local configcopy = deep_copy(copy)
		if value ~= "" then
			configcopy.singlefile = value
		end

		local test = githubcheck(configs, configcopy)
		if test == false then
			print("-- failed single file test " .. value)
			return false
		end
		print("passed single file test " .. value)
	end

	for _, value in ipairs(listversion) do
		print("")
		print("runing version type " .. tostring(value))

		local configcopy = deep_copy(copy)
		if value then
			configcopy.version = {}
		end

		local test = githubcheck(configs, pluginconfig)
		if test == false then
			print("failed version test " .. tostring(value))
			return false
		end
		print("passed version test " .. tostring(value))
	end

	print("runing matrices")
	print("")
	for _, compression in ipairs(listcompressiontypes) do
		for _, singlefile in ipairs(listsinglefile) do
			for _, version in ipairs(listversion) do
				local configcopy = deep_copy(copy)

				if version ~= nil then
					configcopy.version = {}
				end
				configcopy.compressiontype = compression
				if singlefile ~= "" then
					configcopy.singlefile = singlefile
				end

				local test = githubcheck(configs, configcopy)

				if test == false then
					local outputstring = "failed matric test [";
					outputstring = outputstring ..
					    "singlefile:" .. valueif(singlefile == nil, "true", "false") .. ","
					outputstring = outputstring .. "compressiontype:" .. compression .. ","
					outputstring = outputstring ..
					    "version:" .. tostring(version) .. ","


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
	elseif plugin == githubaction then
		print("trying to run all config test")
		local alltests = runtestgithubaction(configs, pluginconfig)
		if alltests == false then
			print("allconfig test failed for githubaction")

			return false
		end
		print("")

		local hasfailed = false
		for index, value in ipairs(configs) do
			print("trying to single config test")
			local onetest = runtestgithubaction({ value }, pluginconfig)

			if onetest == false then
				hasfailed = true
				print("single test at index " .. tostring(index) .. " failed for githubaction")
			end
			print("")
		end

		return not hasfailed
	end
	return false
end

return m

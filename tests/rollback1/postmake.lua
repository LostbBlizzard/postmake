local shellscript = postmake.loadplugin("internal/shellscript")

---@type testpostmakemodule
-- local postmaketest = dofile("../testutils/init.lua")

---@class filestate
---@field path string
---@field hash string
---@field isrunable string

---@param dir string
---@return filestate[]
local function getdirstate(dir)
	---@type filestate[]
	local r = {}

	local fullpath = postmake.path.absolute(dir)
	postmake.os.tree(fullpath, function(path)
		if postmake.os.IsFile(path) then
			local relpath = path:sub(fullpath:len() - 2)

			table.insert(r, {
				path = relpath,
				hash = postmake.os.sha256sum.hashfile(path),
				isrunable = false
			})
		end
	end)

	return r
end

---@param list1 filestate[]
---@param list2 filestate[]
---@param diffcallback? fun(v1:filestate,v2:filestate)
---@return boolean
local function isthesame(list1, list2, diffcallback)
	local isbad = false
	for index, value in ipairs(list1) do
		local value2 = list2[index]

		if value.hash ~= value2.hash then
			if diffcallback ~= nil then
				diffcallback(value, value2)
			end
			isbad = true
		end

		if value.path ~= value2.path then
			if diffcallback ~= nil then
				diffcallback(value, value2)
			end
			isbad = true
		end

		if value.isrunable ~= value2.isrunable then
			if diffcallback ~= nil then
				diffcallback(value, value2)
			end
			isbad = true
		end
	end

	return not isbad
end

---@generic T : any
---@param array T[]
---@param callback fun(item:T)
local function foreach(array, callback)
	for _, value in ipairs(array) do
		callback(value)
	end
end

-- App Settings
postmake.appname = "app"
postmake.appversion = "0.0.1"
postmake.output = "./output/install"
postmake.appinstalldir = "./installedapp"


local localseverport = "3000"
local weburl = "http://localhost:" .. localseverport .. "/"
local uploadir = "./uploadir/"

local function makeversion1()
	--- Configs
	local gnu = postmake.newconfig("linux", "universal")
	local mac = postmake.newconfig("macos", "universal")

	--- Add Your files

	local configs = { gnu, mac }

	foreach(configs, function(item)
		item.addfile("./v1/mainfile", postmake.installdir() .. "mainfile")
		item.addfile("./v1/dir/**.txt", postmake.installdir() .. "dir")
	end)

	if not postmake.os.exist(postmake.appinstalldir) then
		postmake.os.mkdir(postmake.appinstalldir)
	end

	if not postmake.os.exist("./output") then
		postmake.os.mkdir("./output")
	end

	postmake.make(shellscript, configs,
		---@type ShellScriptConfig
		{
			weburl = weburl,
			uploaddir = uploadir,
			rollbackonfail = true,
			checksum = 'sha256',
			silent = true
		});
end

---@param onversiontwo? fun(config:Config)
---@param severout? fun(dir:string)
local function makeversion2(onversiontwo, severout)
	local gnu2 = postmake.newconfig("linux", "universal")
	local mac2 = postmake.newconfig("macos", "universal")

	local configs = { gnu2, mac2 }

	foreach(configs, function(item)
		item.addfile("./v2/mainfile", postmake.installdir() .. "mainfile")
		item.addfile("./v2/dir/**.txt", postmake.installdir() .. "dir")

		if onversiontwo ~= nil then
			onversiontwo(item)
		end
	end)


	if not postmake.os.exist("./output") then
		postmake.os.mkdir("./output")
	end




	postmake.make(shellscript, configs,
		---@type ShellScriptConfig
		{
			weburl = weburl,
			uploaddir = uploadir,
			rollbackonfail = true,
			checksum = 'sha256',
			silent = true
		});

	if severout ~= nil then
		severout(uploadir)
	end
end

---@param onversiontwo? fun(config:Config)
---@param severout? fun(dir:string)
---@param overrideinstallrun? fun()
local function rollbackcheck(onversiontwo, severout, overrideinstallrun)
	makeversion1()

	if postmake.os.exist(postmake.appinstalldir) then
		postmake.os.rmall(postmake.appinstalldir)
	end

	os.execute("chmod +x ./output/install.sh")
	local staticserverpath = "../../staticserver/staticserver"

	local dir = postmake.path.absolute(uploadir)
	-- print("makeing staticserver on " .. weburl .. " on directory " .. dir)

	local serverproc = postmake.os.exec(staticserverpath, { localseverport, uploadir })

	serverproc.start()

	-- print("started server")

	postmake.os.sleep(1) -- wait a bit for the sever to start up.

	os.execute("./output/install.sh >/dev/null")

	serverproc.kill()

	local v1 = getdirstate(postmake.appinstalldir)

	--- get the next version
	makeversion2(onversiontwo, severout)

	-- print("makeing staticserver on " .. weburl .. " on directory " .. dir)

	local serverproc2 = postmake.os.exec(staticserverpath, { localseverport, uploadir })

	serverproc2.start()

	-- print("started server")

	postmake.os.sleep(1) -- wait a bit for the sever to start up.

	if overrideinstallrun ~= nil then
		overrideinstallrun()
	else
		os.execute("./output/install.sh >/dev/null") -- this would fail
	end

	serverproc.kill()

	-- check if its the same
	local v2 = getdirstate(postmake.appinstalldir)


	if not isthesame(v1, v2, function(a, _)
		    print("the original " .. a.path .. " is not the same as old one")
	    end) then
		os.exit(1)
	end

	print("rollback worked")
end

---@param path string
local function messupfile(path)
	local file = io.open(path, "w")
	if file == nil then
		print("unable to messup file at " .. path)
		os.exit(1)
	end

	for i = 1, 100, 1 do
		file:write("afkjafk")
	end


	file:close()
end

print("runing rollback on bad command")
local uploaddir = ""
rollbackcheck(function(config)
	config.addinstallcmd("false", {})
end, function(dir)
	uploaddir = dir
end, nil)

---@type string[]
local filestolist = {}

postmake.os.tree(uploaddir, function(filepath)
	if postmake.os.IsFile(filepath) then
		table.insert(filestolist, filepath)
	end
end)

print("runing on bad file")
for _, value in ipairs(filestolist) do
	print("bad file: wil be " .. value)

	rollbackcheck(nil, function(_)
		messupfile(value)
	end, nil)
end


print("runing on missing file")
for _, value in ipairs(filestolist) do
	print("bad missing: wil be " .. value)

	rollbackcheck(nil, function(_)
		postmake.os.rm(value)
	end, nil)
end


print("runing on interupted")
rollbackcheck(function(config)
	config.addinstallcmd("sleep", { "3" })
end, nil, function()
	-- local scriptproc = postmake.os.exec("bash", { "./output/install.sh" })
	local scriptproc = postmake.os.exec("echo", { "test " })

	scriptproc.onstdout(function(output)
		print("stdout:" .. output)
	end)

	scriptproc.onstderror(function(output)
		print("stderr:" .. output)
	end)

	scriptproc.start()

	postmake.os.sleep(1)
	scriptproc.sync()

	scriptproc.interrupt()

	postmake.os.sleep(3)

	scriptproc.sync()
end)

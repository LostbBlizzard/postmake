local innosetup = postmake.loadplugin("internal/innosetup")
local shellscript = postmake.loadplugin("internal/shellscript")
local githubaction = postmake.loadplugin("internal/githubaction")

local appversionenv = os.getenv("POSTMAKEVERSION")
-- App Settings
postmake.appname = "postmake"
postmake.appversion = "0.0.1"

if appversionenv ~= nil then
	postmake.appversion = appversionenv
end

postmake.appinstalldir = "~/.postmake"
postmake.applicensefile = "LICENSE.txt"
postmake.output = "./output/install"


if postmake.target() == "symlink" then
	-- This is great for debuging and quick fixing
	local function executeorexit(str)
		local exit = os.execute(str)

		if exit == nil then
			os.exit(1)
		end

		if exit ~= 0 then
			print("running command failed : '" .. str .. "'")
			os.exit(1)
		end
	end
	local function symlink(input, output)
		print("symlink " .. output .. " >> " .. input)

		local issymlink = false
		if issymlink then

		else
			if postmake.os.exist(output) then
				if postmake.os.IsFile(output) then
					postmake.os.rm(output)
				else
					postmake.os.rmall(output)
				end
			end

			postmake.os.ln(input, output)
		end
	end


	local thisinstalldir = postmake.path.absolute(postmake.appinstalldir) .. "/"

	local mainfile = thisinstalldir .. postmake.installdir() .. "/" .. postmake.appname
	if postmake.os.uname.os() == 'windows' then
		mainfile = mainfile .. ".exe"
	end
	postmake.os.mkdirall(thisinstalldir .. "bin")
	postmake.os.mkdirall(thisinstalldir .. "lua")

	executeorexit("go build")
	symlink(postmake.path.absolute("./postmake"), mainfile)
	symlink(postmake.path.absolute("lua/api"), thisinstalldir .. "lua/definitions")

	return
end

-- Short Hands
local all = postmake.allconfig

--- Configs
local win = postmake.newconfig("windows", "x64")
local gnu = postmake.newconfig("linux", "x64")

local mac = postmake.newconfig("macos", "x64")
local macarm64 = postmake.newconfig("macos", "arm64")

--- flags
local addpathflag = all.newflag("Add Path", true)
--- Add Your files

local unixmainprogram = postmake.installdir() .. "bin/" .. postmake.appname
local winsmainprogram = unixmainprogram .. ".exe"
win.addxfile("output/postmake.exe", winsmainprogram)
gnu.addxfile("output/postmake", unixmainprogram)
mac.addxfile("output/postmake_macos", unixmainprogram)
macarm64.addxfile("output/postmake_macos_arm64", unixmainprogram)

all.addfile("lua/api/**.lua", postmake.installdir() .. "lua/definitions")
all.addfile(postmake.applicensefile, postmake.installdir() .. "LICENSE.txt")

all.If(addpathflag).addpath(postmake.installdir())

local installwebsite = "https://github.com/LostbBlizzard/postmake/releases/download/Release-" .. postmake.appversion

postmake.make(shellscript, { gnu, mac, macarm64 },
	---@type ShellScriptConfig
	{
		weburl = installwebsite,
		uploaddir = "./output/upload/",
		uninstallfile = postmake.installdir() .. "postmake",
		proxy = {
			uninstallcmd = "uninstall",
			program = postmake.installdir() .. "bin/" .. postmake.appname
		},
		singlefile = "shellscriptinstalldata",
	});
postmake.make(innosetup, { win },
	---@type InnoSetConfig
	{
		AppId = "x1miKP6buq3AuaLlXa7jsDZnMpPYz3vYm8dSJZyMcahk3A3AlNAJYFuXlfFJXbXemGeEoMBwvZi",
		LaunchProgram = postmake.installdir() .. postmake.appname,
		proxy = {
			path = postmake.installdir() .. postmake.appname,
			uninstallcmd = "uninstall",
			program = winsmainprogram
		},
	});

postmake.make(githubaction, { win, gnu, mac, macarm64 },
	---@type GitHubActionConfig
	{
		weburl = installwebsite,
		uploaddir = "./output/githubactionupload/",
		singlefile = "githubactioninstalldata",
		version = {
			getdatabase =
			"https://raw.githubusercontent.com/LostbBlizzard/postmake-action/refs/heads/master/database.json"
		},
		proxy = {
			path = postmake.installdir() .. postmake.appname,
			program = unixmainprogram
		}
	});

local build = {}

local assertpathmustnothaveslash = postmake.lua.assertpathmustnothaveslash
local json = postmake.json
local lua = postmake.lua

---@type ShellScriptPlugin
---@diagnostic disable-next-line: assign-type-mismatch
local shellscript = postmake.loadplugin("internal/shellscript")

local AllowedSettingsFields = {
	"weburl",
	"uploaddir",
	"singlefile",
	"version",
	"export",
	"dependencies",
	"testmode",
	"compressiontype"
}

local programinstalldir = ""
local function resolveoutputpath(path)
	return programinstalldir .. path
end

local indent = "    "
local indent2 = indent .. indent

local function flagtovarable(flagname)
	return "flag_" .. flagname:gsub(" ", "_")
end

local function flagtoactioninput(flagname)
	return flagname:gsub(" ", "_")
end
local function ostoosvarable(osname)
	if osname == "windows" then
		return "isWin"
	elseif osname == "linux" then
		return "isLinux"
	elseif osname == "macos" then
		return "isMac"
	else
		print("error unknown os '" .. osname .. "'")
		os.exit(1)
	end
end
local function archtonodearch(arch)
	if arch == "x64" then
		return "x64"
	elseif arch == "x32" then
		return "x32"
	elseif arch == "arm64" then
		return "arm64"
	else
		print("error unknown arch '" .. arch .. "'")
		os.exit(1)
	end
end

---@param compressiontype shellscriptcompressiontype
local function getzipext(compressiontype)
	if compressiontype == 'tar.gz' then
		return ".tar.gz"
	elseif compressiontype == 'zip' then
		return ".zip"
	end
end

---@param inputfiles { [string]: string }
---@param output string
local function archive(compressiontype, inputfiles, output)
	if compressiontype == "tar.gz" then
		postmake.archive.make_tar_gz(inputfiles, output)
	elseif compressiontype == "zip" then
		postmake.archive.make_zip(inputfiles, output)
	end
end


---@param path string
---@return string
local function linuxpathtowindows(path)
	local r = path:gsub("~/", "%userprofile%/")
	return r
end

local function ispathcmd(path)
	return string.find(path, "/", nil, true) or string.find(path, ".", nil, true)
end

local unziphint = "**"

---@param outputfile file*
---@param cmd plugincmd
---@param iswindows boolean
local function writecomds(outputfile, cmd, iswindows)
	local stringtowrite = "execSync("

	if ispathcmd(cmd.cmd()) then
		if iswindows then
			stringtowrite = stringtowrite .. "revolvewindowspath("
		end
		stringtowrite = stringtowrite .. "\""

		if iswindows then
			stringtowrite = stringtowrite .. linuxpathtowindows(resolveoutputpath(cmd.cmd()))
			stringtowrite = stringtowrite .. "\") + \""
		else
			stringtowrite = stringtowrite .. resolveoutputpath(cmd.cmd())
		end
	else
		stringtowrite = "\"" .. stringtowrite .. cmd.cmd()
	end

	for _, value in ipairs(cmd.pars()) do
		stringtowrite = stringtowrite .. " "
		if ispathcmd(value) then
			if iswindows then
				stringtowrite = stringtowrite .. "\" + revolvewindowspath(\""
			end

			if iswindows then
				stringtowrite = stringtowrite .. linuxpathtowindows(resolveoutputpath(value))
				stringtowrite = stringtowrite .. "\") + \""
			else
				stringtowrite = stringtowrite .. resolveoutputpath(value)
			end
		else
			stringtowrite = stringtowrite .. value
		end
	end
	stringtowrite = stringtowrite .. "\")"

	outputfile:write(stringtowrite)
end


---@param cmd plugincmd
---@return programcmd
local function cmdtoprogramcmd(cmd)
	---@type programcmd
	local newcmd = {
		cmd = cmd.cmd(),
		pars = {},
	}
	for _, value in ipairs(cmd.pars()) do
		local newitem
		if ispathcmd(value) then
			newitem = resolveoutputpath(value)
		else
			newitem = value
		end
		table.insert(newcmd.pars, newitem)
	end

	if ispathcmd(cmd.cmd()) then
		newcmd.cmd = resolveoutputpath(newcmd.cmd)
	end

	return newcmd
end

---@class versionprogramconfig
---@field programversion programversion?

---@param myindent string
---@param outputfile file*
---@param config pluginconfig
---@param weburl string
---@param uploaddir string
---@param uploadfilecontext any
---@param compressiontype shellscriptcompressiontype
---@param versionprogramconfig versionprogramconfig?
local function onconfig(myindent, outputfile, config, weburl, uploaddir, uploadfilecontext, compressiontype,
			singlefile, dirspit,
			versionprogramconfig)
	---@type { archivepath: string, files: string[] }[]
	local archivestomake = {}


	local singledir
	if singlefile then
		singledir = uploaddir .. singlefile
	end

	local iswindowsos = false
	if config.os ~= nil then
		iswindowsos = config.os() == "windows"
	else
		if string.find(dirspit, "windows") then
			iswindowsos = true
		end
	end
	local isunix = not iswindowsos

	for inputtable, output in pairs(config.files) do
		local input = inputtable.string()

		if postmake.match.isbasicmatch(input) then
			local newout = resolveoutputpath(output)
			local newfilename = shellscript.GetUploadfilePath(input, uploadfilecontext,
				function(input2, newfilename)
					if singlefile ~= nil then
						local filepathtostore = singledir .. "/" .. dirspit .. output
						postmake.os.mkdirall(postmake.path.getparent(filepathtostore))
						postmake.os.cp(input2, filepathtostore)
					elseif uploaddir ~= nil then
						postmake.os.cp(input2, uploaddir .. newfilename)
					end
				end)


			if versionprogramconfig ~= nil then
				local newfileinput = newfilename
				if singlefile ~= nil then
					newfileinput = output
				end

				---@type programfile
				local newfile = {
					fileinput = newfileinput,
					fileoutput = newout,
					isexecutable = inputtable.isexecutable(),
				}

				table.insert(versionprogramconfig.programversion.files, newfile)
			else
				if singlefile then
					local startingfilepath = resolveoutputpath("/" .. singlefile) ..
					    "/" ..
					    dirspit .. output

					local outputfilepath = newout
					if iswindowsos then
						outputfilepath = linuxpathtowindows(outputfilepath)
						startingfilepath = linuxpathtowindows(startingfilepath)
					end

					outputfile:write(myindent ..
						"fs.renameSync(\"" .. startingfilepath ..
						"\",\"" .. outputfilepath .. "\");\n\n")
				else
					local outputfilepath = newout

					if iswindowsos then
						outputfilepath = linuxpathtowindows(outputfilepath)
					end

					outputfile:write(myindent ..
						"downloadfile(\"" ..
						weburl .. "/" .. newfilename .. "\",\"" .. outputfilepath .. "\");\n\n")
				end

				if isunix and inputtable.isexecutable() then
					outputfile:write(myindent ..
						"execSync(\"chmod +x\", \"" .. newout .. "\");\n")
				end
			end
		else
			local basepath = postmake.path.absolute(postmake.match.getbasepath(input))
			local basezippath = basepath .. getzipext(compressiontype)

			local newout = shellscript.GetUploadfilePath(basezippath, uploadfilecontext, nil)

			local myarchive
			for _, value in ipairs(archivestomake) do
				if value.archivepath == newout then
					myarchive = value
					break
				end
			end

			local isfirst = false
			if myarchive == nil then
				myarchive = {
					archivepath = newout,
					files = {}
				}
				if singlefile ~= nil then
					myarchive.archivepath = output .. getzipext(compressiontype)
				end

				table.insert(archivestomake, myarchive)
				isfirst = true
			end

			postmake.match.matchpath(input, function(path)
				local fullpath = postmake.path.absolute(path)
				local zippath = string.sub(fullpath, #basepath + 2, #fullpath)

				myarchive.files[path] = zippath
			end)

			if isfirst then
				if versionprogramconfig == nil then
					if singlefile then
						local ext = "." .. compressiontype

						local startingfilepath = resolveoutputpath("/" .. singlefile) ..
						    "/" ..
						    dirspit .. output .. ext

						local outputfilepath = resolveoutputpath(output)

						if iswindowsos then
							outputfilepath = linuxpathtowindows(outputfilepath)
							startingfilepath = linuxpathtowindows(startingfilepath)
						end

						outputfile:write(myindent ..
							"await unzipdir(\"" .. startingfilepath ..
							"\",\"" .. outputfilepath .. "\");\n\n")
					else
						local startingfilepath = resolveoutputpath("/" .. newout)
						local outputfilepathnoext = resolveoutputpath(output)

						if iswindowsos then
							outputfilepathnoext = linuxpathtowindows(outputfilepathnoext)
							startingfilepath = linuxpathtowindows(startingfilepath)
						end

						local outputfilepath = outputfilepathnoext
						    .. postmake.path.getfullfileext(startingfilepath)



						outputfile:write(myindent ..
							"downloadfile(\"" ..
							weburl .. "/" .. newout .. "\",\"" .. outputfilepath .. "\");\n")

						outputfile:write(myindent ..
							"await unzipdir(\"" .. outputfilepath ..
							"\",\"" .. outputfilepathnoext .. "\");\n")


						outputfile:write(myindent ..
							"removefile(\"" .. outputfilepath .. "\");\n\n")
					end
				else
					local newfileinput = newout
					if singlefile ~= nil then
						local ext = "." .. compressiontype
						newfileinput = output .. ext
					end

					---@type programfile
					local newfile = {
						fileinput = newfileinput,
						fileoutput = resolveoutputpath(output) .. unziphint,
						isexecutable = false
					}

					table.insert(versionprogramconfig.programversion.files, newfile)
				end
			end
		end
	end

	for _, output in pairs(config.paths) do
		if versionprogramconfig ~= nil then
			table.insert(versionprogramconfig.programversion.paths, resolveoutputpath(output))
		else
			local pathtoadd = resolveoutputpath(output)

			if iswindowsos then
				pathtoadd = linuxpathtowindows(pathtoadd)
			end
			outputfile:write(myindent .. "addpath(\"" .. pathtoadd .. "\");\n")
		end
	end


	if versionprogramconfig ~= nil then
		for _, cmd in ipairs(config.installcmds) do
			table.insert(versionprogramconfig.programversion.installcmd, cmdtoprogramcmd(cmd))
		end

		for _, cmd in ipairs(config.uninstallcmds) do
			table.insert(versionprogramconfig.programversion.uninstallcmd, cmdtoprogramcmd(cmd))
		end
	else
		for _, cmd in ipairs(config.installcmds) do
			outputfile:write(myindent)
			writecomds(outputfile, cmd, iswindowsos)
			outputfile:write("\n")
		end
	end


	for _, value in ipairs(archivestomake) do
		local outpath = ""

		if singlefile then
			outpath = singledir .. "/" .. dirspit .. "/" .. value.archivepath

			local parent = postmake.path.getparent(outpath);
			if not postmake.os.exist(parent) then
				postmake.os.mkdirall(parent)
			end
		else
			outpath = uploaddir .. value.archivepath
		end

		archive(compressiontype, value.files, outpath)
	end
end

---@param databaseurl string?
---@return string
local function getversionindexjsfile(databaseurl)
	local r = "try {\n"
	if databaseurl ~= nil then
		r = r .. "downloadfile(" .. databaseurl .. "\");\n"
	end

	r = r .. "const data = fs.readFileSync('database.json', 'utf8');\n"
	r = r .. "const databaseinfo = JSON.parse(data);\n\n"
	r = r .. "var foundversion = false;\n\n"
	r = r .. "for (var i = 0; i < databaseinfo.versions.length; i++) {\n"
	r = r .. "var programversion = databaseinfo.versions[i]\n"

	r = r ..
	    "if (programversion.version == versiontodownload || (i == databaseinfo.versions.length - 1 && versiontodownload == \"latest\")) {\n\n"

	r = r .. "var downloadurl = programversion.downloadurl\n"
	r = r .. "for (var i = 0; i < programversion.programs.length; i++) {\n"

	r = r .. "    var program = programversion.programs[i]\n"
	r = r ..
	    "    if (program.os == process.platform && (program.arch == process.arch || program.arch == \"universal\")) {\n"
	r = r ..
	    "        console.log(\"downloading \" + programversion.version + \" \" + program.os + \"-\" + program.arch);\n"

	r = r .. "        fs.mkdirSync(programversion.installdir, { recursive: true })\n\n"

	r = r .. "        var hassinglefile = programversion.singlefile != \"\"\n"
	r = r .. "        var singlefiledir = \"\"\n"
	r = r .. "        if (hassinglefile) {\n"
	r = r ..
	    "            var singlefilepath = programversion.installdir + \"/\" + programversion.singlefile\n"
	r = r .. "            singlefiledir = singlefilepath.substring(0, singlefilepath.indexOf('.'))\n"
	r = r .. "            downloadfile(downloadurl + \"/\" + programversion.singlefile, singlefilepath)\n"
	r = r .. "            await unzipdir(singlefilepath, singlefiledir)\n"
	r = r .. "            removefile(singlefilepath)\n"
	r = r .. "        }\n\n"


	r = r .. "        for (var i = 0; i < program.paths.length; i++) {\n"
	r = r .. "            addpath(program.paths[i])\n"
	r = r .. "        }\n"
	r = r .. "        for (var i = 0; i < program.files.length; i++) {\n"
	r = r .. "            var newfile = program.files[i]\n"
	r = r .. "            var unzip = endsWith(newfile.fileoutput, \"" .. unziphint .. "\")\n\n"
	r = r .. "            if (hassinglefile) {\n"
	r = r .. "            var movedir = singlefiledir + \"/\" + program.os + \"-\" + program.arch\n"

	r = r .. "            if (unzip) {\n"
	r = r .. "             var movefilepath = movedir + \"/\" + newfile.fileinput\n"
	r = r .. "             var outpath = newfile.fileoutput\n"
	r = r .. "             outpath = outpath.substr(0, outpath.length - 2)\n"
	r = r .. "             await unzipdir(movefilepath, outpath)\n"
	r = r .. "            } else \n {\n"

	r = r .. "            var movefilepath = movedir + \"/\" + newfile.fileinput\n"
	r = r .. "            var outpath = newfile.fileoutput\n"
	r = r .. "            var d = path.dirname(outpath)\n"
	r = r .. "            fs.mkdirSync(d, { recursive: true })\n"
	r = r .. "            fs.renameSync(movefilepath, outpath);\n"
	r = r .. "            if (newfile.isexecutable) { fs.chmodSync(outpath, fs.constants.X_OK) }\n"


	r = r .. "}\n   } else {\n "
	r = r .. "            if (unzip) {\n"
	r = r .. "                       var ext = getfileext(newfile.fileinput)\n"
	r = r .. "                       var name = newfile.fileoutput.substr(0, newfile.fileoutput.length -" ..
	    tostring(unziphint:len()) .. ")\n"

	r = r .. "                       var newp = name + ext\n\n"

	r = r .. "                       var d = path.dirname(newp)\n"
	r = r .. "                       fs.mkdirSync(d, { recursive: true })\n\n"

	r = r .. "                       downloadfile(downloadurl + \"/\" + newfile.fileinput, newp)\n"
	r = r .. "                       await unzipdir(newp, name)\n"
	r = r .. "                       removefile(newp)\n"
	r = r .. "            } else {\n"
	r = r .. "            var d = path.dirname(newfile.fileoutput)\n"
	r = r .. "            fs.mkdirSync(d, { recursive: true })\n"
	r = r .. "            downloadfile(downloadurl + \"/\" + newfile.fileinput, newfile.fileoutput)\n"
	r = r .. "            if (newfile.isexecutable)  {  fs.chmodSync(newfile.fileoutput, fs.constants.X_OK) }\n"

	r = r .. "            }\n"
	r = r .. "        }\n } \n"
	r = r .. "        if (hassinglefile) {\n"
	r = r .. "           removedir(singlefiledir);\n"
	r = r .. "        }\n"
	r = r .. "        foundversion = true\n"
	r = r .. "        break\n"
	r = r .. "    }\n"
	r = r .. "}\n"
	r = r .. "if (foundversion) {\n"
	r = r .. "    break\n"
	r = r .. "}\n"
	r = r .. "}\n"
	r = r .. "}\n"
	r = r .. "} catch (err) {\n"
	r = r ..
	    "console.error(\"failed to install program because of error\");\n console.error(err); process.exit(1); \n"
	r = r .. "}\n"

	r = r .. "if (!foundversion) {\n"
	r = r .. "console.log(\"This Program cant be Installed on this system\");\n"
	r = r .. "process.exit(1);\n"
	r = r .. "}"
	return r
end

---@class programfile
---@field fileinput string
---@field fileoutput string
---@field isexecutable boolean

---@class programcmd
---@field cmd string
---@field pars string[]

---@class programversion
---@field os ostype
---@field arch archtype
---@field files programfile[]
---@field paths string[]
---@field installcmd programcmd[]
---@field uninstallcmd programcmd[]

---@class versiondata
---@field postmakeversion string
---@field version string
---@field installdir string
---@field downloadurl string
---@field programs programversion[]
---@field singlefile string

---@class programdatabase
---@field versions versiondata[]

---@param postmake pluginpostmake
---@param configs pluginconfig[]
---@param settings GitHubActionConfig
function build.make(postmake, configs, settings)
	-- boring checks
	if settings.weburl == nil then
		print("error settings must have the 'weburl' field set")
		os.exit(1)
	end
	local goterrorinsettings = false
	for key, _ in pairs(settings) do
		local issettingallowed = false

		for _, field in ipairs(AllowedSettingsFields) do
			if key == field then
				issettingallowed = true
				break
			end
		end

		if issettingallowed then
			goto continue
		end
		print("The Key '" .. key .. "' is not an  valid github action Settings. Typo?\n")
		goterrorinsettings = true
		::continue::
	end
	if goterrorinsettings then
		print("GithubAction  only allows for ")
		for i, field in ipairs(AllowedSettingsFields) do
			print(field)

			if i ~= #AllowedSettingsFields then
				print(",")
			end
		end
		print(" to be in the setting")
		os.exit(1)
	end

	assertpathmustnothaveslash(postmake.appinstalldir(), "postmake.appinstalldir")

	local outputpathdir = "./" .. postmake.output() .. "/githubaction/"
	local srcdir = outputpathdir .. "./src/"

	print("---building github action to " .. outputpathdir)

	programinstalldir = postmake.appinstalldir();

	local weburl = settings.weburl
	local uploaddir = settings.uploaddir
	local singlefile = settings.singlefile
	local version = settings.version
	local compressiontype = settings.compressiontype
	if compressiontype == nil then
		compressiontype = "tar.gz"
	end

	local istestmode = false
	if settings.testmode ~= nil then
		istestmode = settings.testmode
	end


	postmake.os.mkdirall(outputpathdir)
	postmake.os.mkdirall(srcdir)

	if settings.uploaddir ~= nil then
		postmake.os.mkdirall(settings.uploaddir)
	end

	local indexjsfilepath = srcdir .. "index.js"
	local actionymlpath = outputpathdir .. "action.yml"
	local packagejsonpath = outputpathdir .. "package.json"
	local gitignorepath = outputpathdir .. ".gitignore"
	local readmepath = outputpathdir .. "README.md"
	local makefilepath = outputpathdir .. "Makefile"

	local workflowpath = outputpathdir .. "./.github/workflows/"
	local ciworkflowpath = workflowpath .. "CI.yml"


	---@type versionprogramconfig?
	local versionprogramconfig = nil
	---@type versiondata?
	local newprogramversion = nil
	---@type programdatabase?
	local olddata = nil

	---@type {name:string,isflag:boolean,defaultvalue:string}[]
	local allflags = {}

	if version ~= nil then
		---@cast version VersionSetting

		---@type programdatabase
		olddata = { versions = {} }
		if version.getdatabase ~= nil then
			if type(version.getdatabase) == "string" then
				---@type string
				local url = version.getdatabase
				if url:find("https://") then
					local jsontext = postmake.os.curl.downloadtext(url)
					olddata = json.decode(jsontext)
				else
					local function read_file(path)
						local file = io.open(path, "rb") -- r read mode and b binary mode
						if not file then return nil end
						local content = file:read "*a" -- *a or *all reads the whole file
						file:close()
						return content
					end
					local jsontext = read_file(url)
					olddata = json.decode(jsontext)
				end
			else
				if type(version.getdatabase) == "function" then
					---@type fun():string
					local func = version.getdatabase
					olddata = json.decode(func())
				else
					print("version.getdatabase is not an string or an function")
					os.exit(1)
				end
			end
		end


		---@type versiondata
		newprogramversion = {
			postmakeversion = "1",
			version = postmake.appversion(),
			installdir = postmake.appinstalldir(),
			downloadurl = settings.weburl,
			singlefile = lua.valueif(singlefile == nil, "", function()
				return singlefile .. getzipext(compressiontype)
			end),
			programs = {}
		}
		table.insert(olddata.versions, newprogramversion)
	end

	if singlefile ~= nil then
		local ext = getzipext(compressiontype)
		local mainfile = uploaddir .. singlefile .. ext
		local maindir = uploaddir .. singlefile

		if not postmake.os.exist(maindir) then
			postmake.os.mkdirall(maindir)
		end

		postmake.os.ls(maindir, function(path)
			postmake.os.rmall(path)
		end)

		if postmake.os.exist(mainfile) then
			postmake.os.rm(mainfile)
		end
	end

	local indexfile = io.open(indexjsfilepath, "w")

	if indexfile == nil then
		print("unable to open file '" .. indexjsfilepath .. "'")
		os.exit(1)
	end

	postmake.os.mkdirall(workflowpath)

	local indexfile = io.open(indexjsfilepath, "w")

	if indexfile == nil then
		print("unable to open file '" .. indexjsfilepath .. "'")
		os.exit(1)
	end

	local hasfiles = true
	local haspath = true

	for _, config in ipairs(configs) do
		if #config.paths ~= 0 then
			haspath = true
		end
		if #config.files ~= 0 then
			hasfiles = true
		end
		for _, subconfig in ipairs(config.ifs) do
			if #subconfig.paths ~= 0 then
				haspath = true
			end
			if #subconfig.files ~= 0 then
				hasfiles = true
			end
			for _, value in ipairs(subconfig.iflist) do
				local hasvalue = false
				for _, flagitem in ipairs(allflags) do
					if flagitem.name == value.flagname() then
						hasvalue = true
						break
					end
				end
				if hasvalue == false then
					table.insert(allflags,
						{
							name = value.flagname(),
							isflag = value.isflag(),
							defaultvalue = value.value()
						})
				end
			end
		end
	end

	if not istestmode then
		indexfile:write("const core = require('@actions/core');\n")
		indexfile:write("const github = require('@actions/github');\n")
	end
	indexfile:write("const fs = require('fs');\n")
	indexfile:write("const path = require('path');\n")
	indexfile:write("const tar = require('tar');\n")
	indexfile:write("const AdmZip = require('adm-zip');\n")


	if hasfiles then
		indexfile:write("const { execSync } = require(\"child_process\");\n")
	end

	indexfile:write("\nvar isWin = process.platform === \"win32\";\n")
	indexfile:write("var isLinux = process.platform === \"linux\";\n")
	indexfile:write("var isMac = process.platform === \"darwin\";\n")
	indexfile:write("var isUnix = isLinux || isMac;\n\n")

	if hasfiles then
		indexfile:write("function getfileext(filepath) {\n")
		indexfile:write("    var ext = filepath.substring(filepath.indexOf('.'));\n")
		indexfile:write("    return ext;\n")
		indexfile:write("}\n")


		indexfile:write("function endsWith(str, suffix) {\n")
		indexfile:write("    return str.indexOf(suffix, str.length - suffix.length) !== -1;\n")
		indexfile:write("}\n")


		indexfile:write("\nfunction downloadfile(url, outputfile) {\n")
		indexfile:write(indent .. "var command = \"curl -L \" + url + \" -o \" + outputfile;\n")

		indexfile:write(indent .. "if (isUnix) {\n")
		indexfile:write(indent2 .. "       command = \"curl -L \" + url + \" -o \" + outputfile;\n")
		indexfile:write(indent .. "} else {\n")
		indexfile:write(indent2 .. "       command = \"curl.exe -L \" + url + \" -o \" + outputfile;\n")
		indexfile:write(indent .. "}\n")

		indexfile:write(indent .. "child = execSync(command, null);\n")
		indexfile:write("}\n")


		indexfile:write("\nasync function unzipdir(inputpath,outputpath) {\n")

		indexfile:write("var ext = getfileext(inputpath)\n")
		indexfile:write("if (ext == \".zip\") {\n")
		indexfile:write("fs.mkdirSync(outputpath, { recursive: true })\n")
		indexfile:write("const zip = new AdmZip(inputpath);\n")
		indexfile:write("zip.extractAllTo(outputpath,true);\n")
		indexfile:write("} else if (ext == \".tar.gz\") {\n")
		indexfile:write("fs.mkdirSync(outputpath, { recursive: true })\n")
		indexfile:write("await tar.x({\n")
		indexfile:write("    file: inputpath,\n")
		indexfile:write("    C: outputpath,\n")
		indexfile:write("})\n")

		indexfile:write("} else {\n")
		indexfile:write("    throw new Error('unable to unzip file type of \' + ext + \"\'\");\n")
		indexfile:write("}\n")

		indexfile:write("}\n")

		indexfile:write("\nfunction removedir(path) {\n")
		indexfile:write(" fs.rmSync(path, { recursive: true, force: true });\n ")
		indexfile:write("}\n")

		indexfile:write("\nfunction removefile(path) {\n")
		indexfile:write(" fs.unlinkSync(path);\n ")
		indexfile:write("}\n")
	end
	if singlefile and not version then
		local singlefilevarable = "\nvar singlefilepath = \"" ..
		    postmake.appinstalldir() .. "/" .. singlefile .. "\"\n"
		indexfile:write("\nasync function downloadmainfile() {\n")

		indexfile:write(singlefilevarable)

		indexfile:write("downloadfile(\"" ..
			weburl ..
			"/" ..
			singlefile ..
			getzipext(compressiontype) .. "\",singlefilepath + \"" .. getzipext(compressiontype) .. "\")\n")

		indexfile:write("await unzipdir(singlefilepath + \"" ..
			getzipext(compressiontype) .. "\",singlefilepath)\n")

		indexfile:write("removefile(singlefilepath + \".tar.gz\")\n")

		indexfile:write("}\n")

		indexfile:write("\nfunction removemainfile() {\n")

		indexfile:write(singlefilevarable)

		indexfile:write("removedir(singlefilepath)\n")

		indexfile:write("}\n")
	end

	if haspath then
		indexfile:write("\nfunction addpath(path) {\n")
		if istestmode then
			indexfile:write(indent .. "console.log(\"addpath function was called with '\" + path + \"'\");\n")
		else
			indexfile:write(indent .. "core.addPath(path);\n")
		end
		indexfile:write("}\n")
	end

	local haswindowsconfig = true
	if haswindowsconfig then
		indexfile:write("\nfunction revolvewindowspath(path) {\n")
		indexfile:write("}\n")
	end
	indexfile:write("async function main() {\n")

	local uploadfilecontext = {}

	for _, value in ipairs(allflags) do
		local isexported = false
		if settings.export ~= nil then
			for _, exportitem in ipairs(settings.export) do
				if exportitem.flag.name() == value.name then
					isexported = true
					break
				end
			end
		end

		if isexported then
			indexfile:write("var " ..
				flagtovarable(value.name) .. " = " .. "github.getInput(\"" .. value.name .. "\"); \n")
		else
			indexfile:write("var " ..
				flagtovarable(value.name) ..
				" = " .. value.defaultvalue .. "; \n")
		end
	end
	if version then
		if istestmode then
			indexfile:write("\nvar versiontodownload = \"\";\n")
		else
			indexfile:write("\nvar versiontodownload = github.getInput('version');\n")
		end

		indexfile:write("if (versiontodownload == \"\") {\n")
		indexfile:write("     versiontodownload = \"latest\";\n")
		indexfile:write("}\n")
		indexfile:write(getversionindexjsfile(version.actiondatabaseurl))
	end

	indexfile:write("\n\n")
	for configindex, config in ipairs(configs) do
		if not version then
			if configindex == 1 then
				indexfile:write("if ")
			else
				indexfile:write("else if ")
			end

			indexfile:write("(" .. ostoosvarable(config.os()))
			if config.arch() ~= "universal" then
				indexfile:write(" && process.arch == \"" .. archtonodearch(config.arch()) .. "\"")
			end
			indexfile:write(") {\n")
		end

		if version ~= nil then
			---@type programversion
			local newprogram = {
				os = config.os(),
				arch = config.arch(),
				files = {},
				paths = {},
				installcmd = {},
				uninstallcmd = {}
			}

			for file, path in pairs(config.files) do
			end

			versionprogramconfig = {}
			versionprogramconfig.programversion = newprogram

			table.insert(newprogramversion.programs, newprogram)
		end

		if settings.dependencies ~= nil
		    and settings.dependencies.linux ~= nil
		    and settings.dependencies.linux.packages ~= nil
		    and settings.dependencies.linux.packages.apt ~= nil
		    and config.os() == 'linux'
		then
			local apt = settings.dependencies.linux.packages.apt

			local hasapt = false
			for value, _ in pairs(apt) do
				hasapt = true
				break
			end

			if hasapt then
				local cmd = "sudo apt install "
				for value, _ in pairs(apt) do
					cmd = cmd .. value
				end
				cmd = cmd .. " -y"

				indexfile:write("    execSync(\"" .. cmd .. "\")\n");
			end
		end
		if singlefile and not version then
			indexfile:write(" await downloadmainfile();\n")
		end
		local dirspit = config.os() .. "-" .. config.arch()
		onconfig(indent, indexfile, config, weburl, uploaddir, uploadfilecontext, compressiontype, singlefile,
			dirspit,
			versionprogramconfig)



		for _, output in ipairs(config.ifs) do
			local isfirstiniflistloop = true

			if not version then
				for _, output2 in ipairs(output.iflist) do
					if not isfirstiniflistloop then
						indexfile:write(" &&")
					else
						indexfile:write(indent .. "if (")
					end

					if output2.isflag() then
						indexfile:write(flagtovarable(output2.flagname()))
					else
						indexfile:write(flagtovarable(output2.flagname()) ..
							"\" == \"" .. output2.value() .. "\" ] ")
					end

					isfirstiniflistloop = false
				end

				indexfile:write(") {\n")
			end

			if singlefile ~= nil then
				uploadfilecontext = {}
			end

			local dirspit = config.os() .. "-" .. config.arch()
			onconfig(indent2, indexfile, output, weburl, uploaddir, uploadfilecontext, compressiontype,
				singlefile, dirspit,
				versionprogramconfig)

			if not version then
				indexfile:write(indent .. "}\n\n")
			end
		end

		if singlefile and not version then
			indexfile:write("    removemainfile();\n")
		end
		if not version then
			indexfile:write("}\n")
		end
	end


	if not version then
		indexfile:write("else {\n")
		indexfile:write(indent .. "console.log(\"This Program cant be Installed on this system\");\n")
		indexfile:write(indent .. "process.exit(1)\n")
		indexfile:write("}\n")
	end

	indexfile:write("}\n")
	indexfile:write("main();")

	indexfile:close()

	local actionymlfile = io.open(actionymlpath, "w")
	if actionymlfile == nil then
		print("unable to open file '" .. actionymlpath .. "'")
		os.exit(1)
	end

	local ProjectName = postmake.appname()
	local programname = postmake.appname()

	actionymlfile:write("name: '" .. programname .. "'\n")
	actionymlfile:write("description: 'Installs " .. programname .. "'\n")
	actionymlfile:write("runs:\n")
	actionymlfile:write("  using: 'node20'\n")
	actionymlfile:write("  main: './dist/index.js'\n\n")

	local hasinputs = false
	if settings.export ~= nil then
		hasinputs = #settings.export ~= 0
	end

	if hasinputs then
		actionymlfile:write("inputs: \n")

		for _, value in ipairs(settings.export) do
			actionymlfile:write("  " .. flagtoactioninput(value.flag.name()) .. ":\n")
			actionymlfile:write("   description: '" .. "" .. "'\n")
			actionymlfile:write("   require: " .. lua.valueif(value.isrequired, "true", "false") .. "\n")
			actionymlfile:write("   default: '" .. value.flag.default() .. "'\n")
		end
	end

	actionymlfile:close()

	local packagejsonfile = io.open(packagejsonpath, "w")
	if packagejsonfile == nil then
		print("unable to open file '" .. packagejsonpath .. "'")
		os.exit(1)
	end


	packagejsonfile:write("{\n")
	packagejsonfile:write(indent .. "\"name\": \"" .. ProjectName .. "\",\n")
	packagejsonfile:write(indent .. "\"version\": \"" .. postmake.appversion() .. "\",\n")
	packagejsonfile:write(indent .. "\"description\": \"Installs " .. programname .. "\",\n")
	packagejsonfile:write(indent .. "\"main\": \"index.js\",\n")
	packagejsonfile:write(indent .. "\"scripts\": {\n")
	packagejsonfile:write(indent .. "\"test\": \"echo \\\"Error: no test specified\\\" && exit 1\"\n")
	packagejsonfile:write(indent .. "},\n")
	packagejsonfile:write(indent .. "\"keywords\": [],\n")
	packagejsonfile:write(indent .. "\"author\": \"\",\n")
	packagejsonfile:write(indent .. "\"license\": \"ISC\",\n")
	packagejsonfile:write(indent .. "\"dependencies\": {\n")
	packagejsonfile:write(indent2 .. "\"@actions/core\": \"^1.10.1\",\n")
	packagejsonfile:write(indent2 .. "\"@actions/github\": \"^6.0.0\"\n")
	packagejsonfile:write(indent .. "}\n")
	packagejsonfile:write("}")

	packagejsonfile:close()



	local gitignorefile = io.open(gitignorepath, "w")
	if gitignorefile == nil then
		print("unable to open file '" .. gitignorepath .. "'")
		os.exit(1)
	end
	gitignorefile:write("node_modules/")
	gitignorefile:close()


	local readmefile = io.open(readmepath, "w")
	if readmefile == nil then
		print("unable to open file '" .. readmepath .. "'")
		os.exit(1)
	end
	readmefile:write("")
	readmefile:close()

	local makefile = io.open(makefilepath, "w")
	if makefile == nil then
		print("unable to open file '" .. makefilepath .. "'")
		os.exit(1)
	end
	makefile:write("build:\n")
	makefile:write("\tnpm install @actions/core\n\n")
	makefile:write("\tnpm install @actions/github\n\n")
	makefile:write("\tnpm install tar\n\n")
	makefile:write("\tnpm install adm-zip\n\n")
	makefile:write("\tncc build src/index.js -o dist\n\n")

	makefile:close()

	local workflowfile = io.open(ciworkflowpath, "w")
	if workflowfile == nil then
		print("unable to open file '" .. ciworkflowpath .. "'")
		os.exit(1)
	end
	workflowfile:write("on: [push,workflow_dispatch]\n")
	workflowfile:write("\n")

	workflowfile:write("jobs:\n")
	workflowfile:write("  build:\n")
	workflowfile:write("    runs-on: ubuntu-latest\n")
	workflowfile:write("    permissions:\n")
	workflowfile:write("      contents: write\n\n")

	workflowfile:write("    steps:\n")
	workflowfile:write("    - name: Checkout\n")
	workflowfile:write("      uses: actions/checkout@v4\n\n")

	workflowfile:write("    - uses: actions/setup-node@v4\n")
	workflowfile:write("      with:\n")
	workflowfile:write("         node-version: 20\n\n")

	workflowfile:write("    - name: npm Install\n")
	workflowfile:write("      run: npm install\n\n")

	workflowfile:write("    - name: Install Ncc\n")
	workflowfile:write("      run: npm install -g @vercel/ncc\n\n")

	workflowfile:write("    - name: Bundle file\n")
	workflowfile:write("      run: make\n\n")

	workflowfile:write("    - name: Git commit and push changes\n")
	workflowfile:write("      uses: stefanzweifel/git-auto-commit-action@v5\n\n")

	workflowfile:write("  test:\n")
	workflowfile:write("    runs-on: ubuntu-latest\n")
	workflowfile:write("    needs: [ build ]\n\n")

	workflowfile:write("    steps:\n")
	workflowfile:write("    - name: Checkout\n")
	workflowfile:write("      uses: actions/checkout@v4\n\n")

	workflowfile:write("    - name: Run Action\n")
	workflowfile:write("      uses: ./\n\n")

	workflowfile:write("    - name: Test Install\n")
	workflowfile:write("      run: " .. programname .. " --help\n")

	workflowfile:close()


	if version ~= nil then
		---@type string
		local newtext = json.encode(olddata)

		if version.uploaddatabase ~= nil then
			version.uploaddatabase(newtext)
		else
			local databasejsonpath = outputpathdir .. "database.json"

			local databasefile = io.open(databasejsonpath, "w")
			if databasefile == nil then
				print("unable to open file '" .. databasejsonpath .. "'")
				os.exit(1)
			end


			databasefile:write(newtext)
			databasefile:close()
		end
	end

	if singlefile ~= nil then
		local ext = getzipext(compressiontype)
		local mainfile = uploaddir .. singlefile .. ext
		local maindir = uploaddir .. singlefile

		---@type { [string]: string }
		local inputfiles = {}

		postmake.os.tree(maindir, function(path)
			local relpath = string.sub(path, maindir:len())

			if not postmake.os.IsDir(path) then
				inputfiles[path] = relpath
			end
		end)

		archive(compressiontype, inputfiles, mainfile)

		postmake.os.rmall(maindir)
	end
end

return build

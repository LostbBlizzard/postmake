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
	"version"
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
			versionprogramconfig)
	---@type { archivepath: string, files: string[] }[]
	local archivestomake = {}

	for inputtable, output in pairs(config.files) do
		local input = inputtable.string()

		if postmake.match.isbasicmatch(input) then
			local newout = resolveoutputpath(output)
			local newfilename = shellscript.GetUploadfilePath(input, uploadfilecontext,
				function(input2, newfilename)
					if uploaddir ~= nil then
						postmake.os.cp(input2, uploaddir .. newfilename)
					end
				end)



			if versionprogramconfig ~= nil then
				---@type programfile
				local newfile = {
					fileinput = newfilename,
					fileoutput = newout,
				}

				table.insert(versionprogramconfig.programversion.files, newfile)
			else
				outputfile:write(myindent ..
					"downloadfile(\"" ..
					weburl .. "/" .. newfilename .. "\",\"" .. newout .. "\");\n\n")
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
				-- if singlefile ~= nil then
				-- 	myarchive.archivepath = output .. getzipext(compressiontype)
				-- end

				if versionprogramconfig ~= nil then
					---@type programfile
					local newfile = {
						fileinput = newout,
						fileoutput = resolveoutputpath(output),
					}

					table.insert(versionprogramconfig.programversion.files, newfile)
				end

				table.insert(archivestomake, myarchive)
				isfirst = true
			end

			postmake.match.matchpath(input, function(path)
				local fullpath = postmake.path.absolute(path)
				local zippath = string.sub(fullpath, #basepath + 2, #fullpath)

				myarchive.files[path] = zippath
			end)
		end
	end

	for _, output in pairs(config.paths) do
		if versionprogramconfig ~= nil then
			table.insert(versionprogramconfig.programversion.paths, resolveoutputpath(output))
		else
			outputfile:write(myindent .. "addpath(\"" .. resolveoutputpath(output) .. "\");\n")
		end
	end


	for _, value in ipairs(archivestomake) do
		local outpath = ""

		-- if singlefile then
		-- 	outpath = singledir .. "/" .. dirspit .. "/" .. value.archivepath
		--
		-- 	local parent = postmake.path.getparent(outpath);
		-- 	if not postmake.os.exist(parent) then
		-- 		postmake.os.mkdirall(parent)
		-- 	end
		-- else
		outpath = uploaddir .. value.archivepath
		--- end

		archive(compressiontype, value.files, outpath)
	end
end

---@return string
local function getversionindexjsfile()
	local r = "try {\n"
	r = r .. "const data = fs.readFileSync('database.json', 'utf8');\n"
	r = r .. "const databaseinfo = JSON.parse(data);\n\n"
	r = r .. "var foundversion = false;\n\n"
	r = r .. "for (var i = 0; i < databaseinfo.versions.length; i++) {\n"
	r = r .. "var programversion = databaseinfo.versions[i]\n"

	r = r ..
	    "if (programversion.version == versiontodownload || (i == databaseinfo.versions.length - 1 && versiontodownload == \" latest\")) {\n\n"

	r = r .. "var downloadurl = databaseinfo.downloadurl\n"
	r = r .. "for (var i = 0; i < programversion.programs.length; i++) {\n"

	r = r .. "    var program = programversion.programs[i]\n"
	r = r .. "    if (program.os == process.platform && program.arch == process.arch) {\n"
	r = r ..
	    "        console.log(\"downloading \" + programversion.version + \" \" + program.os + \"-\" + program.arch);\n"
	r = r .. "        for (var i = 0; i < program.paths.length; i++) {\n"
	r = r .. "            addpath(program.paths[i])\n"
	r = r .. "        }\n"
	r = r .. "        for (var i = 0; i < program.files.length; i++) {\n"
	r = r .. "            var newfile = program.files[i]\n"
	r = r .. "            downloadfile(downloadurl + \" / \" + newfile.fileinput, newfile.fileoutput)\n"
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

---@class programversion
---@field os ostype
---@field arch archtype
---@field files programfile[]
---@field paths string[]

---@class versiondata
---@field version string
---@field installdir string
---@field downloadurl string
---@field programs programversion[]

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
		print("The Key '" .. key .. "' is not an  valid Shellscript Settins. Typo?\n")
		goterrorinsettings = true
		::continue::
	end
	if goterrorinsettings then
		print("Shellscript only allows for ")
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

	postmake.os.mkdirall(outputpathdir)
	postmake.os.mkdirall(srcdir)

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

	---@type {name:string,value:boolean}[]
	local allflags = {}

	if version ~= nil then
		local databasejsonpath = outputpathdir .. "database.json"
		-- local olddatabasetext = ""

		---@type programdatabase
		-- local olddata = json.decode(olddatabasetext)

		---@type programdatabase
		olddata = { versions = {} }


		---@type versiondata
		newprogramversion = {
			version = postmake.appversion(),
			installdir = postmake.appinstalldir(),
			downloadurl = settings.weburl,
			singlefile = singlefile,
			programs = {}
		}
		table.insert(olddata.versions, newprogramversion)
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
					table.insert(allflags, { name = value.flagname(), value = value.isflag })
				end
			end
		end
	end

	indexfile:write("const core = require('@actions/core');\n")
	indexfile:write("const github = require('@actions/github');\n")

	if hasfiles then
		indexfile:write("const { execSync } = require(\"child_process\");\n")
	end

	indexfile:write("\nvar isWin = process.platform === \"win32\";\n")
	indexfile:write("var isLinux = process.platform === \"linux\";\n")
	indexfile:write("var isMac = process.platform === \"darwin\";\n")
	indexfile:write("var isUnix = isLinux || isMac;\n\n")

	if hasfiles then
		indexfile:write("\nfunction downloadfile(url, outputfile) {\n")
		indexfile:write(indent .. "var command = \"curl -L \" + url + \" -o \" + outputfile;\n")

		indexfile:write(indent .. "if (isUnix) {\n")
		indexfile:write(indent2 .. "       command = \"curl -L \" + url + \" -o \" + outputfile;\n")
		indexfile:write(indent .. "} else {\n")
		indexfile:write(indent2 .. "       command = \"curl.exe -L \" + url + \" -o \" + outputfile;\n")
		indexfile:write(indent .. "}\n")

		indexfile:write(indent .. "child = execSync(command, null);\n")
		indexfile:write("}\n")
	end

	if haspath then
		indexfile:write("\nfunction addpath(path) {\n")
		indexfile:write(indent .. "core.addPath(path);\n")
		indexfile:write("}\n")
	end

	local uploadfilecontext = {}

	for _, value in ipairs(allflags) do
		indexfile:write("var " ..
			flagtovarable(value.name) .. " = " .. lua.valueif(value.value, "true", "false") .. "; \n")
	end
	if version then
		indexfile:write("\nvar versiontodownload = github.getInput('version');\n")
		indexfile:write("if (versiontodownload == \"\") {\n")
		indexfile:write("     versiontodownload = \"latest\";\n")
		indexfile:write("}\n")
		indexfile:write(getversionindexjsfile())
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
				paths = {}
			}

			for file, path in pairs(config.files) do
			end

			versionprogramconfig = {}
			versionprogramconfig.programversion = newprogram

			table.insert(newprogramversion.programs, newprogram)
		end

		onconfig(indent, indexfile, config, weburl, uploaddir, uploadfilecontext, compressiontype,
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

			onconfig(indent2, indexfile, output, weburl, uploaddir, uploadfilecontext, compressiontype,
				versionprogramconfig)


			if not version then
				indexfile:write(indent .. "}\n\n")
			end
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
	actionymlfile:write("  main: './dist/index.js'\n")

	actionymlfile:close()

	local packagejsonfile = io.open(packagejsonpath, "w")
	if packagejsonfile == nil then
		print("unable to open file '" .. packagejsonpath .. "'")
		os.exit(1)
	end


	packagejsonfile:write("{")
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
		local databasejsonpath = outputpathdir .. "database.json"

		local databasefile = io.open(databasejsonpath, "w")
		if databasefile == nil then
			print("unable to open file '" .. databasejsonpath .. "'")
			os.exit(1)
		end

		---@type string
		local newtext = json.encode(olddata)

		databasefile:write(newtext)
		databasefile:close()
	end
end

return build

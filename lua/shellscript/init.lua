local build = {}


function resolveoutputpath(path)
	return  path
end

function ostounname(oosname)
	
	if oosname == "linux" then 
		return "Linux"
	elseif oosname == "macos" then 
		return "Darwin"
	else 
		print("unable convert '".. oosname .. "' to then unix uname string")
		exit(1)
	end
end

function archtounname(archtype)
	
	if archtype == "x64" then 
		return "x86_64"
	elseif archtype == "x32" then 
		return "x86_32"
	elseif archtype == "arm64" then 
		return "arm64"
	else 
		print("unable convert '".. archtype .. "' to then unix uname machine type string")
		exit(1)
	end
end
function build.make(postmake, configs, settings)
	print("---building shell script")

	local weburl = settings.weburl;
	local uploaddir = settings.uploaddir;

	local outputpath = "./" .. postmake.output() .. ".sh"

	print("writing install file to " .. outputpath)
	if weburl == nil then
		print("error settings must have the 'weburl' field set")
		exit(1)
	end


	outputfile = io.open(outputpath, "w")

	outputfile:write("#!/usr/bin/env bash\n")
	outputfile:write("set -e\n")

	outputfile:write("\n\n")

	outputfile:write("Installdir=\"$HOME\\." .. postmake.appname() .. "\" \n")

	outputfile:write("\n")

	outputfile:write("mkdir -p \"$Installdir\" \n")


	if uploaddir ~= nil then
		postmake.os.mkdirall(uploaddir)
	end

	outputfile:write("\n")
	
	if configindex ~= 0 then
		outputfile:write("\n")
		outputfile:write("if ")
	end
	for configindex, config in ipairs(configs) do
		local islast =  configindex == #configs

		if config.os() == "windows" then 
			print("error cant use config with os set the windows")
			exit(1)
		end
		outputfile:write(" [ \"$(uname)\" = \"" .. ostounname(config.os()) .."\" ] && [ \"$(uname -p)\" = \"" .. archtounname(config.arch()) .."\" ]; \nthen\n")

		outputfile:write("\n")

		local count = 0
		--outputfile:write("echo)
		for input, output in pairs(config.files) do

			if count == 0 then
				outputfile:write("echo \"Installing for " .. ostounname(config.os())  .. "-" .. archtounname(config.arch()) ..  "\"\n\n")
			end
			local newout = resolveoutputpath(output)
			outputfile:write("curl -LJ " .. weburl .. newout .. " -o " .. "$Installdir" .. newout .. "\n\n")

			if uploaddir ~= nil then
				postmake.os.cp(input, uploaddir .. "/" .. output)
			end
			count = count +1

		end

		--if count == 0 then
		if true then
			outputfile:write(" :\n")
		end

	
		if not islast then
			outputfile:write("elif")
		end
	end
	outputfile:write("else\n\n")
	outputfile:write("echo \"Unable to Install '" .. postmake.appname() .. "' There is no configuration for your system\"\n")
	outputfile:write("exit 1\n\n")
	outputfile:write("fi\n\n")

	outputfile:close()
end

return build

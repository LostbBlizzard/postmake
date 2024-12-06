local function StringStartWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

local function hexdecode(hex)
	return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

local function hexencode(str)
	return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

local m = {}

local function writefilestring(varablename, pathtoread, output, arevarables)
	local buffervarablename = varablename .. "_buffer"

	local maxbyteperline = 100
	local maxbuffer = 1024 * 4

	local datafile = io.open(pathtoread, "rb")

	if datafile == nil then
		output:close()
		print("unable to read file at " .. pathtoread)
		os.exit(1)
	end

	output:write("char " .. buffervarablename .. "[] = {\n")

	local bytescount = 0
	local bytes = datafile:read(maxbuffer)
	local bytesleft = #bytes


	print("reading " .. pathtoread)
	while true do
		if bytesleft == 0 then
			bytes = datafile:read(maxbuffer)

			if bytes == nil then
				break;
			end
			bytesleft = #bytes
		end


		if bytesleft == 0 then
			break;
		end

		local bytestowrite = math.min(bytesleft, maxbyteperline)

		local currentbytes = string.sub(bytes, 0, bytestowrite)

		output:write("\"")

		for i = 1, #currentbytes do
			local c = currentbytes:sub(i, i)
			output:write("\\x" .. hexencode(c))
		end

		output:write("\"\n")

		bytescount = bytescount + #currentbytes

		bytes = string.sub(bytes, bytestowrite)
		bytesleft = bytesleft - bytestowrite
	end


	output:write("};\n")

	if arevarables then
		output:write("struct InternalFileBuffer " ..
			varablename .. " = {" .. buffervarablename .. ","
			.. bytescount .. "};\n")
	else
		output:write("#define " ..
			varablename .. " {" .. buffervarablename .. ","
			.. bytescount .. "}\n")
	end
end

local function getvarablename(line)
	local pos = string.find(line, ";")

	local varablename = ""

	local i = pos - 1
	while i ~= 0 do
		local c = line:sub(i, i)

		if c == " " then
			break
		end


		varablename = varablename .. c
		i = i - 1
	end


	return varablename:reverse()
end
---@param basefile string
---@param outputfile string,
function m.enbed(basefile, outputfile)
	local inputfile = io.open(basefile, "rb")
	if inputfile == nil then
		print("unable to open/read " .. basefile)
		os.exit(1)
	end

	local output = io.open(outputfile, "wb")
	if output == nil then
		print("unable to open/write " .. outputfile)
		os.exit(1)
	end

	local inputtext = inputfile:read("*a")
	inputfile:close()



	local varablename = nil
	local pathtoread = nil
	for line in inputtext:gmatch("([^\r\n]*)[\r\n]?") do
		if pathtoread ~= nil then
			if (string.find(line, "extern struct InternalFileBuffer")) then
				varablename = getvarablename(line)

				output:write("#include \"" .. basefile .. "\"\n")

				writefilestring(varablename, pathtoread, output, true)
				varablename = nil
				pathtoread = nil
			elseif (string.find(line, "extern struct InternalFileList")) then
				varablename = getvarablename(line)

				output:write("#include \"" .. basefile .. "\"\n")

				local file_count = 0
				local files = {}

				output:write("\n")
				postmake.match.matchpath(pathtoread, function(path)
					file_count = file_count + 1

					output:write("//" .. path .. "\n")
					local varable = "file_" .. tostring(file_count)
					writefilestring(varable, path, output, false)

					output:write("\n")

					files[varable] = path
				end)

				output:write("\n")
				output:write("\n")

				local filelistvarablename = varablename .. "buffer"

				output:write("struct InternalFile " .. filelistvarablename .. "[] = {\n")

				local isfisrst = true
				for varable, path in pairs(files) do
					if isfisrst == false then
						output:write(",\n")
					end
					output:write("{\"" .. path .. "\"," .. varable .. "}")

					isfisrst = false
				end
				output:write("\n};\n")

				output:write("struct InternalFileList " ..
					varablename ..
					" = {" .. filelistvarablename .. "," .. tostring(file_count) .. "};\n")

				varablename = nil
				pathtoread = nil
			end
		elseif string.find(line, "//enbed") then
			local startindex = string.find(line, "//enbed") + #"//enbed"
			local path = string.sub(line, startindex)

			for i = 1, #path do
				local c = path:sub(i, i)
				if c ~= " " then
					path = string.sub(path, i)
					break
				end
			end

			pathtoread = path
			varablename = "internal_files"
		end
	end

	output:close()
end

---@param outputfile string
function m.maketypedef(outputfile)
	local output = io.open(outputfile, "wb")
	if output == nil then
		print("unable to open/write " .. outputfile)
		os.exit(1)
	end

	output:write("#include <stddef.h> //size_t\n\n")

	output:write("struct InternalFileBuffer {\n")
	output:write("	const char* data;\n")
	output:write("	size_t size;\n")
	output:write("};\n")
	output:write("struct InternalFile {\n")
	output:write("	const char* filename;\n")
	output:write("	InternalFileBuffer Data;\n")
	output:write("};\n")
	output:write("struct InternalFileList {\n")
	output:write("	const InternalFile* data;\n")
	output:write("	size_t size;\n")
	output:write("};\n")

	output:close()
end

return m

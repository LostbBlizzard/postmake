local function StringStartWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

local function hexdecode(hex)
	return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

local function hexencode(str)
	return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

---@param basefile string
---@param outputfile string,
return function(basefile, outputfile)
	local inputfile = io.open(basefile, "rb")
	if inputfile == nil then
		print("unable to open/read " .. basefile)
		exit(1)
		return
	end

	local output = io.open(outputfile, "wb")
	if output == nil then
		print("unable to open/write " .. outputfile)
		exit(1)
		return
	end

	local inputtext = inputfile:read("*a")
	inputfile:close()



	local pathtoread = nil
	for line in inputtext:gmatch("([^\r\n]*)[\r\n]?") do
		if pathtoread ~= nil then
			if (string.find(line, "extern struct Buffer")) then
				local varablename = "internal_file"
				local buffervarablename = varablename .. "_buffer"

				local maxbyteperline = 100
				local maxbuffer = 1024 * 4

				local datafile = io.open(pathtoread, "rb")

				if datafile == nil then
					output:close()
					print("unable to read file at " .. pathtoread)
					exit(1)
				end

				output:write("#include \"" .. basefile .. "\"\n")

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
				output:write("struct Buffer " .. varablename .. " = {" .. buffervarablename .. ","
					.. bytescount .. "};\n")
			end
		elseif string.find(line, "//enbed") then
			pathtoread = "./textfile.txt"
		end
	end

	output:close()
end

local m = {}

function m.postmakepathtoinnopath(path)
	local newstr = path.gsub(path, "~/", "{%USERPROFILE}/")
	return newstr
end

function m.postmakepathtoinnoapppath(path)
	local newstr = path.gsub(path, "/", "\\")
	return "{app}" .. newstr
end

function m.innoinputapppath(path)
	local newstr = path.gsub(path, "/", "\\")
	newstr = path.gsub(newstr, "%*%*", "*")
	return newstr
end

local function StringStartWith(String, Start)
	return string.sub(String, 1, string.len(Start)) == Start
end

function m.postmakepathtoinnoapppathcmd(path)
	if not StringStartWith(path, "/") then
		return path
	end
	return "{app}" .. path
end

function m.expandpostmakepathtoinnoapppath(path)
	return "ExpandConstant('{app}') + " .. "'" .. path .. "'"
end

function m.flagnametovarable(path)
	return "env" .. path:gsub(" ", "_")
end

function m.getdir(path)
	return path:match("(.*[/\\])")
end

return m

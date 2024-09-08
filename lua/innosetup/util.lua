local m = {}

function m.postmakepathtoinnopath(path)
	local newstr = path.gsub(path, "~/", "{%USERPROFILE}/")
	return newstr
end

function m.postmakepathtoinnoapppath(path)
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

function m.UseOrDefault(field, default)
	if field == nil then
		return default
	else
		return field
	end
end

return m

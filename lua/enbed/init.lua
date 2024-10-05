local m = {}


_Enbedlangtable = {}

function m.enbed(basefile, outputfile, lang)
	_Enbedlangtable[lang](basefile, outputfile)
end

function m.addlang(langname, callback)
	_Enbedlangtable[langname] = callback
end

m.addlang("c", postmake.require("langs/c.lua"))
m.addlang("c++", postmake.require("langs/cpp.lua"))
m.addlang("zig", postmake.require("langs/zig.lua"))

return m

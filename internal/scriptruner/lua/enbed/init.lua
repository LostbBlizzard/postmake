local m = {}


_Enbedlangtable = {}

function m.enbed(basefile, outputfile, lang)
	_Enbedlangtable[lang].enbed(basefile, outputfile)
end

function m.maketypedef(outputfile, lang)
	_Enbedlangtable[lang].maketypedef(outputfile)
end

function m.addlang(langname, object)
	_Enbedlangtable[langname] = object
end

m.addlang("c", postmake.require("langs/c.lua"))
m.addlang("c++", postmake.require("langs/cpp.lua"))
m.addlang("zig", postmake.require("langs/zig.lua"))

return m

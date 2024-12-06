package luamodule

import (
	"embed"
	"github.com/LostbBlizzard/postmake/internal/utils"
	"os"

	lua "github.com/yuin/gopher-lua"
)

func MakeCompileModule(l *lua.LState, InternalFiles embed.FS) *lua.LTable {
	table := l.NewTable()

	l.SetField(table, "luaprogram", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)
		target := l.ToString(2)

		var filepath string
		if target == "windows" {
			filepath = "lua/bin/win32"
		} else if target == "linux" {
			filepath = "lua/bin/linux32"
		} else if target == "macos" {
			filepath = "lua/bin/macos"
		} else {
			panic("unknown target '" + target + "'")
		}

		data, err := InternalFiles.ReadFile(filepath)
		utils.CheckErr(err)

		err = os.WriteFile(path, []byte(data), 0644)
		utils.CheckErr(err)
		return 0
	}))

	//l.SetField(table, "luaprogramscript", l.NewFunction(func(l *lua.LState) int {
	//	path := l.ToString(1)
	//	target := l.ToString(2)
	//	scripttorun := l.ToString(3)
	//})

	return table
}

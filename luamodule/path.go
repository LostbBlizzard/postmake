package luamodule

import (
	"path/filepath"
	"postmake/utils"
	"strings"

	lua "github.com/yuin/gopher-lua"
)

func MakePathModule(l *lua.LState) *lua.LTable {
	table := l.NewTable()

	l.SetField(table, "getfilename", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		l.Push(lua.LString(filepath.Base(path)))
		return 1
	}))
	l.SetField(table, "removeext", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		l.Push(lua.LString(strings.TrimSuffix(path, filepath.Ext(path))))
		return 1
	}))
	l.SetField(table, "getparent", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		l.Push(lua.LString(filepath.Dir(path)))
		return 1
	}))
	l.SetField(table, "absolute", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		r, err := filepath.Abs(path)
		utils.CheckErr(err)
		l.Push(lua.LString(r))

		return 1
	}))
	return table
}

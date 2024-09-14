package luamodule

import (
	"errors"
	"os"

	"postmake/utils"

	lua "github.com/yuin/gopher-lua"
)

func MakeOsModule(l *lua.LState) *lua.LTable {
	table := l.NewTable()

	l.SetField(table, "cp", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		output := l.ToString(2)

		data, err := os.ReadFile(input)
		utils.CheckErr(err)
		err = os.WriteFile(output, data, 0644)
		utils.CheckErr(err)
		return 0
	}))
	l.SetField(table, "mkdir", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		os.Mkdir(input, os.ModePerm)
		return 0
	}))
	l.SetField(table, "mkdirall", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		os.MkdirAll(input, os.ModePerm)
		return 0
	}))
	l.SetField(table, "exist", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		ret := true
		if _, err := os.Stat(input); errors.Is(err, os.ErrNotExist) {
			ret = false
		}

		l.Push(lua.LBool(ret))
		return 1
	}))

	return table
}

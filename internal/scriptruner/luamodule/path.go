package luamodule

import (
	"github.com/LostbBlizzard/postmake/internal/utils"
	"os"
	"path/filepath"
	"strings"

	lua "github.com/yuin/gopher-lua"
)

func Revolveluapath(path string) (string, error) {
	r := path
	if strings.Contains(r, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}

		r = strings.ReplaceAll(r, "~/", home+"/")
	}
	return r, nil
}
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
	l.SetField(table, "getfileext", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		l.Push(lua.LString(filepath.Ext(path)))
		return 1
	}))
	l.SetField(table, "getfullfileext", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		r := ""
		for i := 0; i < len(path); i++ {
			if path[i] == '.' {
				r = path[i:]
				break
			}
		}

		l.Push(lua.LString(r))
		return 1
	}))
	l.SetField(table, "getparent", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		l.Push(lua.LString(filepath.Dir(path)))
		return 1
	}))
	l.SetField(table, "absolute", l.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		updatedpath, err := Revolveluapath(path)
		utils.CheckErr(err)

		r, err := filepath.Abs(updatedpath)
		utils.CheckErr(err)
		l.Push(lua.LString(r))

		return 1
	}))
	return table
}

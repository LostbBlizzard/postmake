package luamodule

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"

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
		utils.CheckErr(os.Mkdir(input, os.ModePerm))
		return 0
	}))
	l.SetField(table, "mkdirall", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		utils.CheckErr(os.MkdirAll(input, os.ModePerm))
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

	l.SetField(table, "rm", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		utils.CheckErr(os.Remove(input))
		return 0
	}))
	l.SetField(table, "rmall", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		utils.CheckErr(os.RemoveAll(input))
		return 0
	}))
	l.SetField(table, "ls", l.NewFunction(func(l *lua.LState) int {
		inputpath := l.ToString(1)
		callback := l.ToFunction(2)

		items, err := os.ReadDir(inputpath)
		if err != nil {
			panic(err)
		}
		for _, item := range items {
			fullname := inputpath + "/" + item.Name()

			l.Push(callback)
			l.Push(lua.LString(fullname))
			l.PCall(1, 0, nil)
		}
		return 0
	}))
	l.SetField(table, "tree", l.NewFunction(func(l *lua.LState) int {
		inputpath := l.ToString(1)
		callback := l.ToFunction(2)

		err := filepath.WalkDir(inputpath, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if d.IsDir() || d.Type().IsRegular() {
				l.Push(callback)
				l.Push(lua.LString(path))
				l.PCall(1, 0, nil)
			}
			return nil
		})
		utils.CheckErr(err)
		return 0
	}))
	l.SetField(table, "IsFile", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)

		fi, err := os.Stat(input)
		utils.CheckErr(err)

		value := false
		switch mode := fi.Mode(); {
		case mode.IsRegular():
			value = true
		}

		l.Push(lua.LBool(value))
		return 1
	}))
	l.SetField(table, "IsDir", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)

		fi, err := os.Stat(input)
		utils.CheckErr(err)

		value := false
		switch mode := fi.Mode(); {
		case mode.IsDir():
			value = true
		}

		l.Push(lua.LBool(value))
		return 1
	}))

	unametable := l.NewTable()
	{
		l.SetField(unametable, "machine", l.NewFunction(func(l *lua.LState) int {
			r := ""
			if runtime.GOARCH == "386" {
				r = "x32"
			} else if runtime.GOARCH == "amd64" {
				r = "x64"
			} else if runtime.GOARCH == "arm64" {
				r = "arm64"
			} else {
				r = "unknown"
			}

			l.Push(lua.LString(r))
			return 1
		}))
		l.SetField(unametable, "os", l.NewFunction(func(l *lua.LState) int {
			r := ""
			if runtime.GOOS == "windows" {
				r = "windows"
			} else if runtime.GOOS == "linux" {
				r = "linux"
			} else if runtime.GOOS == "darwin" {
				r = "macos"
			} else if runtime.GOOS == "freebsd" {
				r = "openbsd"
			} else {
				r = "unknown"
			}

			l.Push(lua.LString(r))
			return 1
		}))
	}

	l.SetField(table, "uname", unametable)
	return table
}

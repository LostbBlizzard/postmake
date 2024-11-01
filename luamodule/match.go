package luamodule

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"unicode"

	"github.com/gobwas/glob"
	lua "github.com/yuin/gopher-lua"
)

func isbasicmatchrune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r) || r == '/' || r == '.' || r == '_' || r == '-'
}
func IsBasicMatch(s string) bool {
	for _, r := range s {
		if !isbasicmatchrune(r) {
			return false
		}
	}
	return true
}
func GetBasePathFromMatch(s string) (string, string) {
	for i, r := range s {
		if !isbasicmatchrune(r) {
			return s[:i], s[i:]
		}
	}
	return s, ""
}

func MakeMatchModule(l *lua.LState) *lua.LTable {
	table := l.NewTable()

	l.SetField(table, "isbasicmatch", l.NewFunction(func(l *lua.LState) int {
		regexstring := l.ToString(1)
		l.Push(lua.LBool(IsBasicMatch(regexstring)))
		return 1
	}))

	l.SetField(table, "matchpath", l.NewFunction(func(l *lua.LState) int {
		regexstring := l.ToString(1)
		funcioncallback := l.ToFunction(2)

		basepath, regex := GetBasePathFromMatch(regexstring)

		isrecursive := strings.Contains(regexstring, "**")

		if isrecursive {
			newregex := regex
			if !strings.HasSuffix(newregex, "**") {
				newregex = strings.ReplaceAll(newregex, "**", "*")
			}

			glob, err := glob.Compile(newregex)
			if err != nil {
				panic(err)
			}

			err = filepath.WalkDir(basepath, func(path string, d fs.DirEntry, err error) error {
				if err != nil {
					return nil
				}
				if !d.IsDir() {
					if glob.Match(path) {
						l.Push(funcioncallback)
						l.Push(lua.LString(path))
						l.PCall(1, 0, nil)
					}
				}
				return nil
			})
			if err != nil {
				panic(err)
			}
		} else {
			glob, err := glob.Compile(regex)
			if err != nil {
				panic(err)
			}

			items, err := os.ReadDir(basepath)
			if err != nil {
				panic(err)
			}
			for _, item := range items {
				fullname := basepath + "/" + item.Name()

				if glob.Match(fullname) {
					l.Push(funcioncallback)
					l.Push(lua.LString(fullname))
					l.PCall(1, 0, nil)
				}
			}
		}

		return 0
	}))
	l.SetField(table, "match", l.NewFunction(func(l *lua.LState) int {

		pattenstring := l.ToString(1)
		tomatchstring := l.ToString(2)

		glob, err := glob.Compile(pattenstring)

		if err != nil {
			panic(err)
		}
		value := glob.Match(tomatchstring)

		l.Push(lua.LBool(value))
		return 1
	}))
	l.SetField(table, "getbasepath", l.NewFunction(func(l *lua.LState) int {
		matchstring := l.ToString(1)
		base, _ := GetBasePathFromMatch(matchstring)

		l.Push(lua.LString(base))
		return 1
	}))
	return table
}

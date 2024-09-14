package utils

import (
	"log"

	lua "github.com/yuin/gopher-lua"
)

func CheckErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
func Tabletoarray[T any](table *lua.LTable, convertfunc func(item lua.LValue) T) []T {
	var r = make([]T, 0)
	table.ForEach(func(l1, l2 lua.LValue) {
		r = append(r, convertfunc(l2))
	})
	return r
}
func Tabletomap[K comparable, V any](table *lua.LTable, convertfunc func(key lua.LValue, value lua.LValue) (K, V)) map[K]V {
	var r = make(map[K]V, 0)
	table.ForEach(func(l1 lua.LValue, l2 lua.LValue) {
		k, v := convertfunc(l1, l2)
		r[k] = v
	})
	return r
}

func Tostringarray(table *lua.LTable) []string {
	return Tabletoarray(table, func(item lua.LValue) string { return item.String() })
}
func Tostringstringmap(table *lua.LTable) map[string]string {
	return Tabletomap(table, func(key, value lua.LValue) (_ string, _ string) {
		return key.String(), value.String()
	})
}

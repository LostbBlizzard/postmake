package main

import (
	"fmt"
	"os"

	lua "github.com/yuin/gopher-lua"
)

func main() {
	L := lua.NewState()
	defer L.Close()

	data, err := os.ReadFile("main.lua")
	if err != nil {
		fmt.Print(err)
		os.Exit(1)
	}

	if err := L.DoString(string(data)); err != nil {
		panic(err)
	}
}

package main

import (
	"fmt"
	"os"

	"github.com/alecthomas/kong"
)

var CLI struct {
	Init struct {
		Output string `optional:"postmake.lua" help:"Output File"`
	} `cmd:""  help:"Makes a new postmake.lua"  type:"path"`
	Build struct {
		Input  string `default:"postmake.lua" help:"Output File"`
		Target string `optional:"postmake.lua" help:"Output File"`
	} `cmd:"" help:"Builds an install file using postmake.lua file"`
}

func main() {
	ctx := kong.Parse(&CLI)

	switch ctx.Command() {
	case "init <path>":

	case "build":
		data, err := os.ReadFile(CLI.Build.Input)
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}

		RunScript(ScriptRunerInput{ScriptText: string(data), Target: CLI.Build.Target})
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
	default:
		panic(ctx.Command())
	}
}

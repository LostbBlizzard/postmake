package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/alecthomas/kong"
	"golang.org/x/exp/rand"

	"postmake/utils"
)

var CLI struct {
	Init struct {
		Output string `default:"postmake.lua" help:"Output File"`
	} `cmd:""  help:"Makes a new postmake.lua"  type:"path"`
	GenerateInnoID struct {
	} `cmd:""  help:"Prints a new Generated InnoID  to stdout" `
	Build struct {
		Input  string `default:"postmake.lua" help:"Output File"`
		Target string `default:"all" help:"target installer"`
	} `cmd:"" help:"Builds an Install file using postmake.lua file"`
	Uninstall struct {
	} `cmd:""  help:"Uninstalls postmake from the system" `
}

var letterRunes = []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")

func RandStringRunes(n int) string {
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func GenerateNewInnoID() string {
	min := 36
	max := 64
	rand.Seed(uint64(time.Now().UnixNano()))
	return RandStringRunes(rand.Intn(max-min) + max)
}

func main() {
	ctx := kong.Parse(&CLI)

	switch ctx.Command() {
	case "init":
		data, err := InternalPlugins.ReadFile("lua/default.lua")
		utils.CheckErr(err)
		newstr := strings.ReplaceAll(string(data), "###{INNOAPPID}###", GenerateNewInnoID())
		err = os.WriteFile(CLI.Init.Output, []byte(newstr), 0644)
		utils.CheckErr(err)
	case "generate-inno-id":
		fmt.Println(GenerateNewInnoID())
	case "uninstall":
		fmt.Println("If your seeing this message the uninstall command failed.")
		fmt.Println("you can remove this program by removeing the binary directly")
		fmt.Println("this message is only seen if the program was ran directly and not from the proxy executable found at ")
		fmt.Println("~/.postmake/postmake while this current executable is found at ~/.postmake/bin/postmake ")
		fmt.Println("or the program was download without using the installer")
		os.Exit(1)
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

package main

import (
	_ "embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/alecthomas/kong"
	"golang.org/x/exp/rand"
	"gopkg.in/yaml.v2"

	run "github.com/LostbBlizzard/postmake/internal/scriptruner"
	settingsmod "github.com/LostbBlizzard/postmake/internal/settings"
	"github.com/LostbBlizzard/postmake/internal/utils"
)

var CLI struct {
	Version struct {
		Info string `default:"all" enum:"all,name,version,githash,targetos,targetarch,builddate" help:""`
	} ` short:"v" cmd:""  help:"get program version" `

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
	Config struct {
		Get struct {
			AutoUpdate    struct{} `cmd:""  help:"Gets config value of AutoUpdate" `
			UpdateChannel struct{} `cmd:""  help:"Gets config value of UpdateChannel" `
			All           struct{} `cmd:"" Gets all config values`
			ConfigPath    struct{} `cmd:"" get the config path`
		} `cmd`
		Set struct {
			AutoUpdate struct {
				Value string `required:"" enum:"true,false" short:"v"`
			} `cmd:""  help:"Set config value of AutoUpdate" `
			UpdateChannel struct {
				Value string `required:"" enum:"release,hotfix,bleedingedge" short:"v"`
			} `cmd:""  help:"Set config value of UpdateChannel"  `
		} `cmd`
	} `cmd:"" short:"c"`
}

//go:embed version.yaml
var VersionFile string

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
		postmakeluapath := CLI.Init.Output

		postmakeinpath := true
		if _, err := os.Stat(postmakeluapath); errors.Is(err, os.ErrNotExist) {
			postmakeinpath = false
		}

		if postmakeinpath {

			newpostmakeluapath := postmakeluapath + ".bak"

			if _, err := os.Stat(newpostmakeluapath); errors.Is(err, os.ErrNotExist) {
			} else {
				num := 0
				for i := range 100 {
					newpath := newpostmakeluapath + strconv.Itoa(i)
					if _, err := os.Stat(newpath); errors.Is(err, os.ErrNotExist) {
						num = i
						break
					}
				}

				newpostmakeluapath = newpostmakeluapath + strconv.Itoa(num)
			}

			os.Rename(postmakeluapath, newpostmakeluapath)
			fmt.Println("Moved original postmake.lua to " + newpostmakeluapath)
		}

		data, err := run.InternalFiles.ReadFile("lua/default.lua")
		utils.CheckErr(err)
		newstr := strings.ReplaceAll(string(data), "###{INNOAPPID}###", GenerateNewInnoID())
		err = os.WriteFile(CLI.Init.Output, []byte(newstr), 0644)
		utils.CheckErr(err)

		luarcpath := filepath.Join(filepath.Dir(CLI.Init.Output), ".luarc.json")
		if _, err := os.Stat(luarcpath); errors.Is(err, os.ErrNotExist) {
			data, err := run.InternalFiles.ReadFile("lua/default.luarc.json")
			utils.CheckErr(err)
			err = os.WriteFile(luarcpath, []byte(data), 0644)
			utils.CheckErr(err)
		} else {
			fmt.Println("Skiped adding .luarc.json because one was already there. if want to have lua annotations")
			fmt.Println("Add the line '~/.postmake/lua/definitions' to the workspace.library array")
		}

		err = os.WriteFile(CLI.Init.Output, []byte(newstr), 0644)
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

		run.RunScript(run.ScriptRunerInput{ScriptText: string(data), Target: CLI.Build.Target, ScriptPath: CLI.Build.Input})
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}

	case "config get auto-update":
		settings, err := settingsmod.Getsettings()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
		fmt.Println(settings.AutoUpdate)
	case "config get update-channel":
		settings, err := settingsmod.Getsettings()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}

		fmt.Println(settings.UpdateChannel)

	case "config get all":
		settings, err := settingsmod.Getsettings()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}

		fmt.Printf("AutoUpdate:%t \n", settings.AutoUpdate)
		fmt.Printf("UpdateChannel:%s \n", settings.UpdateChannel)

	case "config get config-path":
		path, err := settingsmod.GetSettingsPath()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
		fmt.Println(path)

	case "config set auto-update":
		settings, err := settingsmod.Getsettings()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
		settings.AutoUpdate = CLI.Config.Set.AutoUpdate.Value == "true"

		settingsmod.Savesettings(settings)

	case "config set update-channel":
		settings, err := settingsmod.Getsettings()
		if err != nil {
			fmt.Print(err)
			os.Exit(1)
		}
		settings.UpdateChannel = settingsmod.ParseUpdateChannel(CLI.Config.Set.UpdateChannel.Value)

		settingsmod.Savesettings(settings)
	case "version":
		type versionfile struct {
			Name       string
			Version    string
			Githash    string
			Targetos   string
			Targetarch string
			Builddate  string
		}
		versioninfo := versionfile{}

		err := yaml.Unmarshal([]byte(VersionFile), &versioninfo)
		if err != nil {
			panic(err)
		}

		infotolog := CLI.Version.Info
		switch infotolog {
		case "all":
			fmt.Printf("name:%s \n", versioninfo.Name)
			fmt.Printf("version:%s \n", versioninfo.Version)
			fmt.Printf("githash:%s \n", versioninfo.Githash)
			fmt.Printf("targetos:%s \n", versioninfo.Targetos)
			fmt.Printf("targetarch:%s \n", versioninfo.Targetarch)
			fmt.Printf("builddate:%s \n", versioninfo.Builddate)

		case "name":
			println(versioninfo.Name)
		case "version":
			println(versioninfo.Version)
		case "githash":
			println(versioninfo.Githash)
		case "targetos":
			println(versioninfo.Targetos)
		case "targetarch":
			println(versioninfo.Targetarch)
		case "builddate":
			println(versioninfo.Builddate)
		}
	default:
		panic(ctx.Command())
	}
}

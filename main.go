package main

import (
	"errors"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"

	"github.com/alecthomas/kong"
	lua "github.com/yuin/gopher-lua"
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
		initfile()
	case "":
	case "build":
		build()
	default:
		panic(ctx.Command())
	}
}

func initfile() {
}

type Loadedplugin struct {
	table lua.LValue
}
type InputFile struct {
	input  string
	output string
}
type Config struct {
	os       string
	arch     string
	mainfile InputFile
	files    []InputFile
}
type PreBuildContext struct {
	target        string
	loadedplugins map[string]Loadedplugin
	configs       []Config
}

// const LuaiNSTALLdIR = "$INSTALLDIR$"
// const LUAHOMEDir = "$HOME$"
const LuaiNSTALLdIR = "/"
const LUAHOMEDir = "~/"

func makepostbuildforplugin(l *lua.LState, oldpostbuild lua.LTable, oldcontext *PreBuildContext) *lua.LTable {
	postbuilde := l.NewTable()

	l.SetField(postbuilde, "appname", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "appname"))
		return 1
	}))
	l.SetField(postbuilde, "appversion", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "appversion"))
		return 1
	}))
	l.SetField(postbuilde, "apppublisher", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "apppublisher"))
		return 1
	}))
	l.SetField(postbuilde, "appwebsite", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "appwebsite"))
		return 1
	}))
	l.SetField(postbuilde, "applicensefile", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "applicensefile"))
		return 1
	}))
	l.SetField(postbuilde, "appid", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "appid"))
		return 1
	}))
	l.SetField(postbuilde, "appinstalldir", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "appinstalldir"))
		return 1
	}))
	l.SetField(postbuilde, "output", l.NewFunction(func(l *lua.LState) int {
		l.Push(l.GetField(&oldpostbuild, "output"))
		return 1
	}))
	addutills(l, postbuilde)
	return postbuilde
}

func checkErr(err error) {
	if err != nil {
		log.Fatal(err)
	}
}
func addutills(l *lua.LState, table *lua.LTable) {

	ostable := l.NewTable()
	l.SetField(ostable, "cp", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		output := l.ToString(2)

		data, err := ioutil.ReadFile(input)
		checkErr(err)
		err = ioutil.WriteFile(output, data, 0644)
		checkErr(err)
		return 0
	}))
	l.SetField(ostable, "mkdir", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		os.Mkdir(input, os.ModePerm)
		return 0
	}))
	l.SetField(ostable, "mkdirall", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		os.MkdirAll(input, os.ModePerm)
		return 0
	}))
	l.SetField(ostable, "exist", l.NewFunction(func(l *lua.LState) int {
		ret := true
		if _, err := os.Stat("/path/to/whatever"); errors.Is(err, os.ErrNotExist) {
			ret = false
		}

		l.Push(lua.LBool(ret))
		return 1
	}))
	l.SetField(table, "os", ostable)
}
func build() {
	L := lua.NewState()
	defer L.Close()

	log := log.New(os.Stderr, "", 0)

	prebuild := PreBuildContext{target: CLI.Build.Target, loadedplugins: make(map[string]Loadedplugin)}

	postmaketable := L.NewTable()
	addutills(L, postmaketable)

	L.SetField(postmaketable, "appname", lua.LString("app"))
	L.SetField(postmaketable, "appversion", lua.LString("0.0.1"))
	L.SetField(postmaketable, "apppublisher", lua.LString("publisher"))
	L.SetField(postmaketable, "appwebsite", lua.LString("https://github.com/LostbBlizzard/postmake"))
	L.SetField(postmaketable, "applicensefile", lua.LString(""))
	L.SetField(postmaketable, "appid", lua.LString(""))
	L.SetField(postmaketable, "appinstalldir", lua.LString(LUAHOMEDir+"app"))

	L.SetField(postmaketable, "output", lua.LString("install-"+CLI.Build.Target))

	L.SetField(postmaketable, "target", L.NewFunction(func(l *lua.LState) int {
		l.Push(lua.LString(prebuild.target))
		return 1
	}))
	L.SetField(postmaketable, "installdir", L.NewFunction(func(l *lua.LState) int {
		l.Push(lua.LString(LuaiNSTALLdIR))
		return 1
	}))
	L.SetField(postmaketable, "homedir", L.NewFunction(func(l *lua.LState) int {
		l.Push(lua.LString(LUAHOMEDir))
		return 1
	}))

	configalltable := L.NewTable()
	{
		L.SetField(configalltable, "addfile", L.NewFunction(func(l *lua.LState) int {

			input := InputFile{
				input:  l.ToString(1),
				output: l.ToString(2),
			}
			for i, element := range prebuild.configs {
				prebuild.configs[i].files = append(element.files, input)
			}
			return 0
		}))
		L.SetField(configalltable, "addmainfile", L.NewFunction(func(l *lua.LState) int {
			input := InputFile{
				input:  l.ToString(1),
				output: l.ToString(2),
			}
			for i, element := range prebuild.configs {
				prebuild.configs[i].files = append(element.files, input)
			}
			return 0
		}))
	}

	L.SetField(postmaketable, "allconfig", configalltable)
	L.SetField(postmaketable, "foros", L.NewFunction(func(l *lua.LState) int {
		os := l.ToString(1)

		newtable := l.NewTable()
		{
			l.SetField(configalltable, "addfile", l.NewFunction(func(l *lua.LState) int {
				input := InputFile{
					input:  l.ToString(1),
					output: l.ToString(2),
				}
				for i, element := range prebuild.configs {
					if element.os == os {
						prebuild.configs[i].files = append(element.files, input)
						prebuild.configs[i].mainfile = input
					}
				}
				return 0
			}))
			l.SetField(configalltable, "addmainfile", l.NewFunction(func(l *lua.LState) int {
				input := InputFile{
					input:  l.ToString(1),
					output: l.ToString(2),
				}
				for i, element := range prebuild.configs {
					if element.os == os {
						prebuild.configs[i].files = append(element.files, input)
						prebuild.configs[i].mainfile = input
					}
				}
				return 0
			}))
		}

		l.Push(newtable)
		return 1
	}))
	L.SetField(postmaketable, "forarch", L.NewFunction(func(l *lua.LState) int {
		arch := l.ToString(1)
		newtable := l.NewTable()
		{
			l.SetField(configalltable, "addfile", l.NewFunction(func(l *lua.LState) int {
				input := InputFile{
					input:  l.ToString(1),
					output: l.ToString(2),
				}
				for i, element := range prebuild.configs {
					if element.arch == arch {
						prebuild.configs[i].files = append(element.files, input)
					}
				}
				return 0

			}))
			l.SetField(configalltable, "addmainfile", l.NewFunction(func(l *lua.LState) int {
				input := InputFile{
					input:  l.ToString(1),
					output: l.ToString(2),
				}
				for i, element := range prebuild.configs {
					if element.arch == arch {
						prebuild.configs[i].files = append(element.files, input)
						prebuild.configs[i].mainfile = input
					}
				}
				return 0

			}))
		}

		l.Push(newtable)
		return 1
	}))
	L.SetField(postmaketable, "newconfig", L.NewFunction(func(l *lua.LState) int {

		os := l.ToString(1)
		arch := l.ToString(2)

		ind := len(prebuild.configs)
		prebuild.configs = append(prebuild.configs, Config{
			os:   os,
			arch: arch,
		})

		val := l.NewTable()

		l.SetField(val, "os", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(os))
			return 1
		}))
		l.SetField(val, "arch", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(arch))
			return 1
		}))

		l.SetField(val, "addfile", l.NewFunction(func(l *lua.LState) int {
			prebuild.configs[ind].files = append(prebuild.configs[ind].files, InputFile{
				input:  l.ToString(1),
				output: l.ToString(2),
			})
			return 1
		}))
		l.SetField(val, "addmainfile", l.NewFunction(func(l *lua.LState) int {
			newfile := InputFile{
				input:  l.ToString(1),
				output: l.ToString(2),
			}
			prebuild.configs[ind].files = append(prebuild.configs[ind].files, newfile)
			prebuild.configs[ind].mainfile = newfile

			return 1
		}))
		l.Push(val)
		return 1
	}))

	L.SetField(postmaketable, "loadplugin", L.NewFunction(func(l *lua.LState) int {
		pluginpath := l.ToString(1)

		val, ok := prebuild.loadedplugins[pluginpath]
		if ok {
			l.Push(val.table)
			return 1
		} else {

			if strings.HasPrefix(pluginpath, "internal/") {
				pluginname := pluginpath[len("internal/"):]

				data, err := os.ReadFile("./lua/" + pluginname + "/init.lua")
				if err != nil {
					l.RaiseError("unable to read plugin %s init.lua [%s]", pluginpath, err.Error())
				}

				err = l.DoString(string(data))
				if err != nil {
					l.RaiseError("plugin %s failed to load", pluginpath)
				}
				ret := l.Get(-1)
				l.Pop(1)

				prebuild.loadedplugins[pluginpath] = Loadedplugin{table: ret}

				l.Push(ret)
				return 1
			} else {
				l.RaiseError("unable to find plugin %s", pluginpath)
			}
		}
		return 0
	}))
	L.SetField(postmaketable, "make", L.NewFunction(func(l *lua.LState) int {
		builder := l.ToTable(1)
		config := l.ToTable(2)
		settings := l.ToTable(3)

		makefuncion := l.GetField(builder, "make").(*lua.LFunction)

		config.ForEach(func(index, table lua.LValue) {
			configdata := prebuild.configs[0]

			filestable := l.NewTable()

			for _, v := range configdata.files {
				l.SetField(filestable, v.input, lua.LString(v.output))
			}

			l.SetField(table, "files", filestable)

			l.SetField(table, "mainfile", l.NewFunction(func(l *lua.LState) int {
				newtable := l.NewTable()

				l.SetField(newtable, "name", l.NewFunction(func(l *lua.LState) int {
					l.Push(lua.LString(path.Base(configdata.mainfile.input)))
					return 1
				}))
				l.SetField(newtable, "input", l.NewFunction(func(l *lua.LState) int {
					l.Push(lua.LString(configdata.mainfile.input))
					return 1
				}))
				l.SetField(newtable, "output", l.NewFunction(func(l *lua.LState) int {
					l.Push(lua.LString(configdata.mainfile.output))
					return 1
				}))

				l.Push(newtable)
				return 1
			}))
		})

		l.Push(makefuncion)

		l.Push(makepostbuildforplugin(l, *postmaketable, &prebuild))
		l.Push(config)
		l.Push(settings)

		err := l.PCall(3, 0, nil)

		if err != nil {
			log.Printf("Runing Plugin Failed '" + err.Error() + "'")
			os.Exit(1)
		}
		return 0
	}))
	L.SetGlobal("postmake", postmaketable)

	data, err := os.ReadFile(CLI.Build.Input)
	if err != nil {
		log.Printf("Unable to Read/Find file %s\n", CLI.Build.Input)
		os.Exit(1)
	}
	if err := L.DoString(string(data)); err != nil {
		panic(err)
	}
}

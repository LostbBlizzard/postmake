package main

import (
	"embed"
	"errors"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"

	lua "github.com/yuin/gopher-lua"
)

//go:embed lua/**
var InternalPlugins embed.FS

type ScriptRunerInput struct {
	ScriptText string
	Target     string
}
type Loadedplugin struct {
	table lua.LValue
}
type InputFile struct {
	input  string
	output string
}
type Config struct {
	os          string
	arch        string
	mainfile    InputFile
	files       []InputFile
	path        []string
	flags       []Flag
	tabletoflag map[*lua.LTable]int

	dependsonflags []string
}

type Flag struct {
	FlagName     string
	DefaultValue bool
}
type PreBuildContext struct {
	target        string
	loadedplugins map[string]Loadedplugin
	configs       []Config

	tabletoconfig map[*lua.LTable]int
}

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

	newtableflags := l.NewTable()

	l.SetField(postbuilde, "flags", newtableflags)

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

func addconfigfuncions(L *lua.LState, table *lua.LTable, getonconfig func(func(config *Config)), prebuild *PreBuildContext) {

	L.SetField(table, "addfile", L.NewFunction(func(l *lua.LState) int {

		input := InputFile{
			input:  l.ToString(1),
			output: l.ToString(2),
		}

		getonconfig(func(config *Config) {
			config.files = append(config.files, input)
		})

		return 0
	}))
	L.SetField(table, "addmainfile", L.NewFunction(func(l *lua.LState) int {
		input := InputFile{
			input:  l.ToString(1),
			output: l.ToString(2),
		}

		getonconfig(func(config *Config) {
			config.files = append(config.files, input)
			config.mainfile = input
		})

		return 0
	}))
	L.SetField(table, "addpath", L.NewFunction(func(l *lua.LState) int {
		path := l.ToString(1)

		getonconfig(func(config *Config) {
			config.path = append(config.path, path)
		})

		return 0
	}))

	L.SetField(table, "newflag", L.NewFunction(func(l *lua.LState) int {
		flagname := l.ToString(1)
		flagdefaultvalue := l.ToBool(2)

		val := l.NewTable()

		getonconfig(func(config *Config) {
			config.flags = append(config.flags, Flag{
				FlagName:     flagname,
				DefaultValue: flagdefaultvalue,
			})
		})
		l.Push(val)
		return 1
	}))
	L.SetField(table, "If", L.NewFunction(func(l *lua.LState) int {
		flag := l.ToTable(1)

		val := l.NewTable()

		//Who doesn't love lambdas and recursion
		addconfigfuncions(l, val,
			func(f func(config *Config)) {

				getonconfig(func(config *Config) {
					flaginfo := config.flags[config.tabletoflag[flag]]
					foundconfig, ok := FindConfigWithFlag(prebuild, config.dependsonflags, flaginfo.FlagName)

					if !ok {
						configind := len(prebuild.configs)

						testconfig := Config{
							os:             config.os,
							arch:           config.arch,
							dependsonflags: append(config.dependsonflags, flaginfo.FlagName)}

						prebuild.configs = append(prebuild.configs, testconfig)
						foundconfig = &prebuild.configs[configind]
					}

					f(foundconfig)
				})

			}, prebuild)

		l.Push(val)
		return 1
	}))
}
func FindConfigWithFlag(context *PreBuildContext, flags []string, flag string) (*Config, bool) {

	for i, item := range context.configs {
		if len(item.dependsonflags) == len(flags)+1 {
			if StringArrayEquals(item.dependsonflags[:len(item.dependsonflags)-1], flags) {
				if item.dependsonflags[len(item.dependsonflags)-1] == flag {
					return &context.configs[i], true
				}
			}
		}
	}

	return nil, false

}

func StringArrayEquals(a []string, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i, v := range a {
		if v != b[i] {
			return false
		}
	}
	return true
}

func makeposttableconfig(l *lua.LState, table lua.LValue, configdata Config) {
	filestable := l.NewTable()

	for _, v := range configdata.files {
		l.SetField(filestable, v.input, lua.LString(v.output))
	}

	l.SetField(table, "files", filestable)

	pathtable := l.NewTable()
	for i, v := range configdata.path {
		l.RawSetInt(pathtable, i+1, lua.LString(v))
	}
	l.SetField(table, "paths", pathtable)

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

	newtableflags := l.NewTable()
	for i, element := range configdata.flags {

		tableelement := l.NewTable()

		l.SetField(tableelement, "flagname", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(element.FlagName))
			return 1

		}))

		l.SetField(tableelement, "defaultvalue", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LBool(element.DefaultValue))
			return 1
		}))

		newtableflags.RawSetInt(i+1, tableelement)
	}
	l.SetField(table, "flags", newtableflags)

}
func RunScript(input ScriptRunerInput) {
	L := lua.NewState()
	defer L.Close()

	log := log.New(os.Stderr, "", 0)

	prebuild := PreBuildContext{
		target:        CLI.Build.Target,
		loadedplugins: make(map[string]Loadedplugin),
		tabletoconfig: make(map[*lua.LTable]int),
	}

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
	addconfigfuncions(L, configalltable,
		func(f func(config *Config)) {
			for i, item := range prebuild.configs {
				if len(item.dependsonflags) == 0 {
					f(&prebuild.configs[i])
				}
			}
		}, &prebuild)

	L.SetField(postmaketable, "allconfig", configalltable)
	L.SetField(postmaketable, "foros", L.NewFunction(func(l *lua.LState) int {
		os := l.ToString(1)

		newtable := l.NewTable()
		addconfigfuncions(L, configalltable,
			func(f func(config *Config)) {
				for i, item := range prebuild.configs {
					if item.os == os && len(item.dependsonflags) == 0 {
						f(&prebuild.configs[i])
					}
				}
			}, &prebuild)

		l.Push(newtable)
		return 1
	}))
	L.SetField(postmaketable, "forarch", L.NewFunction(func(l *lua.LState) int {
		arch := l.ToString(1)
		newtable := l.NewTable()

		addconfigfuncions(L, configalltable,
			func(f func(config *Config)) {
				for i, item := range prebuild.configs {
					if item.arch == arch && len(item.dependsonflags) == 0 {
						f(&prebuild.configs[i])
					}
				}
			}, &prebuild)

		l.Push(newtable)
		return 1
	}))
	L.SetField(postmaketable, "newconfig", L.NewFunction(func(l *lua.LState) int {

		os := l.ToString(1)
		arch := l.ToString(2)

		ind := len(prebuild.configs)
		prebuild.configs = append(prebuild.configs, Config{
			os:             os,
			arch:           arch,
			tabletoflag:    make(map[*lua.LTable]int),
			dependsonflags: make([]string, 0),
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

		addconfigfuncions(L, val, func(f func(config *Config)) {
			f(&prebuild.configs[ind])
		}, &prebuild)

		prebuild.tabletoconfig[val] = ind
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

				data, err := InternalPlugins.ReadFile("lua/" + pluginname + "/init.lua")
				if err != nil {
					l.RaiseError("unable to read plugin %s init.lua [%s]", pluginpath, err.Error())
				}

				err = l.DoString(string(data))
				if err != nil {
					l.RaiseError("plugin %s failed to load \n\n\n %s", pluginpath, err.Error())
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
			configdata := prebuild.configs[prebuild.tabletoconfig[table.(*lua.LTable)]]

			makeposttableconfig(l, table, configdata)

			newtableindex := 1

			newifflagtable := l.NewTable()
			for _, element := range prebuild.configs {
				if element.os == configdata.os && element.arch == configdata.arch && len(element.dependsonflags) != 0 {
					newiftable := l.NewTable()

					newiflisttable := l.NewTable()
					for i, element := range element.dependsonflags {
						l.RawSetInt(newiflisttable, i+1, lua.LString(element))
					}
					l.SetField(newiftable, "iflist", newiflisttable)

					makeposttableconfig(l, newiftable, element)

					l.RawSetInt(newifflagtable, newtableindex, newiftable)
					newtableindex = newtableindex + 1

				}
			}
			l.SetField(table, "ifs", newifflagtable)
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

	if err := L.DoString(string(input.ScriptText)); err != nil {
		panic(err)
	}
}

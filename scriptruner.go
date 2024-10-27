package main

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"

	"postmake/luamodule"
	"postmake/utils"

	lua "github.com/yuin/gopher-lua"
)

//go:embed lua/**
var InternalFiles embed.FS

type ScriptRunerInput struct {
	ScriptText    string
	ScriptPath    string
	Target        string
	IsTestingMode bool
}
type Loadedplugin struct {
	table lua.LValue
}
type InputFile struct {
	input        string
	output       string
	isexecutable bool
}

type Dependsoninfo struct {
	flagname string
	value    string
}
type CommandInfo struct {
	cmd        string
	parameters []string
}
type Config struct {
	os    string
	arch  string
	files []InputFile
	path  []string

	installcmds  []CommandInfo
	uninstallcmd []CommandInfo

	flags     []Flag
	enumflags []EnumFlag

	tabletoflag map[*lua.LTable]int
	tabletoenum map[*lua.LTable]int

	dependsonflags []Dependsoninfo
}

type Flag struct {
	FlagName     string
	DefaultValue bool
}
type EnumFlag struct {
	FlagName     string
	Values       []string
	DefaultValue string
}
type PreBuildContext struct {
	target         string
	loadedplugins  map[string]Loadedplugin
	pluginsrequres map[string]lua.LValue
	configs        []Config

	tabletoconfig map[*lua.LTable]int
}

const LuaiNSTALLdIR = "/"
const LUAHOMEDir = "~/"

func makepostbuildforplugin(l *lua.LState, oldpostbuild lua.LTable, _ *PreBuildContext) *lua.LTable {
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

func addutills(l *lua.LState, table *lua.LTable) {

	l.SetField(table, "os", luamodule.MakeOsModule(l))
	l.SetField(table, "match", luamodule.MakeMatchModule(l))
	l.SetField(table, "archive", luamodule.MakeArchiveModule(l))
	l.SetField(table, "path", luamodule.MakePathModule(l))
	l.SetField(table, "compile", luamodule.MakeCompileModule(l, InternalFiles))

	{
		filetext, err := InternalFiles.ReadFile("lua/api/modules/lua.lua")
		if err != nil {
			panic(err)
		}

		if err := l.DoString(string(filetext)); err != nil {
			panic(err)
		}
		l.SetField(table, "lua", l.ToTable(-1))
		l.Pop(1)
	}

	{
		filetext, err := InternalFiles.ReadFile("lua/api/modules/json.lua")
		if err != nil {
			panic(err)
		}

		if err := l.DoString(string(filetext)); err != nil {
			panic(err)
		}
		l.SetField(table, "json", l.ToTable(-1))
		l.Pop(1)
	}
}

func addconfigfuncions(L *lua.LState, table *lua.LTable, getonconfig func(func(config *Config)), prebuild *PreBuildContext) {

	L.SetField(table, "addfile", L.NewFunction(func(l *lua.LState) int {

		input := InputFile{
			input:        l.ToString(1),
			output:       l.ToString(2),
			isexecutable: false,
		}

		getonconfig(func(config *Config) {
			config.files = append(config.files, input)
		})

		return 0
	}))
	L.SetField(table, "addxfile", L.NewFunction(func(l *lua.LState) int {

		input := InputFile{
			input:        l.ToString(1),
			output:       l.ToString(2),
			isexecutable: true,
		}

		getonconfig(func(config *Config) {
			config.files = append(config.files, input)
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
	L.SetField(table, "addinstallcmd", L.NewFunction(func(l *lua.LState) int {
		cmd := l.ToString(1)
		pars := utils.Tostringarray(l.ToTable(2))

		getonconfig(func(config *Config) {
			config.installcmds = append(config.installcmds, CommandInfo{cmd: cmd, parameters: pars})
		})

		return 0
	}))
	L.SetField(table, "adduninstallcmd", L.NewFunction(func(l *lua.LState) int {
		cmd := l.ToString(1)
		pars := utils.Tostringarray(l.ToTable(2))

		getonconfig(func(config *Config) {
			config.uninstallcmd = append(config.uninstallcmd, CommandInfo{cmd: cmd, parameters: pars})
		})

		return 0
	}))
	L.SetField(table, "newflag", L.NewFunction(func(l *lua.LState) int {
		flagname := l.ToString(1)
		flagdefaultvalue := l.ToBool(2)

		val := l.NewTable()
		l.SetField(val, "name", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(flagname))
			return 1
		}))
		l.SetField(val, "isflag", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LBool(true))
			return 1
		}))
		l.SetField(val, "default", l.NewFunction(func(l *lua.LState) int {
			r := "false"
			if flagdefaultvalue {
				r = "true"
			}
			l.Push(lua.LString(r))
			return 1
		}))

		getonconfig(func(config *Config) {
			config.flags = append(config.flags, Flag{
				FlagName:     flagname,
				DefaultValue: flagdefaultvalue,
			})
		})
		l.Push(val)
		return 1
	}))
	L.SetField(table, "newenum", L.NewFunction(func(l *lua.LState) int {
		flagname := l.ToString(1)
		flagsvalues := utils.Tostringarray(l.ToTable(2))
		flagdefaultvalue := l.ToString(3)

		val := l.NewTable()
		l.SetField(val, "name", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(flagname))
			return 1
		}))
		l.SetField(val, "isflag", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LBool(false))
			return 1
		}))
		l.SetField(val, "default", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(flagdefaultvalue))
			return 1
		}))

		getonconfig(func(config *Config) {
			config.enumflags = append(config.enumflags, EnumFlag{
				FlagName:     flagname,
				Values:       flagsvalues,
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
					foundconfig, ok := FindConfigWithFlag(prebuild, config.dependsonflags, flaginfo.FlagName, "true")

					if !ok {
						configind := len(prebuild.configs)

						testconfig := Config{
							os:   config.os,
							arch: config.arch,
							dependsonflags: append(config.dependsonflags, Dependsoninfo{
								flagname: flaginfo.FlagName,
								value:    "true",
							})}

						prebuild.configs = append(prebuild.configs, testconfig)
						foundconfig = &prebuild.configs[configind]
					}

					f(foundconfig)
				})

			}, prebuild)

		l.Push(val)
		return 1
	}))
	L.SetField(table, "IfNot", L.NewFunction(func(l *lua.LState) int {
		flag := l.ToTable(1)

		val := l.NewTable()

		//Who doesn't love lambdas and recursion
		addconfigfuncions(l, val,
			func(f func(config *Config)) {

				getonconfig(func(config *Config) {
					flaginfo := config.flags[config.tabletoflag[flag]]
					foundconfig, ok := FindConfigWithFlag(prebuild, config.dependsonflags, flaginfo.FlagName, "false")

					if !ok {
						configind := len(prebuild.configs)

						testconfig := Config{
							os:   config.os,
							arch: config.arch,
							dependsonflags: append(config.dependsonflags, Dependsoninfo{
								flagname: flaginfo.FlagName,
								value:    "false",
							}),
						}

						prebuild.configs = append(prebuild.configs, testconfig)
						foundconfig = &prebuild.configs[configind]
					}

					f(foundconfig)
				})

			}, prebuild)

		l.Push(val)
		return 1
	}))
	L.SetField(table, "IfEnum", L.NewFunction(func(l *lua.LState) int {
		flag := l.ToTable(1)
		enumvalue := l.ToString(2)

		val := l.NewTable()

		//Who doesn't love lambdas and recursion
		addconfigfuncions(l, val,
			func(f func(config *Config)) {

				getonconfig(func(config *Config) {
					flaginfo := config.enumflags[config.tabletoenum[flag]]
					foundconfig, ok := FindConfigWithFlag(prebuild, config.dependsonflags, flaginfo.FlagName, enumvalue)

					if !ok {
						configind := len(prebuild.configs)

						testconfig := Config{
							os:   config.os,
							arch: config.arch,
							dependsonflags: append(config.dependsonflags, Dependsoninfo{
								flagname: flaginfo.FlagName,
								value:    enumvalue,
							})}

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
func FindConfigWithFlag(context *PreBuildContext, flags []Dependsoninfo, flag string, value string) (*Config, bool) {

	for i, item := range context.configs {
		if len(item.dependsonflags) == len(flags)+1 {
			if StringArrayEquals(item.dependsonflags[:len(item.dependsonflags)-1], flags) {
				value := item.dependsonflags[len(item.dependsonflags)-1]
				if value.flagname == flag && value.flagname == value.value {
					return &context.configs[i], true
				}
			}
		}
	}

	return nil, false

}

func StringArrayEquals(a []Dependsoninfo, b []Dependsoninfo) bool {
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

func CmdArrayToLua(l *lua.LState, list []CommandInfo) lua.LValue {
	r := l.NewTable()

	for i, element := range list {
		tableelement := l.NewTable()

		l.SetField(tableelement, "cmd", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(element.cmd))
			return 1

		}))

		l.SetField(tableelement, "pars", l.NewFunction(func(l *lua.LState) int {
			parslist := l.NewTable()
			for i, element := range element.parameters {
				l.RawSetInt(parslist, i+1, lua.LString(element))
			}
			l.Push(parslist)
			return 1
		}))
		l.RawSetInt(r, i+1, tableelement)
	}

	return r
}
func makeposttableconfig(l *lua.LState, table lua.LValue, configdata Config) {
	filestable := l.NewTable()

	for _, v := range configdata.files {

		inputtable := l.NewTable()
		l.SetField(inputtable, "string", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(v.input))
			return 1
		}))
		l.SetField(inputtable, "isexecutable", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LBool(v.isexecutable))
			return 1
		}))

		l.SetTable(filestable, inputtable, lua.LString(v.output))

	}

	l.SetField(table, "files", filestable)

	pathtable := l.NewTable()
	for i, v := range configdata.path {
		l.RawSetInt(pathtable, i+1, lua.LString(v))
	}
	l.SetField(table, "paths", pathtable)

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

	newtableenumflags := l.NewTable()
	for i, element := range configdata.enumflags {
		tableelement := l.NewTable()

		l.SetField(tableelement, "flagname", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(element.FlagName))
			return 1

		}))

		l.SetField(tableelement, "defaultvalue", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LString(element.DefaultValue))
			return 1
		}))

		l.SetField(tableelement, "values", l.NewFunction(func(l *lua.LState) int {
			newlist := l.NewTable()
			for i, v := range element.Values {
				l.RawSetInt(newlist, i+1, lua.LString(v))
			}

			l.Push(newlist)
			return 1
		}))

		newtableenumflags.RawSetInt(i+1, tableelement)
	}
	l.SetField(table, "enumflags", newtableenumflags)

	l.SetField(table, "installcmds", CmdArrayToLua(l, configdata.installcmds))
	l.SetField(table, "uninstallcmds", CmdArrayToLua(l, configdata.uninstallcmd))

}

type PluginRef struct {
	Url  string
	Hash string
}
type LockFileFormat struct {
	Version  int         `json:"Version"`
	Direct   []PluginRef `json:"Direct"`
	Indirect []PluginRef `json:"Indirect"`
}
type MasterPluginsFileFormat struct {
	Version int `json:"Version"`
}

func DoMigrationIfNeeded(externalpluginspath string) error {
	masterfilepath := path.Join(externalpluginspath, "masterplugin.json")

	masterfilexist := true
	if _, err := os.Stat(masterfilepath); errors.Is(err, os.ErrNotExist) {
		masterfilexist = false
	}

	if masterfilexist {
		data, err := os.ReadFile(masterfilepath)
		if err != nil {
			return err
		}

		var masterplugin MasterPluginsFileFormat
		err = json.Unmarshal(data, &masterplugin)
		if err != nil {
			return err
		}

		//uncomment if needed
		//if (masterplugin.Version == 1) { }
	} else {
		newmasterplugin := MasterPluginsFileFormat{Version: 1}

		jsondata, err := json.MarshalIndent(newmasterplugin, "", "    ")
		if err != nil {
			return err
		}

		err = os.WriteFile(masterfilepath, jsondata, 0644)
		if err != nil {
			return err
		}
	}
	return nil
}

func RunScript(input ScriptRunerInput) {
	L := lua.NewState()
	defer L.Close()

	log := log.New(os.Stderr, "", 0)

	prebuild := PreBuildContext{
		target:         CLI.Build.Target,
		loadedplugins:  make(map[string]Loadedplugin),
		tabletoconfig:  make(map[*lua.LTable]int),
		pluginsrequres: make(map[string]lua.LValue),
	}

	postmaketable := L.NewTable()
	addutills(L, postmaketable)

	L.SetField(postmaketable, "appname", lua.LString("app"))
	L.SetField(postmaketable, "appversion", lua.LString("0.0.1"))
	L.SetField(postmaketable, "apppublisher", lua.LString("publisher"))
	L.SetField(postmaketable, "appwebsite", lua.LString("https://github.com/LostbBlizzard/postmake"))
	L.SetField(postmaketable, "applicensefile", lua.LString(""))
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
		addconfigfuncions(L, newtable,
			func(f func(config *Config)) {
				for i, item := range prebuild.configs {

					okcheck := false
					if os == "unix" {
						okcheck = item.os == "linux" || item.os == "macos"
					} else {
						okcheck = item.os == os
					}

					if okcheck && len(item.dependsonflags) == 0 {
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
			dependsonflags: make([]Dependsoninfo, 0),
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

	currentplugin := ""
	L.SetField(postmaketable, "loadplugin", L.NewFunction(func(l *lua.LState) int {
		pluginpath := l.ToString(1)

		val, ok := prebuild.loadedplugins[pluginpath]
		if ok {
			l.Push(val.table)
			return 1
		} else {

			if strings.HasPrefix(pluginpath, "internal/") {
				pluginname := pluginpath[len("internal/"):]
				data, err := InternalFiles.ReadFile("lua/" + pluginname + "/init.lua")
				if err != nil {
					l.RaiseError("unable to read plugin %s init.lua [%s]", pluginpath, err.Error())
				}

				old := currentplugin
				currentplugin = "lua/" + pluginname
				err = l.DoString(string(data))
				currentplugin = old

				if err != nil {
					l.RaiseError("plugin %s failed to load \n\n\n %s", pluginpath, err.Error())
				}
				ret := l.Get(-1)
				l.Pop(1)

				prebuild.loadedplugins[pluginpath] = Loadedplugin{table: ret}
				l.Push(ret)
				return 1
			} else if strings.HasPrefix(pluginpath, "https://") {

				err := exec.Command("git", "-v").Run()
				isgitinstalled := err == nil

				if !isgitinstalled {
					l.RaiseError("git is not installed.Unable to git clone")
					return 0
				}

				lockfilepath := filepath.Join(filepath.Dir(input.ScriptPath), "postmake.lock.json")

				lockfileexist := true
				if _, err := os.Stat(lockfilepath); errors.Is(err, os.ErrNotExist) {
					lockfileexist = false
				}

				isdirect := currentplugin == ""

				lockfile := LockFileFormat{
					Version:  1,
					Direct:   make([]PluginRef, 0),
					Indirect: make([]PluginRef, 0),
				}

				if lockfileexist {
					data, err := os.ReadFile(lockfilepath)
					if err != nil {
						fmt.Print(err)
						os.Exit(1)
					}
					err = json.Unmarshal(data, &lockfile)

					if err != nil {
						l.RaiseError("unable to parse %s. error: %s", lockfilepath, err.Error())
						return 0
					}
				}

				home, err := os.UserHomeDir()
				if err != nil {
					l.RaiseError("Unable to Get User HomeDir. error: %s", err.Error())
					return 0
				}

				fullpluginname := strings.ReplaceAll(pluginpath, "/", "_")[len("https://"):]
				externalpluginpath := path.Join(home, ".postmake", "externalplugins")

				err = DoMigrationIfNeeded(externalpluginpath)
				if err != nil {
					l.RaiseError("Checking for Migration failed. error: %s", err.Error())
					return 0
				}

				err = os.MkdirAll(externalpluginpath, os.ModePerm)
				if err != nil {
					l.RaiseError("Unable to make external pluginDir. error: %s", err.Error())
					return 0
				}

				plugindir := path.Join(externalpluginpath, fullpluginname)

				baredir := path.Join(plugindir, "bare")
				checkeoutdir := path.Join(plugindir, "checkedout")

				err = os.MkdirAll(checkeoutdir, os.ModePerm)

				plugindirexist := true
				if _, err := os.Stat(baredir); errors.Is(err, os.ErrNotExist) {
					plugindirexist = false
				}

				if !plugindirexist {
					println("downloading " + pluginpath)
					stdout, err := exec.Command("git", "clone", "--bare", pluginpath, baredir).CombinedOutput()
					println(stdout)
					if err != nil {
						l.RaiseError("git clone failed. error: %s", err.Error())
						return 0
					}
				}

				hasinlock := false
				hashtouse := ""

				var listtocheck *[]PluginRef = nil

				if isdirect {
					listtocheck = &lockfile.Direct
				} else {
					listtocheck = &lockfile.Indirect
				}

				for _, item := range *listtocheck {
					if item.Url == pluginpath {
						hasinlock = true
						hashtouse = item.Hash
					}
				}

				if !hasinlock {
					if true {
						println("git pulling " + pluginpath)
						cmd := exec.Command("git", "pull")
						cmd.Dir = baredir

						err = cmd.Start()
						if err != nil {
							l.RaiseError("git pull. error: %s", err.Error())
							return 0
						}
					}

					cmd := exec.Command("git", "rev-parse", "HEAD")
					cmd.Dir = baredir
					githash, err := cmd.Output()
					if err != nil {
						l.RaiseError("git rev-parse HEAD failed. error: %s", err.Error())
						return 0
					}
					hashtouse = string(githash[:len(githash)-1]) // remove the \n on the end

					var newpluginref = PluginRef{
						Url:  pluginpath,
						Hash: string(hashtouse),
					}

					(*listtocheck) = append(*listtocheck, newpluginref)
				}

				newestdir := path.Join(checkeoutdir, string(hashtouse))

				haschecked := true
				if _, err := os.Stat(newestdir); errors.Is(err, os.ErrNotExist) {
					haschecked = false
				}

				if !haschecked {
					println("git checkout " + hashtouse)
					_, err = exec.Command("git", "clone", baredir, newestdir).Output()
					if err != nil {
						l.RaiseError("git clone failed. error: %s", err.Error())
						return 0
					}

					gitfiles := path.Join(newestdir, ".git")

					err = os.RemoveAll(gitfiles) // this dir is unneeded.
					if err != nil {
						l.RaiseError("removeing .git failed. error: %s", err.Error())
						return 0
					}
				}

				initfile := path.Join(newestdir, "init.lua")
				data, err := os.ReadFile(initfile)
				if err != nil {
					l.RaiseError("unable to read plugin %s init.lua [%s]", pluginpath, err.Error())
				}

				old := currentplugin
				currentplugin = initfile
				err = l.DoString(string(data))
				currentplugin = old

				if err != nil {
					l.RaiseError("plugin %s failed to load \n\n\n %s", pluginpath, err.Error())
				}
				ret := l.Get(-1)
				l.Pop(1)

				prebuild.loadedplugins[pluginpath] = Loadedplugin{table: ret}
				l.Push(ret)

				jsondata, err := json.MarshalIndent(lockfile, "", "    ")
				if err != nil {
					l.RaiseError("json Marshal failed. error: %s", err.Error())
					return 0
				}
				err = os.WriteFile(lockfilepath, jsondata, 0644)
				if err != nil {
					l.RaiseError("writeing to lockfile failed. error: %s", err.Error())
					return 0
				}

				return 1

			} else {

				if strings.Contains(pluginpath, "~/") {
					home, err := os.UserHomeDir()
					if err != nil {
						l.RaiseError("Unable to Get User HomeDir. error: %s", err.Error())
						return 0
					}

					pluginpath = strings.ReplaceAll(pluginpath, "~/", home+"/")
				}

				initfile := path.Join(pluginpath, "init.lua")
				data, err := os.ReadFile(initfile)
				if err != nil {
					l.RaiseError("unable to read plugin %s init.lua [%s]", pluginpath, err.Error())
				}

				old := currentplugin
				currentplugin = initfile
				err = l.DoString(string(data))
				currentplugin = old

				if err != nil {
					l.RaiseError("plugin %s failed to load \n\n\n %s", pluginpath, err.Error())
				}
				ret := l.Get(-1)
				l.Pop(1)

				prebuild.loadedplugins[pluginpath] = Loadedplugin{table: ret}
				l.Push(ret)

				return 1
			}
		}
		return 0
	}))
	L.SetField(postmaketable, "require", L.NewFunction(func(l *lua.LState) int {
		filepath := l.ToString(1)

		if strings.HasPrefix(filepath, "./") {
			filepath = filepath[len("."):]
		} else {
			filepath = "/" + filepath
		}

		newpath := currentplugin + filepath

		value, ok := prebuild.pluginsrequres[newpath]

		if ok {
			l.Push(value)
			return 1
		}

		data, err := InternalFiles.ReadFile(newpath)
		if err != nil {
			l.RaiseError("unable to read plugin file '%s' [%s]", newpath, err.Error())
		}

		err = l.DoString(string(data))
		if err != nil {
			l.RaiseError("unable to read plugin %s init.lua [%s]", newpath, err.Error())
		}

		ret := l.Get(-1)
		l.Pop(1)

		prebuild.pluginsrequres[newpath] = ret

		l.Push(ret)
		return 1
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
						elementtable := l.NewTable()

						l.SetField(elementtable, "flagname", L.NewFunction(func(l *lua.LState) int {
							l.Push(lua.LString(element.flagname))
							return 1
						}))
						l.SetField(elementtable, "value", L.NewFunction(func(l *lua.LState) int {
							l.Push(lua.LString(element.value))
							return 1
						}))
						l.SetField(elementtable, "isflag", L.NewFunction(func(l *lua.LState) int {
							l.Push(lua.LBool(element.value == "true" || element.value == "false"))
							return 1
						}))
						l.RawSetInt(newiflisttable, i+1, elementtable)
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

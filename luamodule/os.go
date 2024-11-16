package luamodule

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"

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
	l.SetField(table, "ln", l.NewFunction(func(l *lua.LState) int {
		input := l.ToString(1)
		output := l.ToString(2)

		err := os.Symlink(input, output)
		utils.CheckErr(err)

		return 0
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
		l.SetField(unametable, "isunix", l.NewFunction(func(l *lua.LState) int {
			r := runtime.GOOS == "linux" || runtime.GOOS == "darwin" || runtime.GOOS == "freebsd"
			l.Push(lua.LBool(r))
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

	l.SetField(table, "sleep", l.NewFunction(func(l *lua.LState) int {
		sec := l.ToInt64(1)
		time.Sleep(time.Duration(sec) * time.Second)
		return 0
	}))

	l.SetField(table, "exec", l.NewFunction(func(l *lua.LState) int {
		cmd := l.ToString(1)
		args := utils.Tostringarray(l.ToTable(2))

		type processstate struct {
			process          *exec.Cmd
			workingdir       string
			stdinpipe        *io.WriteCloser
			stdoutpipe       *io.ReadCloser
			stderrpipe       *io.ReadCloser
			onexitcallback   *lua.LFunction
			onstdoutcallback *lua.LFunction
			onstderrcallback *lua.LFunction
		}
		state := processstate{
			process: exec.Command(cmd, args...),
		}
		//table state

		//
		rettable := l.NewTable()
		l.SetField(rettable, "start", l.NewFunction(func(l *lua.LState) int {
			err := state.process.Start()
			utils.CheckErr(err)

			return 0
		}))

		l.SetField(rettable, "setworkingdir", l.NewFunction(func(l *lua.LState) int {
			state.process.Dir = state.workingdir
			return 0
		}))
		l.SetField(rettable, "stdinwrite", l.NewFunction(func(l *lua.LState) int {
			data := l.ToString(1)
			if state.stdinpipe == nil {
				stdinpipe, err := state.process.StdinPipe()
				utils.CheckErr(err)
				state.stdinpipe = &stdinpipe
			}
			_, err := (*state.stdinpipe).Write([]byte(data))
			utils.CheckErr(err)
			return 0
		}))
		l.SetField(rettable, "onstderror", l.NewFunction(func(l *lua.LState) int {
			callback := l.ToFunction(1)
			state.onstderrcallback = callback
			return 0
		}))
		l.SetField(rettable, "onstdout", l.NewFunction(func(l *lua.LState) int {
			callback := l.ToFunction(1)
			state.onstdoutcallback = callback
			return 0
		}))
		l.SetField(rettable, "onexit", l.NewFunction(func(l *lua.LState) int {
			callback := l.ToFunction(1)
			state.onexitcallback = callback
			return 0
		}))
		l.SetField(rettable, "exited", l.NewFunction(func(l *lua.LState) int {
			l.Push(lua.LBool(state.process.ProcessState.Exited()))
			return 1
		}))
		l.SetField(rettable, "wait", l.NewFunction(func(l *lua.LState) int {
			utils.CheckErr(state.process.Wait())
			return 0
		}))
		l.SetField(rettable, "kill", l.NewFunction(func(l *lua.LState) int {
			utils.CheckErr(state.process.Process.Kill())
			return 0
		}))
		l.SetField(rettable, "sync", l.NewFunction(func(l *lua.LState) int {
			if state.onstdoutcallback != nil {
				if state.stdoutpipe == nil {
					stdinpipe, err := state.process.StdoutPipe()
					utils.CheckErr(err)
					state.stdoutpipe = &stdinpipe
				}

				newtext := make([]byte, 0)
				_, err := (*state.stdoutpipe).Read(newtext)
				utils.CheckErr(err)

				l.Push(state.onstdoutcallback)
				l.Push(lua.LString(newtext))
				l.PCall(1, 0, nil)
			}
			if state.onstderrcallback != nil {
				if state.stderrpipe == nil {
					stdinpipe, err := state.process.StderrPipe()
					utils.CheckErr(err)
					state.stderrpipe = &stdinpipe
				}

				newtext := make([]byte, 0)
				_, err := (*state.stderrpipe).Read(newtext)
				utils.CheckErr(err)

				l.Push(state.onstderrcallback)
				l.Push(lua.LString(newtext))
				l.PCall(1, 0, nil)
			}

			utils.CheckErr(state.process.Process.Kill())
			return 0
		}))

		l.Push(rettable)
		return 1
	}))

	curltable := l.NewTable()
	{
		// from https://stackoverflow.com/questions/11692860/how-can-i-efficiently-download-a-large-file-using-go by answered Nov 22, 2015 at 10:38 Pablo Jomer
		l.SetField(curltable, "downloadfile", l.NewFunction(func(l *lua.LState) int {
			url := l.ToString(1)
			outputpath := l.ToString(2)

			// Create the file
			out, err := os.Create(outputpath)
			if err != nil {
				utils.CheckErr(err)
			}
			defer out.Close()

			// Get the data
			resp, err := http.Get(url)
			if err != nil {
				utils.CheckErr(err)
			}
			defer resp.Body.Close()

			// Check server response
			if resp.StatusCode != http.StatusOK {
				err := fmt.Errorf("bad status: %s", resp.Status)
				utils.CheckErr(err)
			}

			// Writer the body to file
			_, err = io.Copy(out, resp.Body)
			if err != nil {
				utils.CheckErr(err)
			}

			return 0
		}))

		l.SetField(curltable, "post", l.NewFunction(func(l *lua.LState) int {
			url := l.ToString(1)
			body := l.ToString(2)

			_, err := http.NewRequest("POST", url, bytes.NewBuffer([]byte(body)))
			utils.CheckErr(err)

			return 0
		}))
	}

	l.SetField(table, "curl", curltable)

	return table
}

package main

import (
	"os"
	"os/exec"
	"testing"
)

// Just testing for no runtime errors
func TestScript(t *testing.T) {

	rootdir, _ := os.Getwd()

	testdir := rootdir + "/tests/"
	items, _ := os.ReadDir(testdir)

	cmd := exec.Command("go", "build")
	err := cmd.Start()
	if err != nil {
		panic(err)
	}
	err = cmd.Wait()
	if err != nil {
		panic(err)
	}

	for _, item := range items {
		if item.IsDir() {
			t.Run(item.Name(), func(t *testing.T) {

				os.Chdir(rootdir)

				workingdir := testdir + item.Name()

				os.Chdir(workingdir)

				cmd := exec.Command(rootdir+"/postmake", "build")
				err := cmd.Run()
				if err != nil {
					t.Fatalf(err.Error())
				}

			})
		}
	}
}

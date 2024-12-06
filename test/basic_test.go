package main

import (
	"os"
	"os/exec"
	"testing"
)

// Just testing for no runtime errors
func TestScript(t *testing.T) {

	rootdir, _ := os.Getwd()
	rootdir = rootdir + "/.."

	testdir := rootdir + "/test/"
	items, _ := os.ReadDir(testdir)

	cmd := exec.Command("make", "postmake")
	cmd.Dir = rootdir
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
			if item.Name() == "testutils" {
				return
			}

			t.Run(item.Name(), func(t *testing.T) {

				os.Chdir(rootdir)

				workingdir := testdir + item.Name()

				os.Chdir(workingdir)

				cmd := exec.Command(rootdir+"/postmake", "build")
				output, err := cmd.CombinedOutput()

				println("---" + item.Name())
				cmdoutput := string(output)
				space := "  "

				print(space)
				for _, c := range cmdoutput {
					print(string(c))
					if c == '\n' {
						print(space)
					}
				}
				println("\n")

				if err != nil {

					println("---[test failed]")
					t.Fatalf(err.Error())
				}

			})
		}
	}
}

package main

import (
	"os"
	"testing"
)

// Just testing for no runtime errors
func TestScript(t *testing.T) {
	var tests = []struct {
		inputfile string
	}{}
	for _, tt := range tests {
		t.Run(tt.inputfile, func(t *testing.T) {

			data, err := os.ReadFile(tt.inputfile)
			if err != nil {
				panic(err)
			}
			RunScript(ScriptRunerInput{ScriptText: string(data), Target: "any"})
		})
	}
}

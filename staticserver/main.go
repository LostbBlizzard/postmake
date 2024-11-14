package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	val := os.Args[1]
	if val == "" {
		val = "3000"
	}

	staticfiledir := os.Args[2]
	if staticfiledir == "" {
		staticfiledir = "./static"
	}

	fs := http.FileServer(http.Dir(staticfiledir))

	http.Handle("/", fs)

	log.Print("Listening on :" + val + "...")
	err := http.ListenAndServe(":"+val, nil)
	if err != nil {
		log.Fatal(err)
	}
}

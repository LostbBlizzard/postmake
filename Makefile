BuildInstallers:
	mkdir -p ./output
	env GOOS=windows go build -o ./output/postmake.exe -v .
	env GOOS=linux go build -o ./output/postmake -v .
	env GOOS=darwin go build -o ./output/postmake_macos -v .
	./output/postmake build


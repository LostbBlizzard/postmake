BuildInstallers:
	mkdir -p ./lua/bin
	env GOOS=windows go build -o ./lua/bin/win32 -v ./luaruner/main.go
	env GOOS=linux go build -o ./lua/bin/linux32 -v ./luaruner/main.go
	env GOOS=darwin go build -o ./lua/bin/mac -v ./luaruner/main.go
	
	mkdir -p ./output
	env GOOS=windows go build -o ./output/postmake.exe -v .
	env GOOS=linux go build -o ./output/postmake -v .
	env GOOS=darwin go build -o ./output/postmake_macos -v .
	./output/postmake build


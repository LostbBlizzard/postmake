BuildInstallers:
	make PreBuildInstallers
	./output/postmake build

BuildInstallersWin:
	make PreBuildInstallers
	./output/postmake.exe build

PreBuildInstallers:
	mkdir -p ./lua/bin
	env GOOS=windows go build -o ./lua/bin/win32 -v ./luaruner/main.go
	env GOOS=linux go build -o ./lua/bin/linux32 -v ./luaruner/main.go
	env GOOS=darwin go build -o ./lua/bin/mac -v ./luaruner/main.go
	
	mkdir -p ./output
	env GOOS=windows go build -o ./output/postmake.exe -v .
	env GOOS=linux go build -o ./output/postmake -v .
	env GOOS=darwin go build -o ./output/postmake_macos -v .

BuildAPIDocs:
	luadocparser run --files ./lua/api
BuildDoc:
	luadocparser run --files ./lua/api
	cd ./doc; mdbook build --dest-dir ./output

WatchDoc:
	cd ./doc; mdbook watch --dest-dir ./output

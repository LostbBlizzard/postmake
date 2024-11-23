BuildInstallers:
	make PreBuildInstallers
	./output/postmake build

BuildInstallersWin:
	make PreBuildInstallers
	output\postmake.exe build

PreBuildInstallers:
	mkdir -p ./lua/bin
	env GOOS=windows GOARCH=amd64 go build -o ./lua/bin/win32 -v ./luaruner/main.go
	env GOOS=linux GOARCH=amd64 go build -o ./lua/bin/linux32 -v ./luaruner/main.go
	env GOOS=darwin GOARCH=amd64 go build -o ./lua/bin/mac -v ./luaruner/main.go
	
	mkdir -p ./output

	cp ./version.yaml ./version.yaml.bak

	python3 ./updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} windows x86_64
	env GOOS=windows GOARCH=amd64 go build -o ./output/postmake.exe -v .
	
	python3 ./updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} linux x86_64
	env GOOS=linux GOARCH=amd64 go build -o ./output/postmake -v .

	python3 ./updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} macos x86_64
	env GOOS=darwin GOARCH=amd64 go build -o ./output/postmake_macos -v .

	python3 ./updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} macos arm64
	env GOOS=darwin GOARCH=arm64 go build -o ./output/postmake_macos_arm64 -v .

	mv ./version.yaml.bak ./version.yaml

BuildAPIDocs:
	luadocparser run --files ./lua/api
BuildDoc:
	luadocparser run --files ./lua/api
	cd ./doc; mdbook build --dest-dir ./output

WatchDoc:
	cd ./doc; mdbook watch --dest-dir ./output

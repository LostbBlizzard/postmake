.PHONY: test clean postmake

BuildInstallers:
	make prebuildinstallers
	./output/postmake build

BuildInstallersWin:
	make prebuildinstallers
	output\postmake.exe build

clean:
	rm -rf ./internal/lua
	rm -rf ./output
	rm -rf ./test/rollback1/installedapp
	rm -rf ./test/rollback1/output
	rm -rf ./test/basictest1/installedapp
	rm -rf ./test/basictest1/output
	rm -f ./postmake

testbuild:
	env VERSIONNAME=0.0.0 POSTMAKEVERSION=0.0.0 make PreBuildInstallers
postmake:
	go build -o postmake -v ./cmd/postmake/main.go 
test:
	go test ./test/...

prebuildinstallers:
	mkdir -p ./internal/lua/bin
	env GOOS=windows GOARCH=amd64 go build -o ./internal/lua/bin/win32 -v ./cmd/luaruner/main.go
	env GOOS=linux GOARCH=amd64 go build -o ./internal/lua/bin/linux32 -v ./cmd/luaruner/main.go
	env GOOS=darwin GOARCH=amd64 go build -o ./internal/lua/bin/mac -v ./cmd/luaruner/main.go
	
	mkdir -p ./output

	cp ./cmd/postmake/version.yaml ./cmd/postmake/version.yaml.bak

	python3 ./scripts/updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} windows x86_64
	env GOOS=windows GOARCH=amd64 go build -o ./output/postmake.exe -v ./cmd/postmake/main.go
	
	python3 ./scripts/updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} linux x86_64
	env GOOS=linux GOARCH=amd64 go build -o ./output/postmake -v ./cmd/postmake/main.go

	python3 ./scripts/updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} macos x86_64
	env GOOS=darwin GOARCH=amd64 go build -o ./output/postmake_macos -v ./cmd/postmake/main.go

	python3 ./scripts/updateversion.py ${VERSIONNAME} ${POSTMAKEVERSION} macos arm64
	env GOOS=darwin GOARCH=arm64 go build -o ./output/postmake_macos_arm64 -v ./cmd/postmake/main.go

	mv ./cmd/postmake/version.yaml.bak ./cmd/postmake/version.yaml

apidoc:
	luadocparser run --files ./lua/api
doc:
	luadocparser run --files ./lua/api
	cd ./doc; mdbook build --dest-dir ./output

watchdoc:
	cd ./doc; mdbook watch --dest-dir ./output

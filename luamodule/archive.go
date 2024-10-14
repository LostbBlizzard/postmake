package luamodule

import (
	"context"
	"os"
	"postmake/utils"

	"github.com/mholt/archiver/v4"
	lua "github.com/yuin/gopher-lua"
)

func MakeArchiveModule(l *lua.LState) *lua.LTable {
	table := l.NewTable()
	l.SetField(table, "make_tar_gz", l.NewFunction(func(l *lua.LState) int {
		inputfiles := utils.Tostringstringmap(l.ToTable(1))
		outputpath := l.ToString(2)

		files, err := archiver.FilesFromDisk(nil, inputfiles)
		utils.CheckErr(err)

		out, err := os.Create(outputpath)
		utils.CheckErr(err)
		defer out.Close()

		format := archiver.CompressedArchive{
			Compression: archiver.Gz{},
			Archival:    archiver.Tar{},
		}

		err = format.Archive(context.Background(), out, files)
		utils.CheckErr(err)
		return 1
	}))
	l.SetField(table, "make_zip", l.NewFunction(func(l *lua.LState) int {
		inputfiles := utils.Tostringstringmap(l.ToTable(1))
		outputpath := l.ToString(2)

		files, err := archiver.FilesFromDisk(nil, inputfiles)
		utils.CheckErr(err)

		out, err := os.Create(outputpath)
		utils.CheckErr(err)
		defer out.Close()

		format := archiver.Zip{}

		err = format.Archive(context.Background(), out, files)
		utils.CheckErr(err)
		return 1
	}))
	return table
}

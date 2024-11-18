package luamodule

import lua "github.com/yuin/gopher-lua"

type Threadmoduleinfo struct {
	Maincompiled *lua.FunctionProto
	Threads      []chan lua.LValue
}

func initworkerthread(l *lua.LState) {

}

func DoCompiled_(L *lua.LState, proto *lua.FunctionProto) error {
	lfunc := L.NewFunctionFromProto(proto)
	L.Push(lfunc)
	return L.PCall(0, lua.MultRet, nil)
}

func newworkerthread(ch chan lua.LValue, Maincompiled *lua.FunctionProto) {
	L := lua.NewState()

	postmaketable := L.NewTable()

	threading := L.NewTable()
	{

	}

	// other modules boring
	{
		L.SetField(postmaketable, "os", MakeOsModule(L))
		L.SetField(postmaketable, "match", MakeMatchModule(L))
		L.SetField(postmaketable, "archive", MakeArchiveModule(L))
		L.SetField(postmaketable, "path", MakePathModule(L))
	}
	L.SetTable(postmaketable, lua.LString("workerthread"), threading)
	L.SetGlobal("postmake", postmaketable)
	defer L.Close()

	if err := DoCompiled_(L, Maincompiled); err != nil {
		panic(err)
	}
}

func MakeThreadsModule(l *lua.LState, state *Threadmoduleinfo) *lua.LTable {
	table := l.NewTable()

	l.SetField(table, "newthread", l.NewFunction(func(l *lua.LState) int {
		ch := make(chan lua.LValue)
		go newworkerthread(ch, state.Maincompiled)

		state.Threads = append(state.Threads, ch)

		l.Push(lua.LChannel(ch))
		return 1
	}))
	return table
}

# Cachex

This is some great kind of gen server. It reads state from somewhere, stores it and its serialized version to ets. Example of usage:

```
defmodule TestActor do
	use Cachex, [ttl: 700, export: true]
	defp read_callback(prev_state) do
		if (prev_state == %{999 => 999}), do: IO.puts("\nINIT\n")
		{_,s,_} = :erlang.timestamp
		val = rem(s,100)
		Map.put(%{},val,val)
	end
end
```

You SHOULD define

- &read_callback/1 function

You CAN define

- &serialize_callback/1 function , default is &Jazz.decode!/1
- ttl param of macro (timeout to call &read_callback/1) , default is 5000
- export param of macro , if false - not register process , default is true

Than you can use it for example this way (better to start on init of your application)

```
{:ok, _} = Supervisor.start_child(Cachex.Supervisor, Supervisor.Spec.worker(TestActor, [%{999 => 999}], [id: TestActor]))
```

Next, you can call 3 functions for your module TestActor

- &get/1 gets value by key from ets - cached state
- &get_all/0 gets all ets - cached state (map)
- &get_serialized/0 gets serialized ets - cached state

Run mix.test to look this example in action

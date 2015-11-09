defmodule CachexTest do
	use ExUnit.Case
	doctest Cachex

	defmodule TestActor do
		use Cachex, [ttl: 700, export: true]
		defp read_callback(prev_state) do
			if (prev_state == %{999 => 999}), do: IO.puts("\nINIT\n")
			{_,s,_} = :erlang.timestamp
			val = rem(s,100)
			Map.put(%{},val,val)
		end
	end

	@delay 333
	defp test_func do
		Enum.each(1..10, fn(_) ->
			:timer.sleep(@delay)
			val = TestActor.get_all |> IO.inspect
			TestActor.get_serialized |> IO.inspect
			[k] = Map.keys(val)
			true = (val == TestActor.get_by_pred(&(&1 == k)))
			true = (%{} == TestActor.get_by_pred(&(&1 == -1)))
			true = (k == TestActor.get(k) |> IO.inspect)
		end)
	end

	test "the truth" do
		{:ok, _} = Supervisor.start_child(Cachex.Supervisor, Supervisor.Spec.worker(TestActor, [%{999 => 999}], [id: TestActor]))
		test_func
		:erlang.whereis(TestActor) |> :erlang.exit(:kill)
		test_func
		assert 1 + 1 == 2
	end

end

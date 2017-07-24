defmodule Cachex do
	use Application
	@tab_specs [:public, :named_table, :set]
	@serialize_tab :cachex_serialized

	# See http://elixir-lang.org/docs/stable/elixir/Application.html
	# for more information on OTP Applications
	def start(_type, _args) do
		import Supervisor.Spec, warn: false
		@serialize_tab = :ets.new(@serialize_tab, @tab_specs)

		children = [
		# Define workers and child supervisors to be supervised
		# worker(Cachex.Worker, [arg1, arg2, arg3]),
		]

		# See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
		# for other strategies and supported options
		opts = [strategy: :one_for_one, name: Cachex.Supervisor]
		Supervisor.start_link(children, opts)
	end

	defmacro __using__(params) do
		ttl = params[:ttl] || 5000
		true = (is_integer(ttl) and (ttl > 0))
		start_link_body = case params[:export] do
							nil -> quote location: :keep do GenServer.start_link(__MODULE__, args, [name: __MODULE__]) end
							true -> quote location: :keep do GenServer.start_link(__MODULE__, args, [name: __MODULE__]) end
							false -> quote location: :keep do GenServer.start_link(__MODULE__, args) end
							name when is_atom(name) -> quote location: :keep do GenServer.start_link(__MODULE__, args, [name: unquote(name)]) end
						 end
		serialize_on_init = case params[:serialize_on_init] do
								true -> quote location: :keep do true = :ets.insert(unquote(@serialize_tab), {__MODULE__, serialize_callback(state)}) end
								false -> nil
								nil -> nil
							end
		quote location: :keep do

			#
			#	public
			#

			@spec get(any) :: any
			def get(k) do
				case :ets.lookup(__MODULE__, k) do
					[{^k, data}] -> data
					[] -> nil
				end
			end

			@spec get_all :: %{}
			def get_all, do: :ets.foldl(fn({k,v}, acc = %{}) -> Map.put(acc, k, v) end, %{}, __MODULE__)

			@spec get_by_pred(((any) -> boolean)) :: %{}
			def get_by_pred(pred) do
				:ets.foldl(fn({k,v}, acc = %{}) ->
					case pred.(v) do
						true -> Map.put(acc, k, v)
						false -> acc
					end
				end, %{}, __MODULE__)
			end

			@spec get_serialized :: String.t | nil
			def get_serialized do
				case :ets.lookup(unquote(@serialize_tab), __MODULE__) do
					[{__MODULE__, data}] -> data
					[] -> nil
				end
			end

			#
			#	priv
			#

			use GenServer
			@spec init(any) :: {:ok, %{}, 1}
			def init(map = %{}), do: cachex_init(map)
			def init(_), do: cachex_init(%{})
			@spec handle_info(:timeout, %{}) :: {:noreply, %{}, unquote(ttl)}
			def handle_info(:timeout, state = %{}), do: {:noreply, cachex_handle(state), unquote(ttl)}
			@spec start_link(any) :: {:ok, pid}
			def start_link(args), do: unquote(start_link_body)
			@spec start_link :: {:ok, pid}
			def start_link do
				args = %{}
				unquote(start_link_body)
			end

			@spec cachex_init(%{}) :: {:ok, %{}, 1}
			defp cachex_init(state = %{}) do
				if (:ets.info(__MODULE__) == :undefined), do: (__MODULE__ = :ets.new(__MODULE__, unquote(@tab_specs)))
				unquote(serialize_on_init)
				{:ok, state, 1}
			end
			@spec cachex_handle(%{}) :: %{}
			defp cachex_handle(state = %{}) do
				case read_callback(state) do
					^state -> state
					new_state ->
						true = :ets.insert(unquote(@serialize_tab), {__MODULE__, serialize_callback(new_state)})
						Enum.each(new_state, fn({k,v}) -> true = :ets.insert(__MODULE__, {k,v}) end)
						:ets.foldl(fn({k,_}, nil) ->
							case Map.has_key?(new_state,k) do
								true -> nil
								false ->
									true = :ets.delete(__MODULE__, k)
									nil
							end
						end, nil, __MODULE__)
						new_state
				end
			end


			# can override it
			@spec serialize_callback(%{}) :: String.t
			defp serialize_callback(state), do: Jazz.encode!(state)
			# read_callback spec , but user should write impl
			@spec read_callback(%{}) :: %{}
			defoverridable [serialize_callback: 1]


		end
	end
end

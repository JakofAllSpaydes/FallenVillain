--!strict
-- Minimal synchronous signal. Handlers run in connection order on the firing thread.

export type Connection = { Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

export type Signal<T...> = typeof(setmetatable({} :: { _handlers: { (T...) -> () } }, Signal))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, handler: (T...) -> ()): Connection
	table.insert(self._handlers, handler)
	local connection = {}
	function connection.Disconnect(_: any)
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection :: any
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	for _, handler in table.clone(self._handlers) do
		handler(...)
	end
end

return Signal

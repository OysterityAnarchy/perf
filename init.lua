local perf_data = {}

local type_old = type
function type(arg)
	if arg == nil then
		return "nil"
	else
		return type_old(arg)
	end
end

local function override_table(tbl, name, seen)
	for k, v in pairs(tbl) do
		if not seen[v] then
			seen[v] = true
			local t = type(v)
			local n = name .. tostring(k)
			if t == "function" and v ~= os.clock and v ~= unpack and v ~= mcl_enchanting.can_enchant then
				local info = debug.getinfo(v).short_src
				rawset(tbl, k, function(...)
					local tm_start = os.clock()
					local ret = {v(...)}
					local result = os.clock() - tm_start
					local data = perf_data[n] or {calls = 0, avg = 0, accum = 0}
					data.accum = data.accum + result
					data.calls = data.calls + 1
					data.avg = data.accum / data.calls
					data.info = info
					perf_data[n] = data
					return unpack(ret)
				end)
			elseif t == "table" then
				override_table(v, n .. ".", seen)
			end
		end
	end
end

minetest.register_on_mods_loaded(function()
	override_table(_G, "", {[_G] = true})
end)

minetest.register_chatcommand("perf", {
	func = function(name)
		local sorted = {}
		for name, data in pairs(perf_data) do
			table.insert(sorted, {name = name, data = data})
		end
		table.sort(sorted, function(a, b) return a.data.accum > b.data.accum end)
		minetest.chat_send_player(name, string.format("[perf] %14s\t%14s\t%14s\t%s (%s)", "accumulated", "calls", "average", "name", "source"))
		for i, func in ipairs(sorted) do
			if i > 50 then
				break
			end
			minetest.chat_send_player(name, string.format("[perf] %14f\t%14d\t%14f\t%s (%s)", func.data.accum, func.data.calls, func.data.avg, func.name, func.data.info))
		end
	end,
})

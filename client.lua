-- Put functions in this file to use them in several other scripts.
-- To get access to the functions, you need to put:
-- require "my_directory.my_file"
-- in any script using the functions.
local ColyseusClient = require "colyseus.client"
local log = require("utility.log")

local M = {}

M.player_states = { WAITING = 'waiting', ALIVE = 'alive', DEAD = 'dead' }
M.player = {state = M.player_states.WAITING}

M.game_states = { JOIN = 'join', PLAY = 'play', END = 'end'}
M.game_state = M.game_states.JOIN
-- all users of the module will share this table
M.colyseus = {
	client = nil,
	room = nil
}

function send_cbs(cb_list, cb_type, value) 
	for i, fun in ipairs(cb_list) do
		fun(cb_type, value)
	end
end

local priors = {
	state = '',
	time_s = 0
}

local simple_cbs = {
	time_s = {},
	state = {}
}
function M.subscribe_time(cb)
	local function dummy (type, value) cb(value) end
	table.insert(simple_cbs.time_s, dummy)
end

function M.subscribe_state(cb)
	local function dummy (type, value) 
		cb(value) 
		M.game_state = value 
	end
	table.insert(simple_cbs.state, dummy)
end

local init_cbs = {}
function M.subscribe_init(cb)
	local function dummy (type, value) cb() end
	table.insert(init_cbs, dummy)
end

local scoreboard_cbs = {}
function M.subscribe_scoreboard(cb)
	table.insert(scoreboard_cbs, cb)
end

local custom_cbs = {}
function M.subscribe_custom(cb)
	table.insert(custom_cbs, cb)
end

local player_cbs = {}
function M.subscribe_player(cb)
	table.insert(player_cbs, cb)
end

function M.register_cbs()
	M.colyseus.room.state["on_change"] = function(changes)
		for i, change in ipairs(changes) do
			-- if we have callbacks for the changed field, call them
			if simple_cbs[change.field] ~= nil and change.value ~= priors[change.field] then
				priors[change.field] = change.value
				send_cbs(simple_cbs[change.field], change.field, change.value)
			end
		end
	end

	M.colyseus.room.state.scoreboard['on_change'] = function(changes)
		for i, change in ipairs(changes) do
			send_cbs(scoreboard_cbs, change.field, change.value)
		end
	end

	-- M.colyseus.room.state.clientData['on_change'] = function(changes)
	-- 	for i, change in ipairs(changes) do
	-- 		send_cbs(custom_cbs, change.field, change.value)
	-- 	end
	-- end

	M.colyseus.room.state.players['on_add'] = function (_player, key)
		if key == M.colyseus.room.sessionId then
			M.player = _player
			M.player["on_change"] = function(changes) 
				for i, change in ipairs(changes) do
					send_cbs(player_cbs, change.field, change.value)
				end
			end
		end
	end
end

function M.on_message(msg, cb)
	M.colyseus.room:on_message(msg, cb)
end

function M.send(msg)
	M.colyseus.room:send(msg)
end

function M.send(msg, data)
	M.colyseus.room:send(msg, data)
end


local function start_server() 
	local info = sys.get_sys_info()
	if info.system_name == "Darwin" then
		os.execute('./defold-dev-server-mac --server=azarus/azarus.lua &')
	elseif info.system_name == "Linux" then
		os.execute('./defold-dev-server-linux --server=custom.lua &')
	elseif info.system_name == "Windows" then
		os.execute('START /B defold-dev-server-windows')	
	end
end


function M.init(cb, isDev)
	local started = false
	timer.delay(0.5, true,function(self, handle) 
		-- colyseus.client = ColyseusClient.new("wss://defold.danielcloran.com:2567")
		M.colyseus.client = ColyseusClient.new("ws://localhost:2567")

		local streamer = sys.get_config("streamer") or "error_streamer"
		M.colyseus.client:join_or_create("game", { streamId=streamer }, function(err, _room)
			if err then
				print("AZA INIT ERROR: " .. err)
				if not started then
					started = true
					return start_server()
				end
				return
			end
			timer.cancel(handle)
			M.colyseus.room = _room
			M.register_cbs()
			send_cbs(init_cbs, '', '')	

			return cb(true)
		end)
	end)
end

function M.close() 
	-- shutdown the development server
	local info = sys.get_sys_info()
	if info.system_name == "Darwin" then
		os.execute('killall defold-dev-server-mac')
	elseif info.system_name == "Linux" then
		os.execute('killall defold-dev-server-linux')
	elseif info.system_name == "Windows" then
		os.execute('taskkill defold-dev-server-windows')
	end
end

return M
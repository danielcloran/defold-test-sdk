local helpers = require 'lua.helpers'

M = {}

local pipe_max_y = 250;
local pipe_min_y = 130;

math.randomseed(os.time())
local function generate_random_y()
	return math.random(pipe_min_y, pipe_max_y)
end

-- when the game server is created
function M.on_create()
	local pipe_y = {}
	for i = 1, 25 do
		pipe_y[i] = generate_random_y()
	end
	helpers.broadcast('pipes', pipe_y)
end

-- when the game server recieves 'start' from the streamer
function M.on_start()
	print('started!')
end

-- when a player dies or becomes inactive
function M.on_death()
	print('player died')
end

-- every frame (use sparingly)
function M.on_update()
end

-- when the game server closes
function M.on_end()
end

-- any non-reserved message from any client
function M.on_message(msg, data)
	print("on_message")
end

return M
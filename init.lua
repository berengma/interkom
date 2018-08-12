-- New and freshly presented by Gundul: Lilly - Jungle Interkom

interkom = {}

local path = minetest.get_modpath(minetest.get_current_modname())
local wpath = minetest.get_worldpath().."/Lilly"

-- Textcolors
local green = '#00FF00'
local red = '#FF0000'
local orange = '#FF6700'


dofile(path.."/settings.lua")



-- checks if file is available
function interkom.file_exists(file)
      local f = io.open(file, "r")
	  if f then f:close() end
      return f ~= nil
end




-- read a File  line by line
function interkom.readlines(file)
	
	if not interkom.file_exists(file) then 
	    minetest.chat_send_all("File does not exist")
	    return {}
	end
	
	local lines = {}
	
	for line in io.lines(file) do 
	  lines[#lines + 1] = line
	end
	return lines
end


-- delete line with "data" from file fname
function interkom.delete(fname,data)
	      local input = interkom.readlines(fname)
	      local f = io.open(fname, "w")
	      for i in pairs(input) do
		  if input[i] ~= data then
		      f:write(input[i].."\n")
		  end
	      end
	      f:close()
end


function interkom.server(modus)
	local fname = wpath.."/Servers"
	
	if modus then
	
	      local f = io.open(fname, "a")
	      f:write(interkom.name.."\n")
	      f:close()
	else
	  
	  interkom.delete(fname,interkom.name)
	end
		  
end


-- 
minetest.register_chatcommand("interkom", {
	params = "",
	description = "Show Servername and connected servers",
	privs = {interact = true},
	func = function(name)

		
		if interkom.name then
		  
		  minetest.chat_send_player(name,core.colorize(green,"*** interkom loaded. This server is : ")..core.colorize(orange,interkom.name).."\n\n")
		  
		  local file = wpath.."/Servers"

		  local lines = interkom.readlines(file)

		  -- print all line numbers and their contents
		  
		  for k,v in pairs(lines) do
		    minetest.chat_send_player(name,core.colorize(green,'Connected Server' .. k .. ': ')..core.colorize(orange,lines[k]))
		    minetest.chat_send_player(name,core.colorize(green,"         Players:"))
		    local pnames = interkom.readlines(wpath.."/"..interkom.name..".players")
		    for l in pairs(pnames) do
			minetest.chat_send_player(name,core.colorize(red,"                       "..pnames[l]))
		    end
		  end
		  
		 
		else
		  
		  minetest.chat_send_player(name,core.colorize(red,"Check your config file, no servername set. Interkom NOT loaded !"))
    
		end

	end,
})

minetest.register_on_joinplayer(function(player)
	  local fname = wpath.."/"..interkom.name..".players"
	  local f = io.open(fname, "a")
	      f:write(player:get_player_name().."\n")
	      f:close()
end)


minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	local fname = wpath.."/"..interkom.name..".players"
	interkom.delete(fname,pname)	
end)


-- delete Server from list when it shutdowns 
minetest.register_on_shutdown(function()
    interkom.server(false)
    os.remove(wpath.."/"..interkom.name..".players")
end)
    
-- add Server to list on startup
interkom.server(true)


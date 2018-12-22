-- New and freshly presented by Gundul: Lilly - Jungle Interkom

interkom = {}

local path = minetest.get_modpath(minetest.get_current_modname())
local wpath = minetest.get_worldpath().."/Lilly"
local timer = 0
local ctime = interkom.intervall or 5



-- Textcolors
local green = '#00FF00'
local red = '#FF0000'
local orange = '#FF6700'


dofile(path.."/settings.lua")


-- global step for server action queue
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= ctime then
		if interkom.name then
		    local aktion = interkom.readlines(wpath.."/"..interkom.name..".action")
		    if aktion and aktion ~= {} then
			for i in pairs(aktion) do
			    interkom.command(aktion[i])
			    interkom.delete(wpath.."/"..interkom.name..".action",aktion[i])
			end
		    end
		timer = 0
		end
	end
end)


-- string split function
function interkom.split(inputstr, sep)
	
        if not sep then sep = "," end
        
        local t={} 
	local i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
	
        return t
end



-- checks if file is available
function interkom.file_exists(file)
      local f = io.open(file, "r")
	  if f then f:close() end
      return f ~= nil
end




-- read a File  line by line
function interkom.readlines(file)
	
	if not interkom.file_exists(file) then 
	    --minetest.chat_send_all("File does not exist")
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


-- register/unregister server with name from settings.lua
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


-- function checks if a certain player is online
function interkom.playeronline(name,server)
	  local pnames = interkom.readlines(wpath.."/"..server..".players")
	  
	  for l in pairs(pnames) do
			if pnames[l] == name then return true end
	  end
		
	  return false
end


-- function checks if a certain server is online
function interkom.serveronline(server)
	  local snames = interkom.readlines(wpath.."/Servers")
	  
	  for l in pairs(snames) do
			if snames[l] == server then return true end
	  end
		
	  return false
end


-- function to save servers actionqueue
function interkom.saveAC(server,code)
    	  local fname = wpath.."/"..server..".action"
	  local f = io.open(fname, "a")
	      f:write(code.."\n")
	      f:close()
end


--function executing commands in actionqueue
function interkom.command(code)
      local perintah = interkom.split(code)
      minetest.log("action","[Interkom] "..code)
      
      if perintah[1] == "MSG" then
	
	    -- this checks for komma in message and revokes splitting
	    local message = ""
	    local i = 5    
	    while perintah[i] do
	      if i == 5 then
		    message = message..perintah[i]
	      else
		    message = message..","..perintah[i]
	      end
	      i = i + 1
	    end
	    
	minetest.chat_send_player(perintah[4],core.colorize(green,perintah[2].."@"..perintah[3]..": ")..core.colorize(orange,message))
      
      elseif perintah[1] == "GIV" then
	local stack = ItemStack(perintah[5])
	if stack:is_known() then
	      minetest.chat_send_player(perintah[4],core.colorize(green,perintah[2].."@"..perintah[3].." send you ")..core.colorize(orange,perintah[5]))
	      interkom.checkstuff(perintah[4],perintah[5],false)
	else
	      minetest.chat_send_player(perintah[4],core.colorize(red,">>> CUSTOMS REJECTED: ")..core.colorize(orange,perintah[5])..core.colorize(green," from "..perintah[2].."@"..perintah[3]))
	      interkom.saveAC(perintah[3],"GIV,"..interkom.name.."-Customs,"..interkom.name..","..perintah[2]..","..perintah[5])
	      interkom.saveAC(perintah[3],"MSG,"..interkom.name.."-Customs,"..interkom.name..","..perintah[2]..",".."Your stuff was rejected")
	end
      
      elseif perintah[1] == "KIK" then
	minetest.kick_player(perintah[4],perintah[5])
      
      else
	  minetest.chat_send_all(core.colorize(red,"<<unknown command in ActionQueue>>"..dump(perintah)))
      end
      
end


-- function to check if stuff is in inventory and valid
function interkom.checkstuff(name,message,remove)
      local player = minetest.get_player_by_name(name)
      if not player then return false end
      local inv = player:get_inventory()
	if remove then
	    if inv:contains_item("main",message) then
		inv:remove_item("main",message)
		return true
	    end
	else
	  if inv:room_for_item("main",message) then
	    inv:add_item("main",message)
	    return true
	  else
	    local pos = player:get_pos()
	    minetest.spawn_item(pos, message)
	    minetest.chat_send_player(name,core.colorize(orange,"Inventory full, Items(s) dropped at your position"))
	    return true
	  end
	end
      return false
end


-- new chatcommand for private messages between servers
minetest.register_chatcommand("pm", {
      params ="<name,server,message>",
      description = "Send a private message to player on other server",
      privs = {interact = true},
	func = function(name,text)
	    local cmd = interkom.split(text)
	    local pname = cmd[1]
	    local sname = cmd[2]
	    local message = ""
	    local i = 3
	    
	    while cmd[i] do
	      if i == 3 then
		    message = message..cmd[i]
	      else
		    message = message..","..cmd[i]
	      end
	      i = i + 1
	    end
	    
	    if pname and sname and message then
		
		if  not interkom.serveronline(sname) then
		    minetest.chat_send_player(name,core.colorize(red,"Server "..sname.." ist not online at the moment"))    
		else
		    if not interkom.playeronline(pname,sname) then
			minetest.chat_send_player(name,core.colorize(red,"Player "..pname.."@"..sname.." is not online at the moment"))
		    else
		      --do this and that
		      interkom.saveAC(sname,"MSG,"..name..","..interkom.name..","..pname..","..message)
		      minetest.chat_send_player(name,core.colorize(green,">> Message send to: ")..core.colorize(orange,pname.."@"..sname))
		    end
		end
	    else
		minetest.chat_send_player(name,core.colorize(red,"Syntax error!  please use </pm playername,server,message>"))
	    end
	    
	
end,
})

 -- new chatcommand for sending stuff between servers
minetest.register_chatcommand("stuff", {
      params ="<name,server,stuff>",
      description = "Send your stuff to a player on an other server",
      privs = {interact = true},
	func = function(name,text)
	    local cmd = interkom.split(text)
	    local pname = cmd[1]
	    local sname = cmd[2]
	    local message = cmd[3]
	    
	    if pname and sname and message then
	      local supported = string.match(message,":")
	      
		  -- check for unusual stacksizes
		  local stack = ItemStack(message)
		  if stack:get_count() > stack:get_stack_max() then
		      stack:set_count(stack:get_stack_max())
		      message = stack:to_string()
		  end
	     	      
		
		if  not interkom.serveronline(sname) then
		    minetest.chat_send_player(name,core.colorize(red,"Server "..sname.." ist not online at the moment"))    
		else
		    if not interkom.playeronline(pname,sname) then
			minetest.chat_send_player(name,core.colorize(red,"Player "..pname.."@"..sname.." is not online at the moment"))
		    else
		      if interkom.checkstuff(name,message,true)  and supported then
			  --do this and that
			  interkom.saveAC(sname,"GIV,"..name..","..interkom.name..","..pname..","..message)
			  minetest.chat_send_player(name,core.colorize(green,">> Stuff send to: ")..core.colorize(orange,pname.."@"..sname))
		      else
			if supported then
			  minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(green,"You do not own ")..core.colorize(orange,message))
			else
			  minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(orange,"> "..message.." <")..core.colorize(green," -- Enter stackname like modname:name  (example: default:stone)"))
			end
		      end
			
		    end
		end
	    else
	    
		minetest.chat_send_player(name,core.colorize(red,"Syntax error!  please use </stuff playername,server,stuff>"))
	      
	    end
	    
	
end,
})     

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
		    local pnames = interkom.readlines(wpath.."/"..lines[k]..".players")
		    for l in pairs(pnames) do
			minetest.chat_send_player(name,core.colorize(red,"                       "..pnames[l]))
		    end
		    pnames = {}
		    minetest.chat_send_player(name,"\n\n")
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
--
-- on_shutdown is not called when server crashes !
if interkom.serveronline(interkom.name) then
    interkom.server(false)
    os.remove(wpath.."/"..interkom.name..".players")
end

interkom.server(true)


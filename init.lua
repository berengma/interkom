--##################################################
-- New and freshly presented by Gundul: Interkom   
-- Communication and stuff exchange between servers
--##################################################


interkom = {}

local storage = minetest.get_mod_storage()
interkom.whitelist = {}
interkom.tempcheck = {}
interkom.playerselect = {}
interkom.serverselect = {}

local path = minetest.get_modpath(minetest.get_current_modname())
local wpath = minetest.get_worldpath().."/Lilly"
local timer = 0
local ctime = interkom.intervall or 5
local blwait = interkom.blacklistTO or 60




-- Textcolors
local green = '#00FF00'
local red = '#FF0000'
local orange = '#FF6700'
local formcolor = '#000000'


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


-- load whitelist from file
function interkom.open()

	local load = storage:to_table()
	interkom.whitelist = load.fields

end 


-- save whitelist to file
function interkom.save()

	storage:from_table({fields=interkom.whitelist})
	
end 



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


-- function to show trading gui
function interkom.gui(playername,selected_server,player)
	local file = wpath.."/Servers"
	local lines,liststr = interkom.readlines(file)
	local playerlist = ""
	local plines = {}
	
	if not selected_server then 
		selected_server = lines[1] 
		interkom.serverselect[playername] = lines[1]
	end
	
	if interkom.serveronline(selected_server) then
		local file = wpath.."/"..selected_server..".players"
		plines,playerlist = interkom.readlines(file)
	end
	

	minetest.show_formspec(playername, "interkom:tradegui",
	"size[8,8.5;]"..
	"label[0,-0.1;"..core.colorize(orange,"Connected Servers").."]"..
	"label[5.3,-0.1;"..core.colorize(orange,"Connected Players").."]"..
	"textlist[0,0.3;2.5,3;selected_server;"..liststr..";selected;false]"..
	"list[current_player;main;0,4.5;8,4;]"..
	"button[3,2.5;2,0.5;send;Send]"..
	"button_exit[3,3.5;2,0.5;exit;Close]"..
	"list[detached:"..playername.."_interkom;myinterkom;3,0;2,2;]"..
	"textlist[5.3,0.3;2.5,3;selected_player;"..playerlist..";selectedpl;false]"
	)
end


-- formspec interpretation
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "interkom:tradegui" and player then -- The form name and player must be online
		local file = wpath.."/Servers"
		local lines,liststr = interkom.readlines(file)
		local playerlist = ""
		local plines = {}
		local myname = player:get_player_name()
		local event = minetest.explode_textlist_event(fields.name)  -- get values of what was clicked
		
		--minetest.chat_send_all(dump(fields))
		
		    
		-- button close is pressed
		if fields.exit or fields.quit then
			local inv = minetest.get_inventory({type="detached", name=myname.."_interkom" })
			local pinv = player:get_inventory()
			for sec = 1,5,1 do
				for j = 1,4,1 do
					local stack = inv:get_stack("myinterkom", j)
					local pstack = inv:remove_item("myinterkom",stack)
					pinv:add_item("main", pstack)
				end
			end
			
			return false
		end
		
		-- button Send is pressed
		if fields.send then
			if not interkom.playerselect[myname] or not interkom.serverselect[myname] then 
				minetest.chat_send_player(myname,core.colorize(red,"ERROR: ")..core.colorize(green," No player and/or server selected"))
				return false 
			end
			local inv = minetest.get_inventory({type="detached", name=myname.."_interkom" })
			
			for sec = 1,5,1 do
			for i = 1,4,1 do
				local stack = inv:get_stack("myinterkom", i)
				local meta = minetest.deserialize(stack:get_metadata()) or nil
				local stackname = stack:get_name().." "..stack:get_count()
				if stackname ~= " 0" and not meta then
					if interkom.send_stuff(myname,interkom.playerselect[myname],interkom.serverselect[myname],stackname) then
						inv:remove_item("myinterkom",stackname)
					end
				end
			end
			end
		return false
		end
		
		-- select server from the list
		if fields.selected_server then
			local server = interkom.split(fields.selected_server,":")
			if not server then return end
			if server[1] == "CHG" then
				local num = tonumber(server[2])
				interkom.serverselect[myname] = lines[num]
				interkom.gui(myname,lines[num],player)
			end
		end
		
		-- select player from the list
		if fields.selected_player then
			local player = interkom.split(fields.selected_player,":")
			if not player then return end
			if interkom.serverselect[myname] then
				file = wpath.."/"..interkom.serverselect[myname]..".players"
				plines,playerlist = interkom.readlines(file)
			end
		
			if player[1] == "CHG" then
				local num = tonumber(player[2])
				interkom.playerselect[myname] = plines[num]
				interkom.gui(myname,interkom.serverselect[myname],plines[num])
			end
		end
	end
end)


-- function to send stuff
function interkom.send_stuff(name,pname,sname,message)
	
	    if pname and sname and message then
	      local supported = true
	      
		  -- check for unusual stacksizes
		  local stack = ItemStack(message)
		  local tool = false
		  if stack:get_stack_max() == 1 then tool = true end
		  if stack:get_count() > stack:get_stack_max() then
		      stack:set_count(stack:get_stack_max())
		      message = stack:to_string()
		  end
		  
		  --check valid stacknames
		if stack:get_name() == "" then supported = false end
		
		if  not interkom.serveronline(sname) then
		    minetest.chat_send_player(name,core.colorize(red,"Server "..sname.." ist not online at the moment"))
		    return false
		else
		    if not interkom.playeronline(pname,sname) then
			minetest.chat_send_player(name,core.colorize(red,"Player "..pname.."@"..sname.." is not online at the moment"))
			return false
			
		    else
				if supported and not tool then
				interkom.saveAC(sname,"GIV,"..name..","..interkom.name..","..pname..","..message)
				minetest.chat_send_player(name,core.colorize(green,">> Stuff send to: ")..core.colorize(orange,pname.."@"..sname))
				return true
				else
					if supported and not tool then
					minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(green,"You do not have (or contains  meta) ")..core.colorize(orange,message))
					return false
					else
						if not tool then
						minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(orange,"> "..message.." <")..core.colorize(green," -- Enter stackname like modname:name # (example: default:stone 25)"))
						return false
						else
							minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(green,"You can not send tools"))
							return false
						end
					end
				end
		    end
		end
	    end
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
	local liststr = ""
	
	
	for line in io.lines(file) do
		lines[#lines + 1] = line
		if #lines > 1 then
			liststr = liststr..","..line
		else
			liststr = liststr..line
		end
	end
	return lines,liststr
end


-- delete line with "data" from file fname
function interkom.delete(fname,data)
	      local input = interkom.readlines(fname)
	      
	      for i in pairs(input) do
		  if input[i] == data then
		      table.remove(input,i)
		  end
	      end
	      minetest.safe_file_write(fname,  table.concat(input, "\n"))
end


-- register/unregister server with name from settings.lua
function interkom.server(modus)
	local fname = wpath.."/Servers"
	
	if modus then
	
	      local input = interkom.readlines(fname)
	      table.insert(input,interkom.name.."\n")
	      minetest.safe_file_write(fname, table.concat(input, "\n"))
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
	  local input = interkom.readlines(fname)
	      table.insert(input,code.."\n")
	      minetest.safe_file_write(fname, table.concat(input, "\n"))
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
	  local checkhere = minetest.encode_base64(perintah[4]..perintah[2]..perintah[3])
	  if interkom.whitelist[checkhere] then
	      minetest.chat_send_player(perintah[4],core.colorize(orange,perintah[2].."@"..perintah[3])..core.colorize(green," send you ")..core.colorize(orange,perintah[5]))
	      interkom.checkstuff(perintah[4],perintah[5],false)
	  else
	      local name = perintah[4]
	      minetest.chat_send_player(perintah[4],core.colorize(orange,perintah[2].."@"..perintah[3])..core.colorize(green," wants to send you ")..core.colorize(orange,perintah[5]))
	      minetest.chat_send_player(perintah[4],core.colorize(green,"You have ")..core.colorize(orange,blwait)..core.colorize(green," seconds to enter ")..core.colorize(orange,"/ok")..core.colorize(green," to accept and to whitelist ")..core.colorize(orange,perintah[2].."@"..perintah[3]))
	      interkom.tempcheck[perintah[4]]={sender = perintah[2],server = perintah[3],stuff = perintah[5]}
	      minetest.after(blwait, function(name)
	      if interkom.tempcheck[name] then
			interkom.tempcheck[name] = nil
		end
	      end, name)
	  end
	      interkom.saveAC(perintah[3],"MSG,".."Customs,"..interkom.name..","..perintah[2]..",".." >OK<")
	else
	      minetest.chat_send_player(perintah[4],core.colorize(red,">>> CUSTOMS REJECTED: ")..core.colorize(orange,perintah[5])..core.colorize(green," from "..perintah[2].."@"..perintah[3]))
	      interkom.saveAC(perintah[3],"GIV,".."Customs,"..interkom.name..","..perintah[2]..","..perintah[5])
	      interkom.saveAC(perintah[3],"MSG,".."Customs,"..interkom.name..","..perintah[2]..",".."Stuff >REJECTED<")
	end
      
      elseif perintah[1] == "KIK" then
	minetest.kick_player(perintah[4],perintah[5])
      
      else
	  minetest.chat_send_all(core.colorize(red,"<<unknown command in ActionQueue>>"..dump(perintah)))
      end
      
end


-- function to check if stuff is in inventory and valid
function interkom.checkstuff(name,message,remove,gui)
      local player = minetest.get_player_by_name(name)
      if not player then return false end
      local inv = player:get_inventory()
	if remove then
	    if inv:contains_item("main",message) then
		local cstack = inv:remove_item("main",message)
		local meta = minetest.deserialize(cstack:get_metadata()) or nil
		if meta then
		    inv:add_item("main",cstack)
		    return false
		else
		    return true
		end
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
	    if name then 
		    interkom.gui(name,interkom.serverselect[name],interkom.playerselect[name])
		    return
	    end
	    
	    if pname and sname and message then
	      local supported = string.match(message,":")
	      
		  -- check for unusual stacksizes
		  local stack = ItemStack(message)
		  local tool = false
		  if stack:get_stack_max() == 1 then tool = true end
		  if stack:get_count() > stack:get_stack_max() then
		      stack:set_count(stack:get_stack_max())
		      message = stack:to_string()
		  end
		  
		  --check valid stacknames
		  if stack:get_name() == "" then supported = false end
		
		if  not interkom.serveronline(sname) then
		    minetest.chat_send_player(name,core.colorize(red,"Server "..sname.." ist not online at the moment"))    
		else
		    if not interkom.playeronline(pname,sname) then
			minetest.chat_send_player(name,core.colorize(red,"Player "..pname.."@"..sname.." is not online at the moment"))
		    else
		      if interkom.checkstuff(name,message,true)  and supported and not tool then
			  interkom.saveAC(sname,"GIV,"..name..","..interkom.name..","..pname..","..message)
			  minetest.chat_send_player(name,core.colorize(green,">> Stuff send to: ")..core.colorize(orange,pname.."@"..sname))
		      else
			if supported and not tool then
			  minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(green,"You do not have (or contains  meta) ")..core.colorize(orange,message))
			else
			  if not tool then
			      minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(orange,"> "..message.." <")..core.colorize(green," -- Enter stackname like modname:name # (example: default:stone 25)"))
			  else
			      minetest.chat_send_player(name,core.colorize(red,">> ERROR: ")..core.colorize(green,"You can not send tools"))
			  end
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


-- chatcommand to accept and whitelist other players stuff
minetest.register_chatcommand("ok", {
	  params = "",
	  description = "Accepts stuff and whitelists sending player",
	  privs = {interact = true},
	  func = function(name)
	  
		if interkom.tempcheck[name] then 
		      local sender = interkom.tempcheck[name].sender
		      local server = interkom.tempcheck[name].server
		      local stuff = interkom.tempcheck[name].stuff
		      local checkhere = minetest.encode_base64(name..sender..server)
		      interkom.checkstuff(name,stuff,false)
		      minetest.chat_send_player(name,core.colorize(green,"## ACCEPTED ")..core.colorize(orange,sender.."@"..server)..core.colorize(green," added to whitelist"))
		      interkom.whitelist[checkhere] = "1"
		      interkom.tempcheck[name] = nil
		      interkom.save()
		else
		      minetest.chat_send_player(name,core.colorize(orange,"## nothing to do ##"))
		end
end,
})


-- chatcommand to blacklist players from sending stuff
minetest.register_chatcommand("bl", {
	  params = "<playername>@<servername>",
	  description = "added to blacklist, cannot send stuff to you anymore without asking",
	  privs = {interact = true},
	  func = function(name,arg)
	      if arg then
		  local cmd = interkom.split(arg,"@")
		  if #cmd > 1 then
		      local checkhere = minetest.encode_base64(name..cmd[1]..cmd[2])
		      if interkom.whitelist[checkhere] then
			 interkom.whitelist[checkhere] = nil
			 minetest.chat_send_player(name, core.colorize(green,">>> "..cmd[1].."@"..cmd[2].." blacklisted !"))
			 interkom.save()
		      else
			 minetest.chat_send_player(name, core.colorize(orange,">>> "..cmd[1].."@"..cmd[2].." unknown !"))
		      end
		  else
		      minetest.chat_send_player(name,core.colorize(orange,"## Syntax Error, use /bl playername@servername"))
		  end
	      end
end,
})
		
	  
	  
	  
minetest.register_on_joinplayer(function(player)
	local fname = wpath.."/"..interkom.name..".players"
	local input = interkom.readlines(fname)
	table.insert(input,player:get_player_name().."\n")
	minetest.safe_file_write(fname, table.concat(input, "\n"))
	-- new inventory for sending stuff
	local inv = minetest.create_detached_inventory(player:get_player_name().."_interkom", {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
					return 1024
		end,
		allow_put = function(inv, listname, index, stack, player) 
					return 1024
		end,
		allow_take = function(inv, listname, index, stack, player) 
					return 1024
		end,
		})
	inv:set_size("myinterkom",4)
		 
end)


minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	local fname = wpath.."/"..interkom.name..".players"
	interkom.delete(fname,pname)	
end)


-- delete Server from list when it shutdowns 
minetest.register_on_shutdown(function()
    interkom.save()
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


-- start mod by registering server
interkom.server(true)
interkom.open()


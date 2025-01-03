
if modules.chatcommands == nil then
  return
end

if modules.chat == nil then
  return
end

log(DEBUG, "setting up tests")

---Expect success
modules.chatcommands:registerChatCommand("test0", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  log(1, "Buying bread")
  modules.protocol:invokeProtocol(0x26, 0, 10)

  return false
end)

local test1 = {

  -- This is called when a user initiates the protocol (with a queueProtocol(protocolNumber) call)
  -- The protocol designer is responsible for storing the to-be-send data somewhere in memory
  scheduleForSend = function(self, meta)
    
    -- For example, assume you want to implement that sleep can be toggled per building (instead of per building type)
    -- meta.parameters:writeInteger(core.readInteger(PLACE_WHERE_BUILDING_ID_IS_STORED))
    -- meta.parameters:writeInteger(core.readInteger(PLACE_WHERE_BUILDING_SLEEP_STATE_IS_STORED))

  end,

  -- This is called when a command is received in multiplayer.
  -- There is nothing to be done here actually. But hey, the programmers wrote it anyway...
  scheduleAfterReceive = function(self, meta)
    
  end,

  -- This is called when the command should be executed (committed to the game state)
  -- There is an example Lockstep protocol, meaning the execute() commits something to game state that should be synchronised across machines (executed simultaenously across machines)
  -- This is synchronised in game match time across machines in case of a Lockstep protocol. 
  -- In case of a IMMEDIATE protocol, which is meant for lobby, chat, and UI operations (meta communication),
  -- execute is executed immediately on each machine
  execute = function(self, meta)
    -- todo, insert config hash...
    log(1, "Buying bread")
    modules.protocol:invokeProtocol(0x26, 0, 10)
  end,

}

---Expect failure
local test1ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test1", "IMMEDIATE", 32, test1)
modules.chatcommands:registerChatCommand("test1", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  modules.protocol:invokeProtocol(test1ProtocolNumber)

  return false
end)

local test2 = {

  scheduleForSend = function(self, meta) end,

  scheduleAfterReceive = function(self, meta)
    
  end,

  execute = function(self, meta)
    log(1, "Sending chat")
    modules.chat:sendChatMessage("hello world!", {1, 2, 3, 4, 5, 6, 7, 8})
  end,

}

---Expect success
local test2ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test2", "IMMEDIATE", 32, test2)
modules.chatcommands:registerChatCommand("test2", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does


  modules.protocol:invokeProtocol(test2ProtocolNumber)

  return false
end)



local test3 = {

  scheduleForSend = function(self, meta) end,

  scheduleAfterReceive = function(self, meta)
    
  end,

  execute = function(self, meta)
    log(1, "Sending chat")
    modules.chat:fireChatEvent("hello world!", 0)
  end,

}

---Expect success
local test3ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test3", "LOCKSTEP", 32, test3)
modules.chatcommands:registerChatCommand("test3", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  modules.protocol:invokeProtocol(test3ProtocolNumber)

  return false
end)

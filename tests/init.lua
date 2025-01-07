
if modules.chatcommands == nil then
  log(1, string.format("Cannot execute tests as module chatcommands isn't loaded"))
  return
end

if modules.chat == nil then
  log(1, string.format("Cannot execute tests as module chat isn't loaded"))
  return
end

log(DEBUG, "setting up tests")

---@type chatcommands
local chatcommands = modules.chatcommands

---Expect success
chatcommands:registerChatCommand("test0", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  log(1, "Buying bread")
  modules.protocol:invokeProtocol(0x26, 0, 10)

  return false
end)

---@type Handler
local test1 = {

  -- This is called when a user initiates the protocol (with a queueProtocol(protocolNumber) call)
  -- The protocol designer is responsible for storing the to-be-send data somewhere in memory
  schedule = function(self, meta)
    
    
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
chatcommands:registerChatCommand("test1", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  modules.protocol:invokeProtocol(test1ProtocolNumber)

  return false
end)

local test2 = {

  schedule = function(self, meta) end,

  scheduleAfterReceive = function(self, meta)
    
  end,

  execute = function(self, meta)
    log(1, "Sending chat")
    modules.chat:sendChatMessage("hello world!", {1, 2, 3, 4, 5, 6, 7, 8})
  end,

}

---Expect success
local test2ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test2", "IMMEDIATE", 32, test2)
chatcommands:registerChatCommand("test2", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does


  modules.protocol:invokeProtocol(test2ProtocolNumber)

  return false
end)



local test3 = {

  schedule = function(self, meta) end,

  scheduleAfterReceive = function(self, meta)
    
  end,

  execute = function(self, meta)
    log(1, "Sending chat")
    modules.chat:fireChatEvent("hello world!", 0)
  end,

}

---Expect success
local test3ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test3", "LOCKSTEP", 32, test3)
chatcommands:registerChatCommand("test3", function(command)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does

  modules.protocol:invokeProtocol(test3ProtocolNumber)

  return false
end)

---Simple class defining what context is given
---@class MyContext
---@field delayToApply number The delay to apply

---@type Handler
local test4 = {

  ---@param meta CommandMetaInformation
  ---@param context MyContext
  schedule = function(self, meta, context)
    local time = core.readInteger(meta.timeAddress)
    local newTime = time + context.delayToApply

    log(1, string.format("test4: schedule: moving scheduled time from %s to %s", time, newTime))
    -- You are not really supposed to do this but for showcasing the mechanics it is nice
    core.writeInteger(meta.timeAddress, newTime)

    meta.parameters:serializeInteger(time)
    meta.parameters:serializeInteger(newTime)
  end,

  scheduleAfterReceive = function(self, meta)
    log(1, string.format("test4: scheduleAfterReceive"))
  end,

  execute = function(self, meta)
    local time = meta.parameters:deserializeInteger()
    local newTime = meta.parameters:deserializeInteger()
    local msg = string.format("test4: execute: %s => %s at ", time, newTime)
    log(1, msg)
    modules.chat:fireChatEvent(msg, 0)
  end,

}

local parser = chatcommands:argparser("/test4")
local delayCommand = parser:command("delay")
delayCommand:argument("ticks", "Ticks to delay", 0, tonumber)

---Expect success
local test4ProtocolNumber = modules.protocol:registerCustomProtocol("protocol", "test4", "LOCKSTEP", 32, test4)
chatcommands:registerChatCommand("test4", function(args)
  -- If you want to set up your data gathering before sending the command, do it here and now just like the game does
  local success, args = parser:parse(args)
  log(2, string.format("parsed args status: %s", success))
  
  if not success then
    local errorObj = args
    return false, {errorObj.message, errorObj.usage}
  end

  modules.protocol:invokeProtocol(test4ProtocolNumber, {
    delayToApply = args.ticks,
  })

  return false
end)

--Overriding here as commands have a bit of an ugly default display
local parserTest5 = chatcommands:argparser("/test5")-- :usage("/test5 delay <ticks>")
local delayCommand5 = parserTest5:command("delay")
delayCommand5:argument("ticks", "Ticks to delay", 0, tonumber)

chatcommands:registerChatCommand(parserTest5, function(args)

  modules.protocol:invokeProtocol(test4ProtocolNumber, {
    delayToApply = args.ticks,
  })

  return false
end)

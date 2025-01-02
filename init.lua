
-- commandCategory of the current command is in EDX
-- preserve EDX
-- make sure the replaced code is reinserted after the hook code
local scheduleCommandHook1Location = core.AOBScan("8B ? ? ? ? ? ? FF D0 8B ? ? ? ? ? 8B 54 24 20")
local scheduleCommandHook1Size = 7

-- commandCategory of the current command is in EAX
-- preserve EAX
-- make sure the replaced code is reinserted after the hook code
local scheduleCommandHook2Location = core.AOBScan("8B ? ? ? ? ? ? FF D1 8B ? ? ? ? ? 52 8B CE E8 ? ? ? ? 5F")
local scheduleCommandHook2Size = 7

-- commandCategory of the current command is in EAX
-- preserve EAX
-- make sure the replaced code is reinserted after the hook code
local sendLongerDataHookLocation = core.AOBScan("8B ? ? ? ? ? ? FF D1 89 ? ? ? ? ?")
local sendLongerDataHookSize = 7

-- commandCategory of the current command is in EDX
-- preserve EDX
-- make sure the replaced code is reinserted after the hook code
local processWaitingCommandsHookLocation = core.AOBScan("8B ? ? ? ? ? ? FF D0 8B ? ? ? ? ? 69 ? ? ? ? ? 83 C5 01")
local processWaitingCommandsHookSize = 7

-- commandCategory of the current command is in ECX
-- preserve ECX
-- make sure the replaced code is reinserted after the hook code
local queueCommandHook1Location = core.AOBScan("8B ? ? ? ? ? ? FF D2 8B ? ? ? ? ? 69 ? ? ? ? ?")
local queueCommandHook1Size = 7

-- commandCategory of the current command is in EDX
-- preserve EDX
-- make sure the replaced code is reinserted after the hook code
local queueCommandHook2Location = core.AOBScan("8B ? ? ? ? ? ? FF D0 8B ? ? ? ? ? 51")
local queueCommandHook2Size = 7

-- Crusader Extreme commands are longer I believe
local TOTAL_GAME_COMMAND_SIZE = 1272

-- byte value, max is 127. 125 and 126 are already taken. Not sure about 121.
local LAST_ORIGINAL_NUMBER = 120 -- Actually 120 is illegal value
local CUSTOM_PROTOCOL_NUMBER1 = LAST_ORIGINAL_NUMBER + 1
local CUSTOM_PROTOCOL_NUMBER2 = CUSTOM_PROTOCOL_NUMBER1 + 1
local FIRST_AVAILABLE_NUMBER = CUSTOM_PROTOCOL_NUMBER2 + 1 + 7 -- reserve an extra 7 for internal use

-- ECX value for most multiplayer functionality (command functionality)
local MULTIPLAYER_HANDLER_ADDRESS = core.readInteger(core.AOBScan("B9 ? ? ? ? E8 ? ? ? ? 39 ? ? ? ? ? 75 17") + 1)

local CURRENT_PLAYER_SLOT_ID_ADDRESS = core.readInteger(core.AOBScan("3B ? ? ? ? ? 75 1C 8B ? ? ? ? ?") + 2)
local MATCH_TIME_ADDRESS = core.readInteger(core.AOBScan("3B ? ? ? ? ? 75 1C 8B ? ? ? ? ?") + 6 + 2 + 2)

local COMMAND_PARAMETER_SIZE_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(core.AOBScan("8B ? ? ? ? ? 8D ? ? ? ? ? 51 52 50") + 2)
local COMMAND_FIXED_PARAMETER_LOCATION_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(core.AOBScan("8B ? ? ? ? ? 8D ? ? ? ? ? 51 52 50") + 6 + 2)

local COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(core.AOBScan("8D ? ? ? ? ? 52 8B 13") + 2)

local COMMAND_CURRENT_ID_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(core.AOBScan("8B ? ? ? ? ? 69 ? ? ? ? ? 8B ? ? ? ? ? ? 8D 3C 31") + 2)

local COMMAND_ARRAY_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(core.AOBScan("89 ? ? ? ? ? ? 8B ? ? ? ? ? 69 ? ? ? ? ? 89 ? ? ? ? ? C7 ? ? ? ? ? ? ? ? ?") + 3)

local niceCommandInfo = core.AOBScan("89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 0F ? ? ? ? ? ? 8B ? ? ? ? ? ?")
local COMMAND_CLICKED_BY_PLAYER_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2)
local COMMAND_PARAM_5_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6)
local COMMAND_PARAM_4_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6)
local COMMAND_PARAM_3_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6)
local COMMAND_PARAM_2_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6 + 6)
local COMMAND_PARAM_1_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6 + 6 + 6)
local COMMAND_PARAM_0_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6 + 6 + 6 + 6)

-- 0 means execute, 1 means schedule, 2 means received
local COMMAND_ACTION_PLAN_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6 + 6 + 6 + 6 + 6)

-- Offset into the parameter array (where currently is being read or written from)
local COMMAND_PARAMETER_OFFSET_ADDRESS = MULTIPLAYER_HANDLER_ADDRESS + core.readInteger(niceCommandInfo + 2 + 6 + 6 + 6 + 6 + 6 + 6 + 6 + 6)

local commandParameterSpaceSize = 1260
local commandParameterSpace = core.allocate(commandParameterSpaceSize, true)



local function codeGenerator(register)

  local registerAssembly = nil

  if register == "EAX" then
    registerAssembly = 0xf8
  elseif register == "ECX" then
    registerAssembly = 0xf9
  elseif register == "EDX" then
    registerAssembly = 0xfa
  else
    error("Unsupported register " .. tostring(register))
  end

  return {
    0x83, registerAssembly, CUSTOM_PROTOCOL_NUMBER1, 
    0x75, 0x07, 
    0x90, 0x90, 0x90, 0x90, 0x90,
    0xEB, 0x0A, 
    0x83, registerAssembly, CUSTOM_PROTOCOL_NUMBER2, 
    0x75, 0x05, 
    0x90, 0x90, 0x90, 0x90, 0x90,
    0xC3 
  }

end

local _queueCommandFinder = core.AOBScan("E8 ? ? ? ? 8B ? ? ? ? ? 8B 4C 24 10 01 ? ? ? ? ? 03 C8 3B ? ? ? ? ? 89 4C 24 10 0F ? ? ? ? ? 83 ? ? ? ? 83 C5 01 83 FD 40")
local _queueCommandAddress = core.readInteger(_queueCommandFinder + 1) + (_queueCommandFinder + 5)
log(1, string.format("queue command address: 0x%X", _queueCommandAddress))
local _queueCommand = core.exposeCode(_queueCommandAddress, 2, 1)


local _scheduleCommand = core.exposeCode(core.AOBScan("56 8B F1 81 ? ? ? ? ? ? ? ? ?"), 5, 1)

local PlanNames = {
  [0] = "EXECUTE", -- executing the command (deserialize + execute)
  [1] = "SCHEDULE_FOR_SEND", -- sending your own command (serialize + place in command queue)
  [2] = "SCHEDULE_AFTER_RECEIVE", -- receiving command from another machine/player (prep steps for execution (never used by the game actually))
}

local PlanEnum = {
  ["EXECUTE"] = 0,
  ["SCHEDULE_FOR_SEND"] = 1,
  ["SCHEDULE_AFTER_RECEIVE"] = 2,
}

---@class Handler
---@field public scheduleForSend fun(self, meta)
---@field public scheduleAfterReceive fun(self, meta)
---@field public execute fun(self, meta)
local Handler = {}

---@class Protocol
---@field public extension string
---@field public name string
---@field public type string
---@field public parameterSize number
---@field public handler Handler
local Protocol = {}

---@type table<number, Protocol>
local PROTOCOL_REGISTRY = {}

---@type table<number, string>
local KNOWN_REGISTRY_ENTRIES = {
  [FIRST_AVAILABLE_NUMBER] = "config-similarity-protocol.protocols.config-similarity-protocol",
}

local nextAvailableRegistrySlot = function()
  local i = FIRST_AVAILABLE_NUMBER
  while true do
    if PROTOCOL_REGISTRY[i] == nil and KNOWN_REGISTRY_ENTRIES[i] == nil then 
      return i 
    end

    i = i + 1
  end
end

local setCommandParameterSize = function(size) core.writeInteger(COMMAND_PARAMETER_SIZE_ADDRESS, size) end
local getCommandParameterSize = function(size) core.readInteger(COMMAND_PARAMETER_SIZE_ADDRESS) end

local ParameterSerialisationHelper = require("ParameterSerialisationHelper")
local FixedParameterLocationSerializer = ParameterSerialisationHelper:new({address = COMMAND_FIXED_PARAMETER_LOCATION_ADDRESS, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})
-- This assumes scheduleCommand is always called with ReceivedParameterAddress as the address argument!
local FixedReceivedParameterLocationSerializer = ParameterSerialisationHelper:new({address = COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})

local getCommandOffset = function(commandID)
  return COMMAND_ARRAY_ADDRESS + (commandID * TOTAL_GAME_COMMAND_SIZE)
end


---@class CommandMetaInformation
---@field public base number the base address of the data for this invocation
---@field public time number the time the invocation should take place
---@field public player number the player invoking the protocol
---@field public category number the protocol number
---@field public state number the state of the protocol (executed, scheduled)
---@field public parametersAddress number the address of the parameters of this invocation


---Get data for the invocation
---@param commandID number invocation number
---@return CommandMetaInformation
local getCommandMetaInformation = function(commandID)
  local base = getCommandOffset(commandID)
  return {
    base = base,
    time = core.readInteger(base),
    player = core.readInteger(base + 4),
    category = core.readByte(base + 4 + 4),
    state = core.readByte(base + 4 + 4 + 1),
    parametersAddress = base + 4 + 4 + 1 + 1,
  }
end

local setCommandTime = function(commandID, t)
  core.writeInteger(getCommandMetaInformation(commandID).base + 0, t)
end

local setCommandActionPlan = function(plan) 
  core.writeInteger(COMMAND_ACTION_PLAN_ADDRESS, PlanEnum[plan])
end

-- IMMEDIATE commands
local function onProcessCommand121()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    log(DEBUG, "Custom immediate protocol #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    -- IMMEDIATE command specific code:
    setCommandTime(id, 0) -- set to 0 so execution is immediate after queueing

    local meta = getCommandMetaInformation(id)
    local psh = FixedParameterLocationSerializer

    local subCommand = nil
    if plan == PlanEnum.SCHEDULE_FOR_SEND then
      -- Player did a queueCommand, read the information in this parameter to get the sub protocol information
      subCommand = core.readInteger(COMMAND_PARAM_0_ADDRESS)
      FixedParameterLocationSerializer:serializeInteger(subCommand)
      psh = FixedParameterLocationSerializer
    elseif plan == PlanEnum.EXECUTE then
      subCommand = FixedParameterLocationSerializer:deserializeInteger()
      psh = FixedParameterLocationSerializer
    elseif plan == PlanEnum.SCHEDULE_AFTER_RECEIVE then
      subCommand = FixedReceivedParameterLocationSerializer:deserializeInteger()
      psh = FixedReceivedParameterLocationSerializer
    end

    print("Subcommand: " .. tostring(subCommand))

    local prot = PROTOCOL_REGISTRY[subCommand]
    if prot == nil then
      error("Unknown protocol: " .. tostring(subCommand))
    end

    log(1, "Following protocol: " .. prot.name .. " as defined by extension: " .. prot.extension)

    setCommandParameterSize(4 + prot.parameterSize) -- at least 4 to house the sub protocol as a parameter

    meta.parameters = psh

    local cb
    if plan == PlanEnum["SCHEDULE_FOR_SEND"] then
      cb = prot.handler.scheduleForSend
    elseif plan == PlanEnum["SCHEDULE_AFTER_RECEIVE"] then
      cb = prot.handler.scheduleAfterReceive
    elseif plan == PlanEnum["EXECUTE"] then
      cb = prot.handler.execute
    end

    if cb == nil then
      error("No callback for plan: " .. tostring(PlanNames[plan]))
    end

    log(1, "Calling into handler: ")
    local state, result = pcall(cb, prot.handler, meta)
    if not state then
      error("Error occurred when executing handler for: " .. tostring(subCommand) .. ". Message: " .. tostring(result))
    end

    if plan == PlanEnum.SCHEDULE_FOR_SEND then
      setCommandActionPlan(PlanEnum.EXECUTE)
    end

  end)
  
  if not state then log(WARNING, err) end
end

-- LOCKSTEP commands
local function onProcessCommand122()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    log(DEBUG, "Custom lockstep protocol #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    log(DEBUG, "get command meta information")
    local meta = getCommandMetaInformation(id)

    log(DEBUG, "create ParameterSerialisationHelper")
    local psh = ParameterSerialisationHelper:new({address = meta.parametersAddress, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})

    log(VERBOSE, string.format("offset address: %X", psh.offsetAddress))

    local subCommand = nil
    if plan == PlanEnum.SCHEDULE_FOR_SEND then
      log(DEBUG, string.format("read integer from: %X", COMMAND_PARAM_0_ADDRESS))
      -- Player did a queueCommand, read the information in this parameter to get the sub protocol information
      subCommand = core.readInteger(COMMAND_PARAM_0_ADDRESS)
      ParameterSerialisationHelper:serializeInteger(subCommand)
      psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.EXECUTE then
      log(DEBUG, "deserialize integer from parameters")
      subCommand = ParameterSerialisationHelper:deserializeInteger()
      psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.SCHEDULE_AFTER_RECEIVE then
      log(DEBUG, "deserialize integer from parameters")
      subCommand = ParameterSerialisationHelper:deserializeInteger()
      psh = ParameterSerialisationHelper
    end

    log(DEBUG, "Subcommand: " .. tostring(subCommand))

    local prot = PROTOCOL_REGISTRY[subCommand]
    if prot == nil then
      error("Unknown protocol: " .. tostring(subCommand))
    end

    log(DEBUG, "Following protocol: " .. prot.name .. " as defined by extension: " .. prot.extension)

    setCommandParameterSize(4 + prot.parameterSize) -- at least 4 to house the sub protocol as a parameter

    meta.parameters = psh

    local cb
    if plan == PlanEnum["SCHEDULE_FOR_SEND"] then
      cb = prot.handler.scheduleForSend
    elseif plan == PlanEnum["SCHEDULE_AFTER_RECEIVE"] then
      cb = prot.handler.scheduleAfterReceive
    elseif plan == PlanEnum["EXECUTE"] then
      cb = prot.handler.execute
    end

    if cb == nil then
      error("No callback for plan: " .. tostring(PlanNames[plan]))
    end

    log(DEBUG, "Executing callback for plan: " .. tostring(PlanNames[plan]))
    local state, result = pcall(cb, prot.handler, meta)
    if not state then
      error("Error occurred when executing handler for: " .. tostring(subCommand) .. ". Message: " .. tostring(result))
    end

    log(DEBUG, "Callback succesful for plan: " .. tostring(PlanNames[plan]))

  end)
  
  if not state then log(WARNING, string.format("custom protocol failed to execute: \n%s", err)) end
end



local namespace = {
  enable = function(self, config)

    local onProcessCommand_landingLocation_EAX = core.allocateCode(codeGenerator("EAX"))

    local onProcessCommand_landingLocation_ECX = core.allocateCode(codeGenerator("ECX"))
    
    local onProcessCommand_landingLocation_EDX = core.allocateCode(codeGenerator("EDX"))

    log(DEBUG, string.format("Landing locations: EAX: 0x%X; ECX: 0x%X; EDX: 0x%X", onProcessCommand_landingLocation_EAX, onProcessCommand_landingLocation_ECX, onProcessCommand_landingLocation_EDX))
    
    -- call onProcessCommand and set the command type to 0 because custom command type (121) does not exist. 0 is a dummy
    core.detourCode(function(registers) registers.EAX = 0; onProcessCommand121(); return registers end, onProcessCommand_landingLocation_EAX + 5, 5)
    core.detourCode(function(registers) registers.ECX = 0; onProcessCommand121(); return registers end, onProcessCommand_landingLocation_ECX + 5, 5)
    core.detourCode(function(registers) registers.EDX = 0; onProcessCommand121(); return registers end, onProcessCommand_landingLocation_EDX + 5, 5)
    
    -- Untested
    core.detourCode(function(registers) registers.EAX = 0; onProcessCommand122(); return registers end, onProcessCommand_landingLocation_EAX + 5 + 5 + 5 + 2, 5)
    core.detourCode(function(registers) registers.ECX = 0; onProcessCommand122(); return registers end, onProcessCommand_landingLocation_ECX + 5 + 5 + 5 + 2, 5)
    core.detourCode(function(registers) registers.EDX = 0; onProcessCommand122(); return registers end, onProcessCommand_landingLocation_EDX + 5 + 5 + 5 + 2, 5)
    

    core.insertCode(
      scheduleCommandHook1Location, 
    scheduleCommandHook1Size, 
    {core.callTo(onProcessCommand_landingLocation_EDX)},
    nil,
    "after"
    )

    core.insertCode(
      processWaitingCommandsHookLocation, 
      processWaitingCommandsHookSize, 
    {core.callTo(onProcessCommand_landingLocation_EDX)},
    nil,
    "after"
    )
  
    core.insertCode(
      queueCommandHook2Location, 
      queueCommandHook2Size, 
    {core.callTo(onProcessCommand_landingLocation_EDX)},
    nil,
    "after"
    )

    core.insertCode(
      scheduleCommandHook2Location, 
      scheduleCommandHook2Size, 
    {core.callTo(onProcessCommand_landingLocation_EAX)},
    nil,
    "after"
    )

    core.insertCode(
      sendLongerDataHookLocation, 
      sendLongerDataHookSize, 
    {core.callTo(onProcessCommand_landingLocation_EAX)},
    nil,
    "after"
    )
  
    core.insertCode(
      queueCommandHook1Location, 
      queueCommandHook1Size, 
    {core.callTo(onProcessCommand_landingLocation_ECX)},
    nil,
    "after"
    )

  end,
  disable = function(self, config)
  end,
  
}


---Helper function to process a protocol value that is either a number or a key
---@param p string|number the protocol
---@return number the protocol number
local function argToProtocolNumber(p)
  local protocolNumber = p
  if type(p) ~= "number" then
    protocolNumber = namespace:getProtocolNumberByKey(p)
    if protocolNumber == nil then
      error(string.format("Cannot find a protocol associated with identifier: %s", tostring(p)))
    end
  end
  return protocolNumber
end

---Register a custom protocol
---@param self table reference to this module
---@param extension string name of the extension
---@param name string name of the protocol
---@param type string "IMMEDIATE" or "LOCKSTEP"
---@param parameterSize number total size of the parameters in serialized form
---@param handler Handler handler of this protocol, table with function scheduleForSend, scheduleAfterReceive, and execute
---@return nil
function namespace.registerCustomProtocol(self, extension, name, type, parameterSize, handler)
  -- TODO: insert check for known registerProtocol numbers
  -- TODO: insert check for too large parameter size?

  local key = tostring(extension) .. ".protocols." .. tostring(name)

  local number

  for reservedNumber, protocolName in pairs(KNOWN_REGISTRY_ENTRIES) do
    if protocolName == key then
      number = reservedNumber
    end
  end

  if number == nil then number = nextAvailableRegistrySlot() end

  KNOWN_REGISTRY_ENTRIES[number] = key

  ---@type Protocol
  local protocol = {
    extension = extension,
    type = type,
    name = name,
    parameterSize = parameterSize,
    handler = handler,
  }
  PROTOCOL_REGISTRY[number] = protocol

  return number
end

---Get the protocol number
---@param self table reference to this module
---@param key string key of the protocol
---@return nil
function namespace.getProtocolNumberByKey(self, key)
  for number, k in pairs(KNOWN_REGISTRY_ENTRIES) do
    if k == key then return number end
  end

  return nil
end

---Get the protocol number
---@param self table reference to this module
---@param extension string name of the extension
---@param name string name of the protocol
---@return nil
function namespace.getProtocolNumber(self, extension, name)
  local key = tostring(extension) .. ".protocols." .. tostring(name)

  for number, k in pairs(KNOWN_REGISTRY_ENTRIES) do
    if k == key then return number end
  end

  return nil
end


---Pretend a protocol invocation is received over multiplayer
---@param self table reference to the module
---@param commandCategory number protocol number
---@param player number the player that sent the invocation
---@param time number use 0 for immediate execution instead of lockstep (game time)
---@param parameterBytes table table of bytes that represent the parameters to the protocol invocation
---@return nil
function namespace.injectProtocol(self, protocol, player, time, parameterBytes)
  if #parameterBytes > commandParameterSpaceSize then 
    error("parameter bytes is too long")
  else
    core.writeBytes(COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS, parameterBytes)
  end

  
  if protocol < 0 or protocol > CUSTOM_PROTOCOL_NUMBER2 then
    error("Illegal command category: " .. tostring(protocol))
  end
  _scheduleCommand(MULTIPLAYER_HANDLER_ADDRESS, protocol, player, time, COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS)
end


local argArrayMemoryMapping = {
  COMMAND_PARAM_0_ADDRESS,
  COMMAND_PARAM_1_ADDRESS,
  COMMAND_PARAM_2_ADDRESS,
  COMMAND_PARAM_3_ADDRESS,
  COMMAND_PARAM_4_ADDRESS,
  COMMAND_PARAM_5_ADDRESS,
}

---Write parameters to memory
---@param ... the parameters to write, can be tables and loose integers
---@return nil
local function setupInvocationParameters(...)
  local args = table.pack(...)
  args.n = nil

  local argArray = {}
  local otherArg = {}
  for _, arg in ipairs(args) do
    if type(arg) == "table" then
      for k, v in pairs(arg) do
        if type(k) == "number" then
          -- add it to the list of args
          table.insert(argArray, v)  
        elseif type(k) == "string" then
          if otherArg[k] ~= nil then
            error(string.format("cannot overwrite already specified argument: %s", k))
          end
          -- add it to a special set
          otherArg[k] = v
        else
          error(string.format("illegal argument type: %s", type(v)))    
        end
        
      end
    elseif type(arg) == "number" then
      -- add it to the list of args
      table.insert(argArray, arg)
    else
      error(string.format("illegal argument type: %s", type(arg)))
    end
  end

  if #argArray > 6 then
    error(string.format("too many arguments applied: %s", #argArray))
  end

  for k,v in ipairs(argArray) do
    core.writeInteger(argArrayMemoryMapping[k], v)
  end

  for k, v in pairs(otherArg) do
    error(string.format("string keys for invocation parameters not yet supported: %s", tostring(k)))
  end

end

---Invoke original protocol
---@param self table reference to this module
---@param protocol number protocol number
---@param ... number|table a number or table with numbers acting as the parameters to the invocation
---@return nil
function namespace.invokeOriginalProtocol(self, protocol, ...) 
  if protocol < 0 or protocol > CUSTOM_PROTOCOL_NUMBER2 then
    error("Illegal protocol number: " .. tostring(protocol))
  end

  setupInvocationParameters(...)
  _queueCommand(MULTIPLAYER_HANDLER_ADDRESS, protocol)
end



---Invoke custom protocol by name or number
---Arguments for the protocol are to be set up during the call to scheduleForSend
---@param self table reference to the module
---@param protocol number|string name or number of the protocol
---@return nil
function namespace.invokeCustomProtocol(self, protocol)
  local protocolNumber = argToProtocolNumber(protocol)

  if protocolNumber < FIRST_AVAILABLE_NUMBER then
    error(string.format("Illegal custom protocol number: %s", protocolNumber))
  end

  if PROTOCOL_REGISTRY[protocolNumber] == nil then 
    error("Unknown custom protocol: " .. tostring(protocolNumber)) 
  end

  if PROTOCOL_REGISTRY[protocolNumber].type == "IMMEDIATE" then
    core.writeInteger(COMMAND_PARAM_0_ADDRESS, protocolNumber)
    self:invokeOriginalProtocol(CUSTOM_PROTOCOL_NUMBER1) -- todo, add arg protocolNumber
  elseif PROTOCOL_REGISTRY[protocolNumber].type == "LOCKSTEP" then
    core.writeInteger(COMMAND_PARAM_0_ADDRESS, protocolNumber)
    self:invokeOriginalProtocol(CUSTOM_PROTOCOL_NUMBER2) -- todo, add arg protocolNumber
  else
    error(string.format("unknown protocol type: %s", tostring(PROTOCOL_REGISTRY[protocolNumber].type)))
  end
end


---Invoke protocol
---@param self table reference to this module
---@param protocol number|string name or number of the protocol
---@param ... number|table a number or table with numbers acting as the parameters to the invocation.
---Only supported for original protocols
---@return nil
function namespace.invokeProtocol(self, protocol, ...)
  local protocolNumber = argToProtocolNumber(protocol)

  if protocolNumber < 1 then
    error(string.format("invalid protocol number: %s", protocolNumber))    
  end

  if protocolNumber <= LAST_ORIGINAL_NUMBER then
    return self:invokeOriginalProtocol(protocolNumber, ...)
  end

  if protocolNumber >= FIRST_AVAILABLE_NUMBER then
    return self:invokeCustomProtocol(protocolNumber)
  end

  error(string.format("illegal protocol number: %s", protocolNumber))
end

return namespace
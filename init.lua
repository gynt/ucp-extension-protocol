
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
local CUSTOM_PROTOCOL_NUMBER1 = 120 + 1
local CUSTOM_PROTOCOL_NUMBER2 = CUSTOM_PROTOCOL_NUMBER1 + 1

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

local PROTOCOL_REGISTRY = {}

local KNOWN_REGISTRY_ENTRIES = {
  [1] = "config-similarity-protocol.protocols.config-similarity-protocol",
}

local nextAvailableRegistrySlot = function()
  local i = 1
  while true do
    if PROTOCOL_REGISTRY[i] == nil and KNOWN_REGISTRY_ENTRIES[i] == nil then return i end

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
local getCommandMetaInformation = function(commandID)
  local base = getCommandOffset(commandID)
  return {
    base = base,
    time = core.readInteger(base),
    player = core.readInteger(base + 4),
    category = core.readByte(base + 4 + 4),
    state = core.readByte(base + 4 + 4 + 1),
    parameters = base + 4 + 4 + 1 + 1,
  }
end

local setCommandTime = function(commandID, t)
  core.writeInteger(getCommandMetaInformation(commandID).base + 0, t)
end

local setCommandActionPlan = function(plan) 
  core.writeInteger(COMMAND_ACTION_PLAN_ADDRESS, PlanEnum[plan])
end

-- DIRECT commands
local function onProcessCommand121()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    print("Custom command #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    -- DIRECT command specific code:
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

-- DELAYED commands
local function onProcessCommand122()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    print("Custom command #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    local meta = getCommandMetaInformation(id)
    local psh = ParameterSerialisationHelper:new({address = meta.parameters, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})

    local subCommand = nil
    if plan == PlanEnum.SCHEDULE_FOR_SEND then
      -- Player did a queueCommand, read the information in this parameter to get the sub protocol information
      subCommand = core.readInteger(COMMAND_PARAM_0_ADDRESS)
      ParameterSerialisationHelper:serializeInteger(subCommand)
      psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.EXECUTE then
      subCommand = ParameterSerialisationHelper:deserializeInteger()
      psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.SCHEDULE_AFTER_RECEIVE then
      subCommand = ParameterSerialisationHelper:deserializeInteger()
      psh = ParameterSerialisationHelper
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

    local state, result = pcall(cb, prot.handler, meta)
    if not state then
      error("Error occurred when executing handler for: " .. tostring(subCommand) .. ". Message: " .. tostring(result))
    end

  end)
  
  if not state then log(WARNING, err) end
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
  registerProtocol = function(self, extension, name, type, parameterSize, handler)
    -- TODO: insert check for known registerProtocol numbers

    local key = tostring(extension) .. ".protocols." .. tostring(name)

    local number

    for reservedNumber, protocolName in pairs(KNOWN_REGISTRY_ENTRIES) do
      if protocolName == key then
        number = reservedNumber
      end
    end

    if number == nil then number = nextAvailableRegistrySlot() end

    KNOWN_REGISTRY_ENTRIES[key] = number

    PROTOCOL_REGISTRY[number] = {
      extension = extension,
      type = type,
      name = name,
      parameterSize = parameterSize,
      handler = handler,
    }

    return number
  end,
  getProtocolNumber = function(self, extension, name)
    local key = tostring(extension) .. ".protocols." .. tostring(name)

    return KNOWN_REGISTRY_ENTRIES
  end,
  queueCommand = function(self, commandCategory) 
    if commandCategory < 0 or commandCategory > CUSTOM_PROTOCOL_NUMBER2 then
      error("Illegal command category: " .. tostring(commandCategory))
    end
    _queueCommand(MULTIPLAYER_HANDLER_ADDRESS, commandCategory)
  end,
  scheduleCommand = function(self, commandCategory, player, time, parameterBytes)
    if #parameterBytes > commandParameterSpaceSize then 
      error("parameter bytes is too long")
    else
      core.writeBytes(COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS, parameterBytes)
    end

    
    if commandCategory < 0 or commandCategory > CUSTOM_PROTOCOL_NUMBER2 then
      error("Illegal command category: " .. tostring(commandCategory))
    end
    _scheduleCommand(MULTIPLAYER_HANDLER_ADDRESS, commandCategory, player, time, COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS)
  end,
  queueProtocol = function(self, protocolNumber)
    if PROTOCOL_REGISTRY[protocolNumber] == nil then error("Unknown protocol: " .. tostring(protocolNumber)) end

    core.writeInteger(COMMAND_PARAM_0_ADDRESS, protocolNumber)

    if PROTOCOL_REGISTRY[protocolNumber].type == "DIRECT" then
      self:queueCommand(CUSTOM_PROTOCOL_NUMBER1)
    else
      self:queueCommand(CUSTOM_PROTOCOL_NUMBER2)
    end
  end,
}

return namespace

local globals = require("globals")
local common = require("protocols.common")
local interface = require("game.interface")


local PROTOCOL_REGISTRY = globals.PROTOCOL_REGISTRY

local namespace = {
  enable = function(self, config)

    require("game.hooks").setHooks()

    require("tests")
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

    
  local KNOWN_REGISTRY_ENTRIES = globals.KNOWN_REGISTRY_ENTRIES
  local nextAvailableRegistrySlot = globals.nextAvailableRegistrySlot

  local key = tostring(extension) .. ".protocols." .. tostring(name)

  local number

  for reservedNumber, protocolName in pairs(KNOWN_REGISTRY_ENTRIES) do
    if protocolName == key then
      number = reservedNumber

      if PROTOCOL_REGISTRY[number] ~= nil then
        error(string.format("protocol already registered: %s", key))
      end
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
  
local KNOWN_REGISTRY_ENTRIES = globals.KNOWN_REGISTRY_ENTRIES

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
  
  local KNOWN_REGISTRY_ENTRIES = globals.KNOWN_REGISTRY_ENTRIES

  local key = tostring(extension) .. ".protocols." .. tostring(name)

  for number, k in pairs(KNOWN_REGISTRY_ENTRIES) do
    if k == key then return number end
  end

  return nil
end


local CUSTOM_PROTOCOL_NUMBER2 = globals.CUSTOM_PROTOCOL_NUMBER2
local COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS = common.COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS
local MULTIPLAYER_HANDLER_ADDRESS = common.MULTIPLAYER_HANDLER_ADDRESS
local _scheduleCommand = interface._scheduleCommand

---Pretend a protocol invocation is received over multiplayer
---@param self table reference to the module
---@param commandCategory number protocol number
---@param player number the player that sent the invocation
---@param time number use 0 for immediate execution instead of lockstep (game time)
---@param parameterBytes table table of bytes that represent the parameters to the protocol invocation
---@return nil
function namespace.injectProtocol(self, protocol, player, time, parameterBytes)
  if #parameterBytes > globals.MAX_PARAMETER_LENGTH then 
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
  common.COMMAND_PARAM_0_ADDRESS,
  common.COMMAND_PARAM_1_ADDRESS,
  common.COMMAND_PARAM_2_ADDRESS,
  common.COMMAND_PARAM_3_ADDRESS,
  common.COMMAND_PARAM_4_ADDRESS,
  common.COMMAND_PARAM_5_ADDRESS,
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

local checkIllegalInvocationNesting = require("helpers.checkIllegalInvocationNesting").checkIllegalInvocationNesting
local _queueCommand = interface._queueCommand

---Invoke original protocol
---@param self table reference to this module
---@param protocol number protocol number
---@param ... number|table a number or table with numbers acting as the parameters to the invocation
---@return nil
function namespace.invokeOriginalProtocol(self, protocol, ...) 
  if protocol < 0 or protocol > CUSTOM_PROTOCOL_NUMBER2 then
    error("Illegal protocol number: " .. tostring(protocol))
  end

  checkIllegalInvocationNesting(protocol)

  setupInvocationParameters(...)
  _queueCommand(MULTIPLAYER_HANDLER_ADDRESS, protocol)
end

local FIRST_AVAILABLE_NUMBER = globals.FIRST_AVAILABLE_NUMBER
local CUSTOM_PROTOCOL_NUMBER1 = globals.CUSTOM_PROTOCOL_NUMBER1

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

  checkIllegalInvocationNesting(protocolNumber)

  if PROTOCOL_REGISTRY[protocolNumber].type == "IMMEDIATE" then
    core.writeInteger(common.COMMAND_PARAM_0_ADDRESS, protocolNumber)
    self:invokeOriginalProtocol(CUSTOM_PROTOCOL_NUMBER1) -- todo, add arg protocolNumber
  elseif PROTOCOL_REGISTRY[protocolNumber].type == "LOCKSTEP" then
    core.writeInteger(common.COMMAND_PARAM_0_ADDRESS, protocolNumber)
    self:invokeOriginalProtocol(CUSTOM_PROTOCOL_NUMBER2) -- todo, add arg protocolNumber
  else
    error(string.format("unknown protocol type: %s", tostring(PROTOCOL_REGISTRY[protocolNumber].type)))
  end
end

local LAST_ORIGINAL_NUMBER = globals.LAST_ORIGINAL_NUMBER

---Invoke protocol by number or key
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

  log(DEBUG, string.format("invokeProtocol(%s)", protocolNumber))

  if protocolNumber <= LAST_ORIGINAL_NUMBER then
    return self:invokeOriginalProtocol(protocolNumber, ...)
  end

  if protocolNumber >= FIRST_AVAILABLE_NUMBER then
    return self:invokeCustomProtocol(protocolNumber)
  end

  error(string.format("illegal protocol number: %s", protocolNumber))
end

return namespace
-- byte value, max is 127. 125 and 126 are already taken. Not sure about 121.
local LAST_ORIGINAL_NUMBER = 120 -- Actually 120 is illegal value
local CUSTOM_PROTOCOL_NUMBER1 = LAST_ORIGINAL_NUMBER + 1
local CUSTOM_PROTOCOL_NUMBER2 = CUSTOM_PROTOCOL_NUMBER1 + 1
local FIRST_AVAILABLE_NUMBER = CUSTOM_PROTOCOL_NUMBER2 + 1 + 7 -- reserve an extra 7 for internal use

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

---Note that a Handler that is handling a Lockstep protocol
---can never invoke an Immediate protocol, because the
---ID of the currently processed invocation will be messed up
---causing an infinite loop as the Handler's invocation is called
---repeatedly
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

---@class InvocationLock
---@field current Protocol currently executing protocol
local InvocationLock = {}

---Lock to lock what kind of invocation can be called
---Lockstep protocols (game time) can never call immediate protocols
---@type InvocationLock
local INVOCATION_LOCK = {
  current = nil,
}

return {
  LAST_ORIGINAL_NUMBER = LAST_ORIGINAL_NUMBER,
  CUSTOM_PROTOCOL_NUMBER1 = CUSTOM_PROTOCOL_NUMBER1,
  CUSTOM_PROTOCOL_NUMBER2 = CUSTOM_PROTOCOL_NUMBER2,
  FIRST_AVAILABLE_NUMBER = FIRST_AVAILABLE_NUMBER,
  PlanNames = PlanNames,
  PlanEnum = PlanEnum,
  Handler = Handler,
  Protocol = Protocol,
  PROTOCOL_REGISTRY = PROTOCOL_REGISTRY,
  KNOWN_REGISTRY_ENTRIES = KNOWN_REGISTRY_ENTRIES,
  nextAvailableRegistrySlot = nextAvailableRegistrySlot,
  InvocationLock = InvocationLock,
  INVOCATION_LOCK = INVOCATION_LOCK,
}
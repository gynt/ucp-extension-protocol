---Invocation context for custom protocols
---@class Context
---@field public current any The current context
local CONTEXT = {
  current = nil,
}

---Invocation meta information detailing meta information about the invocation
---@class CommandMetaInformation
---@field public base number the base address of the data for this invocation
---@field public time number the time the invocation should take place
---@field public timeAddress number the memory pointer to the time (int32) the invocation should take place
---@field public player number the player invoking the protocol
---@field public category number the protocol number
---@field public state number the state of the protocol (executed, scheduled)
---@field public parametersAddress number the address of the parameters of this invocation
---@field public parameters ParameterSerialisationHelper helper to (de)serialize parameters
local CommandMetaInformation = {}

---Note that only an Immediate protocol can invoke another
---Immediate protocol.
---A Handler that is handling a Lockstep protocol
---can never invoke an Immediate protocol, because the
---ID of the currently processed invocation will be messed up
---causing an infinite loop as the Handler's invocation is called
---repeatedly. Similarly, an Immediate protocol can never invoke
---a Lockstep protocol because the Lockstep protocol will never scheduled
---@class Handler
---@field public scheduleForSend fun(self: Handler, meta: CommandMetaInformation, context: Context):void
---@field public scheduleAfterReceive fun(self: Handler, meta: CommandMetaInformation):void
---@field public execute fun(self: Handler, meta: CommandMetaInformation):void
local Handler = {}

---@alias HandlerCallback fun(self: Handler, meta: CommandMetaInformation):void

---A protocol is the way to share events and state across the network.
---A Lockstep protocol is used for events that should be processed simultaenously on
---each machine in Multiplayer. An Immediate protocol is used for all other events
---and is executed immediately on each machine
---@class Protocol
---@field public extension string
---@field public name string
---@field public type string
---@field public parameterSize number
---@field public handler Handler
local Protocol = {}

---@type table<number, Protocol>
local PROTOCOL_REGISTRY = {}

-- byte value, max is 127. 125 and 126 are already taken. Not sure about 121.
local LAST_ORIGINAL_NUMBER = 120 -- Actually 120 is illegal value
local CUSTOM_PROTOCOL_NUMBER1 = LAST_ORIGINAL_NUMBER + 1
local CUSTOM_PROTOCOL_NUMBER2 = CUSTOM_PROTOCOL_NUMBER1 + 1
local FIRST_AVAILABLE_NUMBER = CUSTOM_PROTOCOL_NUMBER2 + 1 + 7 -- reserve an extra 7 for internal use

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

---An invocation lock tracks which custom protocol
---has been invoked in order to restrict the types of
---nested invocation that can occur
---@class InvocationLock
---@field current Protocol currently executing custom protocol
local InvocationLock = {}

---Lock to lock what kind of invocation can be called
---Lockstep protocols (game time) can never call immediate protocols
---@type InvocationLock
local INVOCATION_LOCK = {
  current = nil,
}

local MAX_PARAMETER_LENGTH = 1260

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
  MAX_PARAMETER_LENGTH = MAX_PARAMETER_LENGTH,
  CONTEXT = CONTEXT,
}
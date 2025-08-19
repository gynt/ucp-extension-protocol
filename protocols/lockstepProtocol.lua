local globals = require("globals")

local PlanEnum = globals.PlanEnum
local PlanNames = globals.PlanNames
local PROTOCOL_REGISTRY = globals.PROTOCOL_REGISTRY
local INVOCATION_LOCK = globals.INVOCATION_LOCK

local common = require("protocols.common")
local COMMAND_ACTION_PLAN_ADDRESS = common.COMMAND_ACTION_PLAN_ADDRESS
local COMMAND_CURRENT_ID_ADDRESS = common.COMMAND_CURRENT_ID_ADDRESS
local COMMAND_PARAM_0_ADDRESS = common.COMMAND_PARAM_0_ADDRESS
local getCommandMetaInformation = common.getCommandMetaInformation
local setCommandParameterSize = common.setCommandParameterSize
local COMMAND_PARAMETER_OFFSET_ADDRESS = common.COMMAND_PARAMETER_OFFSET_ADDRESS
local COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS = common.COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS

local ParameterSerialisationHelper = require("helpers.parameterSerialisationHelper")

---TODO: there is a latent issue here which is whether it is always known which address the packet is at upon receive...
-- LOCKSTEP commands
local function onProcessCommand122()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    log(DEBUG, "custom lockstep protocol invocation #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    log(DEBUG, "get command meta information")
    local meta = getCommandMetaInformation(id)

    log(VERBOSE, string.format("scheduled for time: %s (current time is: %s)", meta.time, core.readInteger(common.MAP_TIME_ADDRESS)))

    log(DEBUG, "create ParameterSerialisationHelper")
    local psh = ParameterSerialisationHelper:new({address = meta.parametersAddress, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})

    log(VERBOSE, string.format("offset address: %X", psh.offsetAddress))

    local subCommand = nil
    if plan == PlanEnum.SCHEDULE then
      log(DEBUG, string.format("read integer from: %X", COMMAND_PARAM_0_ADDRESS))
      -- Player did a queueCommand, read the information in this parameter to get the sub protocol information
      subCommand = core.readInteger(COMMAND_PARAM_0_ADDRESS)
      psh:serializeInteger(subCommand)
      -- psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.EXECUTE then
      log(DEBUG, "deserialize integer from parameters")
      subCommand = psh:deserializeInteger()
      -- psh = ParameterSerialisationHelper
    elseif plan == PlanEnum.SCHEDULE_AFTER_RECEIVE then
      log(DEBUG, "deserialize integer from parameters after receive")
      psh = ParameterSerialisationHelper:new({address = COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})
      subCommand = psh:deserializeInteger()
      -- psh = ParameterSerialisationHelper
    end

    log(DEBUG, "subcommand: " .. tostring(subCommand))

    local prot = PROTOCOL_REGISTRY[subCommand]
    if prot == nil then
      error("Unknown protocol: " .. tostring(subCommand))
    end

    log(DEBUG, "following protocol: " .. prot.name .. " as defined by extension: " .. prot.extension)

    setCommandParameterSize(4 + prot.parameterSize) -- at least 4 to house the sub protocol as a parameter

    meta.parameters = psh

    local cb
    if plan == PlanEnum["SCHEDULE"] then
      cb = prot.handler.schedule or (
        function() end
      )
    elseif plan == PlanEnum["SCHEDULE_AFTER_RECEIVE"] then
      cb = prot.handler.scheduleAfterReceive or (
        function() end
      )
    elseif plan == PlanEnum["EXECUTE"] then
      cb = prot.handler.execute
    end

    if cb == nil then
      error("No callback for plan: " .. tostring(PlanNames[plan]))
    end

    log(DEBUG, "executing callback for plan: " .. tostring(PlanNames[plan]))
    local state, result
    
    INVOCATION_LOCK.current = prot
    if plan == PlanEnum["SCHEDULE"] then
      state, result = pcall(cb, prot.handler, meta, globals.CONTEXT.current)
    else
      state, result = pcall(cb, prot.handler, meta)
    end
    INVOCATION_LOCK.current = nil

    if not state then
      error("Error occurred when executing handler for: " .. tostring(subCommand) .. ". Message: " .. tostring(result))
    end

    log(DEBUG, "callback succesful for plan: " .. tostring(PlanNames[plan]))

  end)
  
  if not state then log(WARNING, string.format("custom protocol failed to execute: \n%s", err)) end
end

return {
  onProcessCommand122 = onProcessCommand122,
}
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

local COMMAND_FIXED_PARAMETER_LOCATION_ADDRESS = common.COMMAND_FIXED_PARAMETER_LOCATION_ADDRESS
local COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS = common.COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS

local ParameterSerialisationHelper = require("ParameterSerialisationHelper")
local FixedParameterLocationSerializer = ParameterSerialisationHelper:new({address = COMMAND_FIXED_PARAMETER_LOCATION_ADDRESS, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})
-- This assumes scheduleCommand is always called with ReceivedParameterAddress as the address argument!
local FixedReceivedParameterLocationSerializer = ParameterSerialisationHelper:new({address = COMMAND_FIXED_RECEIVED_PARAMETER_LOCATION_ADDRESS, offsetAddress = COMMAND_PARAMETER_OFFSET_ADDRESS})

local setCommandActionPlan = function(plan) 
  core.writeInteger(COMMAND_ACTION_PLAN_ADDRESS, PlanEnum[plan])
end

local setCommandTime = function(commandID, t)
  core.writeInteger(getCommandMetaInformation(commandID).base + 0, t)
end

-- IMMEDIATE commands
local function onProcessCommand121()
  local state, err = pcall(function()
    local id = core.readInteger(COMMAND_CURRENT_ID_ADDRESS)
    local plan = core.readInteger(COMMAND_ACTION_PLAN_ADDRESS)
    log(DEBUG, "custom immediate protocol invocation #" .. tostring(id) .. " called with plan: " .. tostring(PlanNames[plan]))

    -- IMMEDIATE command specific code:
    setCommandTime(id, 0) -- set to 0 so execution is immediate after queueing

    local meta = getCommandMetaInformation(id)

    log(VERBOSE, string.format("scheduled for time: %s", meta.time))

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

    log(VERBOSE, "subcommand: " .. tostring(subCommand))

    ---@type Protocol
    local prot = PROTOCOL_REGISTRY[subCommand]
    if prot == nil then
      error("Unknown protocol: " .. tostring(subCommand))
    end

    log(DEBUG, "following protocol: " .. prot.name .. " as defined by extension: " .. prot.extension)

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
    INVOCATION_LOCK.current = prot
    local state, result = pcall(cb, prot.handler, meta)
    INVOCATION_LOCK.current = nil
    if not state then
      error("Error occurred when executing handler for: " .. tostring(subCommand) .. ". Message: " .. tostring(result))
    end

    if plan == PlanEnum.SCHEDULE_FOR_SEND then
      setCommandActionPlan(PlanEnum.EXECUTE)
    end

  end)
  
  if not state then log(WARNING, err) end
end

return {
  onProcessCommand121 = onProcessCommand121,
}
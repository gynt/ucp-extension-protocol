
local globals = require("globals")

local onProcessCommand121 = require("protocols.immediateProtocol").onProcessCommand121
local onProcessCommand122 = require("protocols.lockstepProtocol").onProcessCommand122


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
    0x83, registerAssembly, globals.CUSTOM_PROTOCOL_NUMBER1, 
    0x75, 0x07, 
    0x90, 0x90, 0x90, 0x90, 0x90,
    0xEB, 0x0A, 
    0x83, registerAssembly, globals.CUSTOM_PROTOCOL_NUMBER2, 
    0x75, 0x05, 
    0x90, 0x90, 0x90, 0x90, 0x90,
    0xC3 
  }

end

local function setHooks()
  
  local onProcessCommand_landingLocation_EAX = core.allocateCode(codeGenerator("EAX"))

  local onProcessCommand_landingLocation_ECX = core.allocateCode(codeGenerator("ECX"))
  
  local onProcessCommand_landingLocation_EDX = core.allocateCode(codeGenerator("EDX"))

  log(DEBUG, string.format("Landing locations: EAX: 0x%X; ECX: 0x%X; EDX: 0x%X", onProcessCommand_landingLocation_EAX, onProcessCommand_landingLocation_ECX, onProcessCommand_landingLocation_EDX))
  
  -- call onProcessCommand and set the command type to 0 because custom command type (121) does not exist. 0 is a dummy
  core.detourCode(function(registers) 
      registers.EAX = 0
      onProcessCommand121()
      return registers 
    end, onProcessCommand_landingLocation_EAX + 5, 5)
  core.detourCode(function(registers) 
      registers.ECX = 0
      onProcessCommand121()
      return registers 
    end, onProcessCommand_landingLocation_ECX + 5, 5)
  core.detourCode(function(registers) 
      registers.EDX = 0
      onProcessCommand121()
      return registers
    end, onProcessCommand_landingLocation_EDX + 5, 5)
  
  -- Untested
  core.detourCode(function(registers) 
      registers.EAX = 0
      onProcessCommand122()
      return registers
    end, onProcessCommand_landingLocation_EAX + 5 + 5 + 5 + 2, 5)
  core.detourCode(function(registers) 
      registers.ECX = 0
      onProcessCommand122()
      return registers
    end, onProcessCommand_landingLocation_ECX + 5 + 5 + 5 + 2, 5)
  core.detourCode(function(registers)
      registers.EDX = 0
      onProcessCommand122()
      return registers 
    end, onProcessCommand_landingLocation_EDX + 5 + 5 + 5 + 2, 5)
  

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
end

return {
  setHooks = setHooks,
}
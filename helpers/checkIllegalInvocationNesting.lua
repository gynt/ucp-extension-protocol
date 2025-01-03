local knownProtocolTypes = require("game.knownProtocolTypes")

local globals = require("globals")
local INVOCATION_LOCK = globals.INVOCATION_LOCK
local PROTOCOL_REGISTRY = globals.PROTOCOL_REGISTRY


---Only IMMEDIATE => IMMEDIATE works because there is a specific clause in the code
---that immediately clears the command if time == 0 (IMMEDIATE).
---All other combinations go through the processWaitingCommands which causes issues
---as the one waiting in the array is never put to processed.
local function checkIllegalInvocationNesting(protocol)
  local l = INVOCATION_LOCK.current

  log(VERBOSE, string.format("checkIllegalInvocationNesting: checking active invocation type"))

  if l ~= nil then
    log(VERBOSE, string.format("checkIllegalInvocationNesting: checking active invocation type: %s", l.type))
    -- We are currently executing/scheduling a protocol already, does this new invocation conflict?
    if l.type == "LOCKSTEP" then
      error(string.format("A %s protocol can never invoke another protocol: %s",  l.type, protocol))
    elseif l.type == "IMMEDIATE" then
      local kpt = knownProtocolTypes[protocol]
      if kpt ~= nil then
        log(VERBOSE, string.format("checkIllegalInvocationNesting: checking active invocation type: %s against %s", l.type, kpt))
        if kpt == "LOCKSTEP" then
          error(string.format("A %s protocol can never invoke an %s protocol (%s)",  l.type, kpt, protocol))
        end
      else
        local pr = PROTOCOL_REGISTRY[protocol]
        if pr ~= nil then
          log(VERBOSE, string.format("checkIllegalInvocationNesting: checking active invocation type: %s against %s", l.type, pr))
          if pr.type == "LOCKSTEP" then
            error(string.format("A %s protocol can never invoke an %s protocol (%s)", l.type, pr, protocol))
          end
        else
          log(WARNING, string.format("checkIllegalInvocationNesting: cannot check, unknown protocol type: %s", protocol))
        end
      end
    end
  end
end

return {
  checkIllegalInvocationNesting = checkIllegalInvocationNesting,
}
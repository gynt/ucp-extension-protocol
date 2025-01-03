local _queueCommandFinder = core.AOBScan("E8 ? ? ? ? 8B ? ? ? ? ? 8B 4C 24 10 01 ? ? ? ? ? 03 C8 3B ? ? ? ? ? 89 4C 24 10 0F ? ? ? ? ? 83 ? ? ? ? 83 C5 01 83 FD 40")
local _queueCommandAddress = core.readInteger(_queueCommandFinder + 1) + (_queueCommandFinder + 5)

local _queueCommand = core.exposeCode(_queueCommandAddress, 2, 1)


local _scheduleCommand = core.exposeCode(core.AOBScan("56 8B F1 81 ? ? ? ? ? ? ? ? ?"), 5, 1)

return {
  _queueCommand = _queueCommand,
  _scheduleCommand = _scheduleCommand,
}
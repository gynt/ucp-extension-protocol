local PROTOCOL_REGISTRY = require("globals").PROTOCOL_REGISTRY

local pGameVersionLocationInstruction = core.AOBScan("C7 ? ? ? ? ? ? ? ? ? E8 ? ? ? ? C7 ? ? ? ? ? ? ? ? ? C3 85 C0")
local pGameVersion = pGameVersionLocationInstruction + 6

local function writeMultiplayerGameVersion(version)
  core.writeCodeInteger(pGameVersion, version)
end

local function hashProtocols()
    local array = {}
    for number, protocol in pairs(PROTOCOL_REGISTRY) do
        local name = protocol.name
        table.insert(array, {name, number})
    end
    if #array == 0 then return nil end
    table.sort(array, function(a, b) return a[1] < b[1] end)
    local message = yaml.dump(array)
    local hash = sha.sha1(message)

    return tonumber(hash:sub(1, 8), 16), hash -- return hash number and full hash
end

local setMultiplayerGameVersion = function()
    local hash = hashProtocols()
    if hash ~= nil then
      log(VERBOSE, string.format("Setting game version to: %X", hash))
      writeMultiplayerGameVersion(hash)
    else
      log(VERBOSE, string.format("Leaving game version unchanged: %X", core.readInteger(pGameVersion)))
    end
end

return {
    setMultiplayerGameVersion = setMultiplayerGameVersion,
}
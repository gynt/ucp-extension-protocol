local PROTOCOL_REGISTRY = require("globals").PROTOCOL_REGISTRY

local function writeMultiplayerGameVersion(version)
    error("not yet implemented")
end

local function hashProtocols()
    local array = {}
    for number, protocol in pairs(PROTOCOL_REGISTRY) do
        local name = protocol.name
        table.insert(array, {name = name, number = number,})
    end
    local message = yaml.dump(array)
    local hash = sha.sha1(message)

    return tonumber(hash:sub(1, 8), 16), hash -- return hash number and full hash
end

local setMultiplayerGameVersion = function()
    local hash = hashProtocols()
    log(VERBOSE, string.format("Setting game version to: %X", hash))
    writeMultiplayerGameVersion(hash)
end

return {
    setMultiplayerGameVersion = setMultiplayerGameVersion,
}
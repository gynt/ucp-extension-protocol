local common = require("protocols.common")

local argArrayMemoryMapping = {
  common.COMMAND_PARAM_0_ADDRESS,
  common.COMMAND_PARAM_1_ADDRESS,
  common.COMMAND_PARAM_2_ADDRESS,
  common.COMMAND_PARAM_3_ADDRESS,
  common.COMMAND_PARAM_4_ADDRESS,
  common.COMMAND_PARAM_5_ADDRESS,
}

---Write parameters to memory
---@param ... table|integer the parameters to write, can be tables and loose integers
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

return {
  setupInvocationParameters = setupInvocationParameters,
}
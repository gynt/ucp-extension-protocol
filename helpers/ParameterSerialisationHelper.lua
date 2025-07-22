
---Helper for serializing and deserializing invocation parameters
---@class ParameterSerialisationHelper
---@field public address number
---@field public offsetAddress number
local ParameterSerialisationHelper = {}

-- First parameter should be a table with address: o
function ParameterSerialisationHelper:new(o)
  local o = o or {
    address = nil,
    offsetAddress = nil,
  }

  -- this is to add methods of self to o. Self will be ParameterSerialisationHelper itself initially (but this pattern allows inheritance)
  setmetatable(o, self)
  
  -- this is for keys that aren't found in o, it will be searched in ParameterSerialisationHelper or a derived class.
  self.__index = self 

  return o
end

function ParameterSerialisationHelper:getOffset()
    return core.readInteger(self.offsetAddress)
end

function ParameterSerialisationHelper:setOffset(offset)
  return core.writeInteger(self.offsetAddress, offset)
end

function ParameterSerialisationHelper:serializeBytes(data)
  local o = self:getOffset()
  core.writeBytes(self.address + o, data)
  self:setOffset(o + #data)
end

function ParameterSerialisationHelper:deserializeBytes(size)
  local o = self:getOffset()
  local data = core.readBytes(self.address + o, size)
  self:setOffset(o + size)
  return data
end

function ParameterSerialisationHelper:serializeInteger(value)
  local o = self:getOffset()
  core.writeInteger(self.address + o, value)
  self:setOffset(o + 4)
end

function ParameterSerialisationHelper:deserializeInteger()
  local o = self:getOffset()
  local result = core.readInteger(self.address + o)
  self:setOffset(o + 4)

  return result
end

function ParameterSerialisationHelper:serializeSmallInteger(value)
  local o = self:getOffset()
  core.writeSmallInteger(self.address + o, value)
  self:setOffset(o + 2)
end

function ParameterSerialisationHelper:deserializeSmallInteger()
  local o = self:getOffset()
  local result = core.readSmallInteger(self.address + o)
  self:setOffset(o + 2)

  return result
end

function ParameterSerialisationHelper:serializeByte(value)
  local o = self:getOffset()
  core.writeByte(self.address + o, value)
  self:setOffset(o + 1)
end

function ParameterSerialisationHelper:deserializeByte()
  local o = self:getOffset()
  local result = core.readByte(self.address + o)
  self:setOffset(o + 1)

  return result
end

return ParameterSerialisationHelper
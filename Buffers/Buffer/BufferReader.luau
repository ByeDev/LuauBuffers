local replicatedStorage = game:GetService("ReplicatedStorage")

local bufferTypes = require(replicatedStorage.Shared.Modules.Buffer.BufferTypes)

type bufferReader = bufferTypes.bufferReader

local bufferReader = {}
bufferReader.__index = bufferReader

local SCALING_MAP_TO_U16 = 32767.5
local SIX_BITS = 63

local offsetValues = {
	i8 = 1,
	u8 = 1,
	i16 = 2,
	u16 = 2,
	f16 = 2,
	u24 = 3,
	i32 = 4,
	u32 = 4,
	f32 = 4,
	f64 = 8,
	V3 = 12,
	CF = 18,
}

local shiftValues = {1, 128, 16384, 2097152, 268435456, 34359738368, 4398046511104, 562949953421312, 72057594037927936, 9223372036854775808}



local DEFAULT_SIZE = 1024 

function bufferReader.new(inputBuffer : buffer?) : bufferReader
	local self = setmetatable({}, bufferReader)
	self.bytePositions  = 0
	self.buffer = inputBuffer or buffer.create(DEFAULT_SIZE)
	return self
end

local function zigZagDecode(value : number) : number
	return (value % 2 == 0) and (value // 2) or (-(value // 2) - 1)
end

local function readOneByteVLQ(self : bufferReader) : (number, boolean)
	local byte = buffer.readu8(self.buffer, self.bytePositions )
	self.bytePositions  += 1
	local value = byte % 128
	local keepReading = (byte >= 128)

	return value, keepReading
end

local function VLQReader(self : bufferReader, value : number, shiftIndex : number) : (number, boolean)
	local byte, keepReading = readOneByteVLQ(self)
	value += byte * shiftValues[shiftIndex]
	return value, keepReading
end

function bufferReader:readVarietyInt() : number
	local value = 0
	local keepReading 

	for i = 1, 9 do
		value, keepReading = VLQReader(self, value, i)
		if not keepReading then return zigZagDecode(value) end
	end

	value, keepReading = VLQReader(self, value, 10)
	return zigZagDecode(value)
end

function bufferReader:readi8() : number
	local offset = offsetValues.i8
	local value = buffer.readi8(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readu8() : number
	local offset = offsetValues.u8
	local value = buffer.readu8(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readi16() : number
	local offset = offsetValues.i16
	local value = buffer.readi16(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readu16() : number
	local offset = offsetValues.u16
	local value = buffer.readu16(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readf16()
	local lowerByte = self:readu8()
	local upperByte = self:readu8()
	local packedValue = lowerByte + (upperByte * 256)
	local sign = (packedValue >= 0x8000) and -1 or 1
	local exponent = math.floor((packedValue % 0x8000) / 1024)
	local biasedExponent = exponent - 15
	local mantissa = packedValue % 1024
	if exponent == 31 then
		if mantissa == 0 then
			return sign * math.huge
		else
			return 0 / 0
		end
	elseif exponent == 0 then
		if mantissa == 0 then
			return sign * 0
		else
			return sign * math.ldexp(mantissa / 1024, -14)
		end
	end
	local fraction = 1 + (mantissa / 1024)
	return sign * math.ldexp(fraction, biasedExponent)
end

function bufferReader:readu24() : number
	local offset = offsetValues.u24
	local u16 = buffer.readu16(self.buffer, self.bytePositions)
	local u8 = buffer.readu8(self.buffer, self.bytePositions + 2)
	self.bytePositions += offset
	local value = u16 * 256 + u8
	return value
end

function bufferReader:readi32() : number
	local offset = offsetValues.i32
	local value = buffer.readi32(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readu32() : number
	local offset = offsetValues.u32
	local value = buffer.readu32(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readf32() : number
	local offset = offsetValues.f32
	local value = buffer.readf32(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readf64() : number
	local offset = offsetValues.f64
	local value = buffer.readf64(self.buffer, self.bytePositions)
	self.bytePositions  += offset
	return value
end

function bufferReader:readV2() : Vector2
	local x = self:readf32()
	local y = self:readf32()
	return Vector2.new(x,y)
end

function bufferReader:readV3() : Vector3
	local x = self:readf32()
	local y = self:readf32()
	local z = self:readf32()
	return Vector3.new(x,y,z)
end

function bufferReader:readCFrame()
	local axisAligned = self:readu8()
	local x = self:readf32()
	local y = self:readf32()
	local z = self:readf32()
	if axisAligned == 1 then
		return CFrame.new(x, y, z)
	end
	local qX = (self:readu16() / SCALING_MAP_TO_U16) - 1
	local qY = (self:readu16() / SCALING_MAP_TO_U16) - 1
	local qZ = (self:readu16() / SCALING_MAP_TO_U16) - 1
	local w = math.sqrt(1 - qX^2 - qY^2 - qZ^2) 
	return CFrame.new(x, y, z, qX, qY, qZ, w)
end

function bufferReader:readString() : string
	local length = self:readVarietyInt()
	local string = buffer.readstring(self.buffer, self.bytePositions, length)
	self.bytePositions += length
	return string
end

local mapFunctions = {
	bufferReader.readi8,
	bufferReader.readu8,
	bufferReader.readi16,
	bufferReader.readu16,
	bufferReader.readi32,
	bufferReader.readu32,
	bufferReader.readf32,
	bufferReader.readf64,
	bufferReader.readString,
	bufferReader.readV2,
	bufferReader.readV3,
	bufferReader.readCFrame,
	bufferReader.readu24,
	bufferReader.readf16,
}

function bufferReader:readFloatIntArray<T>() : {T}
	local header = self:readu8()
	if header == SIX_BITS then
		header = header + self:readVarietyInt()
	end
	local array = {}
	for i = 1, header do
		local isFloat = self:readu8()
		if isFloat == 1 then
			array[i] = self:readf32()
		else
			array[i] = self:readVarietyInt()
		end
	end
	return array
end

function bufferReader:readStringArray()
	local length = self:readVarietyInt() 
	local array = {}

	for i = 1, length do
		table.insert(array, self:readString()) 
	end
	return array
end


function bufferReader:readDict(keyType, fieldType)
	local dict = {}

	local len = self:readVarietyInt()
	for i = 1, len do 
		local key = mapFunctions[keyType](self)
		local val = mapFunctions[fieldType](self)
		dict[key] = val
	end
	return dict
end

function bufferReader:readStructs(schema)
	if type(schema) == "number" then
		return mapFunctions[schema](self)
	elseif type(schema) == "table" then
		if #schema == 2 then
			local dictSize = self:readVarietyInt()
			local dict = {}
			for i = 1, dictSize do
				local dictKey = self:readStructs(schema[1])
				dict[dictKey] = self:readStructs(schema[2])
			end
			return dict
		else
			local subStruct = {}
			local subKeys = {}
			for subFieldName in schema do
				table.insert(subKeys, subFieldName)
			end
			table.sort(subKeys)

			for i, subFieldName in ipairs(subKeys) do
				subStruct[subFieldName] = self:readStructs(schema[subFieldName])
			end
			return subStruct
		end
	else
		error("Schema not recognized")
	end
end

function bufferReader:setBuffer(newBuffer: buffer)
	self.buffer = newBuffer
	self.bytePositions = 0
end

return bufferReader 

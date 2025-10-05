--optimize 2

-- written by jjz02 the goat himself 
local replicatedStorage = game:GetService("ReplicatedStorage")

local bufferTypes = require(replicatedStorage.Shared.Modules.Buffer.BufferTypes)

type bufferWriter = bufferTypes.bufferWriter

local bufferWriter = {}
bufferWriter.__index = bufferWriter

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
	V2 = 8,
	V3 = 12,
	CF = 18,
}

local subKeys = {}

local DEFAULT_SIZE = 1024
local BUFFER_EXPAND_RATE = 1.5

function bufferWriter.new(size: number?) : bufferWriter
	local self = setmetatable({}, bufferWriter)
	self.buffer = buffer.create(size or DEFAULT_SIZE)
	self.bytePositions = 0
	return self
end

local function spaceCheck(self : bufferWriter, bytesToCheck: number)
	local lengthOfBuffer = buffer.len(self.buffer)
	local bytePosition = self.bytePositions
	if lengthOfBuffer < (bytePosition + bytesToCheck) then
		if lengthOfBuffer == 0 then lengthOfBuffer = 1 end
		local exponent = math.ceil(math.log((bytePosition + bytesToCheck) / lengthOfBuffer, BUFFER_EXPAND_RATE))
		local newSize = lengthOfBuffer * (BUFFER_EXPAND_RATE ^ exponent)
		local newBuffer = buffer.create(newSize)
		buffer.copy(newBuffer, 0, self.buffer, 0, lengthOfBuffer)
		self.buffer = newBuffer
	end
end

local function zigZagEncode(number : number) : number
	return (number >= 0) and (number * 2) or (-number * 2 - 1)
end

local function writeOneByteVLQ(self : bufferWriter , value : number) : number?
	spaceCheck(self, 1)
	local byte = value % 128
	value = value // 128
	if value == 0 then
		buffer.writeu8(self.buffer, self.bytePositions, byte)
		self.bytePositions += 1
		return nil
	end
	buffer.writeu8(self.buffer, self.bytePositions, byte + 128)
	self.bytePositions += 1
	return value
end

local function hasDecimal(value)
	return value % 1 ~= 0
end

local function isAxisAligned(CF: CFrame) : (boolean)
	local tolerance = 1e-4
	local right = CF.XVector
	local up = CF.YVector
	local back = CF.ZVector

	local function isUnitAxis(vector)
		return math.abs(math.abs(vector.X) - 1) < tolerance or
			math.abs(math.abs(vector.Y) - 1) < tolerance or
			math.abs(math.abs(vector.Z) - 1) < tolerance
	end
	return isUnitAxis(right) and isUnitAxis(up) and isUnitAxis(back)
end

local function hasDeeperTable(value) : (boolean, number)
	if typeof(value) ~= "table" then return false, 0 end
	local count = 0;
	local containsTable = false
	for i, entry in value do
		if typeof(entry) == "table" then
			containsTable = true
			local _, subCount = hasDeeperTable(entry)
			count += 1 + subCount
		end
	end
	return containsTable, count
end

--vlq 8th bit is the flag of 0 1 to determine stop or continue
-- first bit reserved for zigzag
function bufferWriter:writeVarietyInt(integer : number)
	local value = zigZagEncode(integer)
	for i = 1, 10 do
		value = writeOneByteVLQ(self, value)
		if not value then return end
	end
end

function bufferWriter:writei8(value : number)
	local offset = offsetValues.i8
	spaceCheck(self, offset)
	buffer.writei8(self.buffer, self.bytePositions, value)
	self.bytePositions += offset
end

function bufferWriter:writeu8(value : number)
	local offset = offsetValues.u8
	spaceCheck(self, offset)
	buffer.writeu8(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writei16(value : number)
	local offset = offsetValues.i16
	spaceCheck(self, offset)
	buffer.writei16(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writeu16(value : number)
	local offset = offsetValues.u16
	spaceCheck(self, offset)
	buffer.writeu16(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

-- 1 bit sign, 4 bit biased exponent, 11 for mantissa, bias = 7, THE CUSTOM F16 IMPLEMENTION MWAHAHA 
-- not IEEE 754 STANDARD SO IM AMAZING
function bufferWriter:writef16(value: number)
	local offset = offsetValues.f16
	spaceCheck(self, offset)
	-- edgecases
	if value > 65504 then
		self:writeu8(251)
		self:writeu8(255)
		return
	elseif value < -65504 then
		self:writeu8(251)
		self:writeu8(127)
		return
	elseif value == math.huge then
		self:writeu8(252)
		self:writeu8(0)
		return
	elseif value == -math.huge then
		self:writeu8(252)
		self:writeu8(128)
		return
	elseif math.abs(value) < 5.96e-8 then
		self:writeu8(0)
		self:writeu8(if value < 0 then 128 else 0)
		return
	end
	local sign = (value < 0) and 32768 or 0
	value = math.abs(value)
	local rawExponent = math.floor(math.log(value) / math.log(2))
	local exponent = rawExponent + 15
	local normalizedValue = value / (2 ^ rawExponent)
	local mantissa = math.floor((normalizedValue - 1) * 1024) % 1024
	local packedValue = sign + (exponent * 1024) + mantissa
	self:writeu8(packedValue % 256)
	self:writeu8(math.floor(packedValue / 256))
end

function bufferWriter:writeu24(value : number)
	local offset = offsetValues.u24 
	spaceCheck(self, offset)
	local hi16 = math.floor(value / 256)
	local lo8  = value % 256
	buffer.writeu16(self.buffer, self.bytePositions, hi16)
	buffer.writeu8(self.buffer, self.bytePositions + 2, lo8)
	self.bytePositions += offset 
end


function bufferWriter:writei32(value : number)
	local offset = offsetValues.i32
	spaceCheck(self, offset)
	buffer.writei32(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writeu32(value : number)
	local offset = offsetValues.u32
	spaceCheck(self, offset)
	buffer.writeu32(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writef32(value : number)
	local offset = offsetValues.f32
	spaceCheck(self, offset)
	buffer.writef32(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writef64(value : number)
	local offset = offsetValues.f64
	spaceCheck(self, offset)
	buffer.writef64(self.buffer, self.bytePositions , value)
	self.bytePositions  += offset
end

function bufferWriter:writeV2(value: Vector2)
	spaceCheck(self, offsetValues.V2)
	self:writef32(value.X)
	self:writef32(value.Y)
end

function bufferWriter:writeV3(value: Vector3)
	spaceCheck(self, offsetValues.V3)
	self:writef32(value.X)
	self:writef32(value.Y)
	self:writef32(value.Z)
end

-- changed to send quaternion so I stop getting bullied :D
function bufferWriter:writeCFrame(value: CFrame)
	local axisAligned = isAxisAligned(value) and 1 or 0
	self:writeu8(axisAligned)
	self:writef32(value.X)
	self:writef32(value.Y)
	self:writef32(value.Z)
	if axisAligned == 1 then
		return
	end
	local axis, theta = value:ToAxisAngle()
	local sinHalfTheta = math.sin(theta / 2)
	local qX = math.floor((axis.X * sinHalfTheta + 1) * SCALING_MAP_TO_U16)
	local qY = math.floor((axis.Y * sinHalfTheta + 1) * SCALING_MAP_TO_U16)
	local qZ = math.floor((axis.Z * sinHalfTheta + 1) * SCALING_MAP_TO_U16)
	self:writeu16(qX)
	self:writeu16(qY)
	self:writeu16(qZ)
end

function bufferWriter:writeString(value: string)
	local length = #value
	self:writeVarietyInt(length)
	spaceCheck(self, length)
	buffer.writestring(self.buffer, self.bytePositions, value)
	self.bytePositions += length
end

-- this is just for the following functions
local mapFunctions = {
	bufferWriter.writei8,
	bufferWriter.writeu8,
	bufferWriter.writei16,
	bufferWriter.writeu16,
	bufferWriter.writei32,
	bufferWriter.writeu32,
	bufferWriter.writef32,
	bufferWriter.writef64,
	bufferWriter.writeString,
	bufferWriter.writeV2,
	bufferWriter.writeV3,
	bufferWriter.writeCFrame,
	bufferWriter.writeu24,
	bufferWriter.writef16,
}

function bufferWriter:writeFloatIntArray<T>(array : {T})
	local length = #array
	local header = math.min(length, SIX_BITS)
	self:writeu8(header)
	if length > SIX_BITS then
		self:writeVarietyInt(length - SIX_BITS)
	end
	for i, value in array do
		local isFloat = hasDecimal(value) and 1 or 0
		self:writeu8(isFloat)
		if isFloat == 1 then
			self:writef32(value)
		else
			self:writeVarietyInt(value)
		end
	end
end

function bufferWriter:writeStringArray(array: {string})
	local length = #array
	self:writeVarietyInt(length)

	for i, value in array do
		self:writeString(value) 
	end
end

-- use only for unknown entries in the table
-- keep in mind order is not guranteed for writedict, uesd for tables with dynamic value keys and samevaluetype
function bufferWriter:writeDict(keyType: number, valueType: number, dict: {[any]: any})
	local dictSize = 0
	for i in dict do
		dictSize += 1
	end
	self:writeVarietyInt(dictSize)
	for i, value in dict do
		mapFunctions[keyType](self, i)
		mapFunctions[valueType](self, value)
	end
end

-- roblox num 9 bytes, string #str + 2
-- no static keys are written :D save them bytes bois
function bufferWriter:writeStructs(schema, data)
	if type(schema) == "number" then
		local writer = mapFunctions[schema]
		writer(self, data)
	elseif type(schema) == "table" then
		if #schema == 2 then
			local size = 0
			for _ in data do
				size += 1
			end
			self:writeVarietyInt(size)
			for dictKey, dictVal in data do
				if type(schema[1]) == "number" then
					local writer = mapFunctions[schema[1]]
					writer(self, dictKey)
				else
					self:writeStructs(schema[1], dictKey)
				end
				if type(schema[2]) == "number" then
					local writer = mapFunctions[schema[2]]
					writer(self, dictVal)
				else
					self:writeStructs(schema[2], dictVal)
				end
			end
		else
			local subKeys = {}
			for subName in schema do
				table.insert(subKeys, subName)
			end
			table.sort(subKeys)
			for _, subName in subKeys do
				local subValue = data[subName]
				if subValue ~= nil then
					local subSchema = schema[subName]
					if type(subSchema) == "number" then
						local writer = mapFunctions[subSchema]
						writer(self, subValue)
					else
						self:writeStructs(subSchema, subValue)
					end
				end
			end
		end
	end
end

function bufferWriter:createBuffer() : buffer
	local usedBytes = self.bytePositions
	local newBuffer = buffer.create(usedBytes)
	buffer.copy(newBuffer, 0, self.buffer, 0, usedBytes)
	self.bytePositions = 0
	return newBuffer
end

function bufferWriter:clear()
	self.bytePositions = 0
end

return bufferWriter 

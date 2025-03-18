local bufferStructs = {}

-- these have to match exactly of array index when mapped so dont change value randomly, ill reorganize the u24,f16 later :D
bufferStructs.bufferValueTypes = {
	i8 = 1,
	u8 = 2,
	i16 = 3,
	u16 = 4,
	i32 = 5,
	u32 = 6,
	f32 = 7,
	f64 = 8,
	str = 9,
	V2 = 10,
	V3 = 11,
	CF = 12,
	u24 = 13,
	f16 = 14,
}

local i8 = bufferStructs.bufferValueTypes.i8
local u8 = bufferStructs.bufferValueTypes.u8
local i16 = bufferStructs.bufferValueTypes.i16
local u16 = bufferStructs.bufferValueTypes.u16
local i32 = bufferStructs.bufferValueTypes.i32
local u32 = bufferStructs.bufferValueTypes.u32
local f32 = bufferStructs.bufferValueTypes.f32
local f64 = bufferStructs.bufferValueTypes.f64
local str = bufferStructs.bufferValueTypes.str
local V2 = bufferStructs.bufferValueTypes.V2
local V3 = bufferStructs.bufferValueTypes.V3
local CF = bufferStructs.bufferValueTypes.CF
local u24 = bufferStructs.bufferValueTypes.u24
local f16 = bufferStructs.bufferValueTypes.f16

local function dict(keyType, valueType)
	return { keyType, valueType }
end

local function arrayOf(subStruct, indexType)
	return { indexType, subStruct }
end

bufferStructs.exampleDict = {
	typeOfKey = str,
	typeOfValue = i32,
}

-- REMINDER: FIX STRUCTS
-- combat struct for mr clubs game to test - finished
bufferStructs.travelersClubCombat = {
	Id = i8,
	Name = str,
	Table1 = dict(str,f32),
	Table2 = dict(str,f32),
	Level = u16,
	Exp = u32,
	Attribute = str,
	Type = str,
	Rank = str,
	Table3 = {
		Damage = u32,
		Level = u16,
		Icon = str,
		WaitVal = u8,
		Type = str,
	},
}

bufferStructs.playerData = {
	tokens = u24,
    scarebux = u24,
    level = u16,
    skins = dict(str,u8),
    wins = u24,
    losses = u24,
    achievements = dict(str,u8),
    passes = dict(str,u8),
}

bufferStructs.characterReplication = {
	writtenCFrame = CF,
	timeStamp = f32,
}

bufferStructs.characterReplicationClient = {
	player = u8,
	writtenCFrame = CF,
	originalTime = f32,
}

return bufferStructs
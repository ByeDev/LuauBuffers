local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local network = require(ReplicatedStorage.Network)
local BufferWriter = require(ReplicatedStorage.Buffers.BufferWriter).new()
local BufferReader = require(ReplicatedStorage.Buffers.BufferReader).new()
local bufferStructs = require(ReplicatedStorage.Buffers.BufferStructs)
local snapShot = require(ReplicatedStorage.Snapshot)

local infoStruct = bufferStructs.characterReplication
local clientStruct = bufferStructs.characterReplicationClient

local activePlayers = {} 
local playerPositions = {} 
local playerInfos = {}
local lastSentInfos = {}

local PROXIMITY_THRESHOLD = 20

local timeSpent = 0
local tickRate = 1/40

local function prepData(player, playerInfo)
	local preparedData = {
		player = snapShot.getPlayerValue(player),
		writtenCFrame = playerInfo.writtenCFrame,
		originalTime = playerInfo.timeStamp
	}
	return preparedData
end

local function proximityDetermination()
	for playerA, posA in playerPositions do
		if not activePlayers[playerA] then continue end
		if lastSentInfos[playerA] ~= playerInfos[playerA].originalTime then
			BufferWriter:clear()
			BufferWriter:writeStructs(clientStruct, playerInfos[playerA])
			local madeBuffer = BufferWriter:createBuffer()
			for playerB, posB in playerPositions do
				if activePlayers[playerB] and playerA ~= playerB and (posA - posB).Magnitude <= PROXIMITY_THRESHOLD then
					network:fireUnreliableClient("CharacterReplication", playerB, madeBuffer)
				end
			end
			lastSentInfos[playerA] = playerInfos[playerA].originalTime
		end
	end
end

network:bindUnreliableServerEvent("CharacterReplication", function(player, writtenBuffer)
	BufferReader:setBuffer(writtenBuffer)
	local info = BufferReader:readStructs(infoStruct)
	print(info)
	playerPositions[player] = info.writtenCFrame.Position
	playerInfos[player] = prepData(player, info)
end)

network:bindServerEvent("RequestCharacterReplication", function(player)
	activePlayers[player] = true
end)

RunService.Heartbeat:Connect(function(dt)
	timeSpent += dt 
	if timeSpent >= tickRate then
		timeSpent -= tickRate 
		proximityDetermination()
	end
end)

local function setUpSnapShot()
	for i, player in Players:GetPlayers() do
		snapShot.addPlayer(player)
	end
	BufferWriter:writeDict(9, 2, snapShot.getMapping())
	local madeBuffer = BufferWriter:createBuffer()
	network:fireAllClients("SnapShot", madeBuffer)
end

setUpSnapShot()

Players.PlayerAdded:Connect(function(player)
	snapShot.addPlayer(player)
	BufferWriter:writeDict(9, 2, snapShot.getMapping())
	local madeBuffer = BufferWriter:createBuffer()
	network:fireAllClients("SnapShot", madeBuffer)
end)

Players.PlayerRemoving:Connect(function(player)
	snapShot.removePlayer(player)
end)





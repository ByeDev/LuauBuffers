local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local bufferWriter = require(ReplicatedStorage.BufferWriter).new()
local bufferReader = require(ReplicatedStorage.BufferReader).new()
local bufferStructs = require(ReplicatedStorage.BufferStructs)
local network = require(ReplicatedStorage.network)
local playerMap = require(ReplicatedStorage.PlayerMap)
local lagCompensation = require(ReplicatedStorage.LagCompensation)

local clientCFrameStruct = bufferStructs.characterReplication

local mapping = {}
local playerData = {}
local lastCFrames = {}
local lastUpdateTimes = {}
local lastSentTimes = {}
local readyPlayers = {}

local TICK_RATE = 1 / 20
local LOAD_BUFFER = 0.5

local lastTick = 0
local serverProcessingTime = 0

local function disableReplication(player)
	if not player then return end
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")
	task.wait(LOAD_BUFFER)
	rootPart.Anchored = true
	playerMap.addPlayer(player.Name)
	mapping = playerMap.getPlayers()
	bufferWriter:clear()
	bufferWriter:writeDict(9, 2, mapping)
	local bufferMade = bufferWriter:createBuffer()
	network:fireClient("Onjoin", player, bufferMade)
	for _, existingPlayer in Players:GetPlayers() do
		if existingPlayer ~= player then
			network:fireClient("Onjoin", existingPlayer, bufferMade)
		end
	end
end

local function isValidMovement(player, newCFrame)
	local character = player.Character
	if not character then return false end
	local rootPart = character.HumanoidRootPart
	if not rootPart then return false end
	local lastCFrame = lastCFrames[player.Name]
	local lastTime = lastUpdateTimes[player.Name]
	local currentTime = os.clock()
	local humanoid = character.Humanoid
	local maxSpeed =  humanoid.WalkSpeed
	if not lastCFrame or not lastTime then
		lastCFrames[player.Name] = newCFrame
		lastUpdateTimes[player.Name] = currentTime
		return true
	end
	local deltaTime = currentTime - lastTime
	if math.abs(deltaTime) <= 0 then return false end
	local distance = (newCFrame.Position - lastCFrame.Position).Magnitude
	local speed = distance / deltaTime
	if speed > maxSpeed * 1.5 then
		return false
	end
	lastCFrames[player.Name] = newCFrame
	lastUpdateTimes[player.Name] = currentTime
	return true
end

local function storeValidPlayerPositions()
	for playerName, lastCFrame in lastCFrames do
		local player = Players:FindFirstChild(playerName)
		if player and mapping[playerName] then
			local storedTimeStamp = lastUpdateTimes[playerName]
			if storedTimeStamp then
				lagCompensation.addSnapshot(player.Name, storedTimeStamp, lastCFrame)
			end
		end
	end
end

local function createReplicationDataForPlayer(player)
	local replicationData = {}
	for playerName, lastCFrame in lastCFrames do
		if playerName ~= player.Name then 
			local targetPlayer = Players:FindFirstChild(playerName)
			if targetPlayer and mapping[playerName] then
				local lastTime = lastUpdateTimes[playerName]
				if lastSentTimes[playerName] == lastTime then
					continue
				end
				table.insert(replicationData, {player = mapping[playerName], cframe = lastCFrame, timeStamp = lastTime})
				lastSentTimes[playerName] = lastTime
			end
		end
	end
	return replicationData
end

local function broadcastPlayerPositions()
	for player, isReady in readyPlayers do
		if isReady then
			local replicationData = createReplicationDataForPlayer(player)
			if #replicationData > 0 then
				bufferWriter:clear()
				bufferWriter:writeStructs(bufferStructs.playerReplicationTable, replicationData)
				local bufferMade = bufferWriter:createBuffer()
				network:fireUnreliableClient("UpdatePlayerPositions", player, bufferMade)
			end
		end
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(disableReplication, player)
end

network:bindServerEvent("ReadyToReceive", function(player)
	if not player then return end
	readyPlayers[player] = true
	network:fireClient("OnUnanchor", player)
end)

network:bindUnreliableServerEvent("PlayerCFrame", function(player, data)
	bufferReader:setBuffer(data)
	local cframeData = bufferReader:readStructs(clientCFrameStruct)
	if isValidMovement(player, cframeData.cframe) then
		lastCFrames[player.Name] = cframeData.cframe
		lastUpdateTimes[player.Name] = cframeData.timeStamp
	else
		warn("Invalid movement detected for", player.Name)
	end
end)

Players.PlayerAdded:Connect(function(player)
	playerData[player.Name] = {}
	player.CharacterAdded:Connect(function()
		task.wait(LOAD_BUFFER)
		disableReplication(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	readyPlayers[player] = nil
	playerData[player.Name] = nil
	lastCFrames[player.Name] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = time()
	if now - lastTick >= TICK_RATE then
		lastTick = now
		local startTime = os.clock()
		storeValidPlayerPositions()
		broadcastPlayerPositions()
		serverProcessingTime = os.clock() - startTime
	end
end)

network:bindServerEvent("RequestServerProcess", function(player)
	network:fireClient("ReceiveServerProcess", player, serverProcessingTime)
end)

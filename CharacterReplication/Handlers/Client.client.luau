local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local network = require(ReplicatedStorage.network)
local bufferReader = require(ReplicatedStorage.BufferReader).new()
local bufferWriter = require(ReplicatedStorage.BufferWriter).new()
local bufferStructs = require(ReplicatedStorage.BufferStructs)
local SnapShots = require(ReplicatedStorage.SnapShots).new()

local clientInputSendStruct = bufferStructs.characterReplication
local serverWriteStruct = bufferStructs.playerReplicationTable

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local HRP = character:WaitForChild("HumanoidRootPart")

local mappingReversed = {}
local dataToSend = {}
local targetCFrames = {}
local receivedFirstSnapshot = {}

local LOAD_TIME = 2
local LOAD_BUFFER = 1
local CFRAME_THRESHOLD = 0.01
local SEND_RATE = 1 / 60
local INTERPOLATION_DELAY = 1/30

local serverProcess = 0
local lastSentCFrame = HRP.CFrame

local function unanchorCharacter()
	task.wait(LOAD_BUFFER)
	HRP.Anchored = false
end

network:bindClientEvent("OnUnanchor", unanchorCharacter)

network:bindClientEvent("Onjoin", function(data)
	bufferReader:setBuffer(data)
	local dataRead = bufferReader:readDict(9, 2)
	mappingReversed = {}
	for playerName, assignedNumber in dataRead do
		mappingReversed[assignedNumber] = playerName
	end
end)

local function readyCheck()
	for i = 1, 3 do
		local character = player.Character or player.CharacterAdded:Wait()
		if character then
			network:fireServer("ReadyToReceive")
			return
		else
			task.wait(LOAD_TIME * i)
		end
	end
end

local function determineSend(CF1, CF2)
	local delta = CF1:Inverse() * CF2 
	if delta.Position.Magnitude > CFRAME_THRESHOLD then
		return true
	end
	local rx, ry, rz = delta:ToEulerAnglesYXZ() 
	local angleDelta = math.abs(rx) + math.abs(ry) + math.abs(rz)
	return angleDelta > CFRAME_THRESHOLD
end

local function sendCFrame()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local newCFrame = rootPart.CFrame
	if not determineSend(lastSentCFrame, newCFrame) then
		return
	end
	local timeStamp = workspace:GetServerTimeNow()
	dataToSend = { cframe = newCFrame, timeStamp = timeStamp }
	bufferWriter:writeStructs(clientInputSendStruct, dataToSend)
	local bufferMade = bufferWriter:createBuffer()
	network:fireUnreliableServer("PlayerCFrame", bufferMade)
	lastSentCFrame = newCFrame
end

local function updatePlayerPositions(data)
	bufferReader:setBuffer(data)
	local info = bufferReader:readStructs(serverWriteStruct)
	local ping = network:getPing(player)
	local targetTime = workspace:GetServerTimeNow() - SEND_RATE - (ping * 2)  - serverProcess - INTERPOLATION_DELAY
	for i, playerData in info do
		local playerName = mappingReversed[playerData.player]
		local timestamp = playerData.timeStamp
		local cframe = playerData.cframe
		SnapShots:addSnapshot(playerName, timestamp, cframe)
		if not receivedFirstSnapshot[playerName] then
			receivedFirstSnapshot[playerName] = cframe
			continue
		end
		local interpolatedCFrame = SnapShots:interpolate(playerName, targetTime)
		if interpolatedCFrame then
			targetCFrames[playerName] = interpolatedCFrame
		end
	end
end

function updatePlayerCFrames()
	for playerName, interpolatedCFrame in targetCFrames do
		if playerName == player.Name then continue end
		local character = Players:FindFirstChild(playerName) and Players[playerName].Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = interpolatedCFrame
			end
		end
	end
end

player.CharacterAdded:Connect(function()
	task.wait(LOAD_BUFFER)
	unanchorCharacter()
end)

readyCheck()

network:bindUnreliableClientEvent("UpdatePlayerPositions", function(data)
	bufferReader:setBuffer(data)
	local info = bufferReader:readStructs(serverWriteStruct)
	print(info)
	for _, playerData in info do
		local playerName = mappingReversed[playerData.player]
		local timestamp = playerData.timeStamp
		local cframe = playerData.cframe

		SnapShots:addSnapshot(playerName, timestamp, cframe)
	end
end)

network:bindUnreliableClientEvent("UpdatePlayerPositions", updatePlayerPositions)

network:bindClientEvent("ReceiveServerProcess", function(time)
	serverProcess = time
end)

RunService.PostSimulation:Connect(function()
	sendCFrame()
	updatePlayerCFrames()
end)

task.spawn(function()
	while true do
		network:fireServer("RequestServerProcess")
		task.wait(5)
	end
end)
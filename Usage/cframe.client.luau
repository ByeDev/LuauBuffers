local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local HRP = character:WaitForChild("HumanoidRootPart")

local network = require(ReplicatedStorage.Network)
local bufferWriter = require(ReplicatedStorage.Buffers.BufferWriter).new()
local bufferReader = require(ReplicatedStorage.Buffers.BufferReader).new()
local bufferStructs = require(ReplicatedStorage.Buffers.BufferStructs)
local snapShot = require(ReplicatedStorage.Snapshot)

local infoStruct = bufferStructs.characterReplication
local clientStruct = bufferStructs.characterReplicationClient

local LOAD = 3
local CFRAME_THRESHOLD = 0.01
local INTERPOLATION_DELAY = 1/10
local TICK_RATE = 1 / 40

local lastCFrame = HRP.CFrame
local firstRun = true
local timeSpent = 0

local playerMapping = {}
local timeComparisons = {}
local collectedCFrames = {}

local playerRenderData = {}

local function determineSend(CF1, CF2)
	local delta = CF1:Inverse() * CF2 
	if delta.Position.Magnitude > CFRAME_THRESHOLD then
		return true
	end
	local rx, ry, rz = delta:ToEulerAnglesYXZ() 
	local angleDelta = math.abs(rx) + math.abs(ry) + math.abs(rz)
	return angleDelta > CFRAME_THRESHOLD
end

function checkReadiness()
	for i = 1, 3 do
		if HRP then 
			network:fireServer("RequestCharacterReplication") 
			break
		else
			task.wait(LOAD * i)
		end
	end
end

local function getEstimatedServerTime(player)
	local cache = timeComparisons[player]
	if not cache or not cache.ogTime or not cache.receiveTime then 
		return os.clock() 
	end
	return cache.ogTime + (os.clock() - cache.receiveTime)
end

local function findPlayerValue(player)
	for i, value in playerMapping do
		if value == player then
			if not playerRenderData[value] then
				playerRenderData[value] = {
					nextRenderTime = nil,
					lastReceivedTimestamp = 0,
					lastClientClock = 0
				}
			end
			return i
		end
	end 
end

local function updateTimeComparisons(player, ogTime, receiveTime)
	timeComparisons[player] = {
		ogTime = ogTime,
		receiveTime = receiveTime
	}
end

local function lerpCorrection(playerHRP, targetCF)
	local currentCF = playerHRP.CFrame
	local currentPos = currentCF.Position
	local targetPos = targetCF.Position
	local errorMagnitude = (currentPos - targetPos).Magnitude
	local lerpFactor = math.clamp(errorMagnitude * 0.1, 0.3, 0.9) 
	playerHRP.CFrame = currentCF:Lerp(targetCF, lerpFactor)
end

checkReadiness()

RunService.PostSimulation:Connect(function(dt)
	timeSpent += dt 
	if timeSpent >= TICK_RATE then
		timeSpent -= TICK_RATE 
		local HRPCF = HRP.CFrame
		if determineSend(lastCFrame, HRPCF) or firstRun then
			lastCFrame = HRPCF
			firstRun = false
			local sendData = {
				writtenCFrame = HRPCF,
				timeStamp = os.clock()
			}
			bufferWriter:writeStructs(infoStruct, sendData)
			local madeBuffer = bufferWriter:createBuffer()
			network:fireUnreliableServer("CharacterReplication", madeBuffer)
		end
		for player, CF in collectedCFrames do
			local character = player.Character
			if not character then continue end
			local playerHRP = character.HumanoidRootPart
			if not playerHRP then continue end
			lerpCorrection(playerHRP, CF)
		end
		collectedCFrames = {}
	end
end)

network:bindUnreliableClientEvent("CharacterReplication", function(info)
	bufferReader:setBuffer(info)
	local readInfo = bufferReader:readStructs(clientStruct)
	local player = findPlayerValue(readInfo.player)
	if not playerRenderData[player] then
		playerRenderData[player] = {
			nextRenderTime = nil,
			lastReceivedTimestamp = 0,
			lastClientClock = 0
		}
	end
	local renderData = playerRenderData[player]
	local currentTimestamp = readInfo.originalTime
	if currentTimestamp > renderData.lastReceivedTimestamp then
		renderData.lastClientClock = os.clock()
		renderData.lastReceivedTimestamp = currentTimestamp
	else
		return
	end
	if not renderData.nextRenderTime then
		local estimatedServerTime = getEstimatedServerTime(player)
		renderData.nextRenderTime = estimatedServerTime - INTERPOLATION_DELAY
	end
	snapShot.addSnapShot(player, readInfo)
	collectedCFrames[player] = snapShot.interpolateSnapShot(player, renderData.nextRenderTime)
	renderData.nextRenderTime += TICK_RATE 
	updateTimeComparisons(player, readInfo.timeStamp, os.clock())
	print(readInfo)
end)

network:bindClientEvent("SnapShot", function(mapping)
	bufferReader:setBuffer(mapping)
	local info = bufferReader:readDict(9, 2)
	playerMapping = info
	print(info)
end)

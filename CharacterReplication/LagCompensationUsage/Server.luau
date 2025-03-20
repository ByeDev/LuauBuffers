local ReplicatedStorage = game:GetService("ReplicatedStorage")

local network = require(ReplicatedStorage.network)
local bufferReader = require(ReplicatedStorage.BufferReader).new()
local bufferStructs = require(ReplicatedStorage.BufferStructs)
local lagCompensation = require(ReplicatedStorage.LagCompensation)

local clientStruct = bufferStructs.attackSendClient

local MAX_TIME_DIFFERENCE = 1.5
local MAX_HITBOX_THRESHOLD = Vector3.new(10,10,10)

network:bindServerEvent("Attack", function(player, data)
	bufferReader:setBuffer(data)
	local info = bufferReader:readStructs(clientStruct)
	print(info)
	local attackTime = info.attackTime
	local attackSize = info.attackSize
	if typeof(attackSize) ~= "Vector3" or attackSize.Magnitude > MAX_HITBOX_THRESHOLD.Magnitude then
		return
	end
	local serverTime = workspace:GetServerTimeNow()
	if math.abs(serverTime - attackTime) > MAX_TIME_DIFFERENCE then
		return
	end
	local character = player.Character
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	local attackDirection = info.attackDirection
	local confirmedHits = lagCompensation.performAttack(player, attackTime, attackDirection, attackSize)
	-- ^ returns the players that are validated from server after just add here whatever you wana do if there are discprencies for adjugstments 
    -- or alternatively just pass that its valid and do the server adjustments on health and stuff 
end)

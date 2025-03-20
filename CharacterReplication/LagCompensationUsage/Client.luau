local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local bufferWriter = require(ReplicatedStorage.BufferWriter).new()
local bufferStructs = require(ReplicatedStorage.BufferStructs)
local network = require(ReplicatedStorage.network)

local clientSendStruct = bufferStructs.attackSendClient

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local HRP = character.HumanoidRootPart
local mouse = player:GetMouse()

local hitPlayersDict = {}
local hitPlayers = {}

local function onMouseClick()
	if not character or not HRP then return end
	local attackDirection = HRP.CFrame.LookVector
	local attackSize = Vector3.new(4, 4, 4)
	local attackTime = workspace:GetServerTimeNow()
	local attackCFrame = HRP.CFrame + (attackDirection * (attackSize.Z / 2))
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local hitParts = Workspace:GetPartBoundsInBox(attackCFrame, attackSize, overlapParams)
    -- no time to do this myself but u just add react immediately on client for instant feedback before sending validation 
    
	hitPlayersDict = {}
	for _, part in hitParts do
		local hitCharacter = part.Parent
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
		if hitPlayer and hitPlayer ~= player then
			local targetRoot = hitCharacter:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local distance = (targetRoot.Position - attackCFrame.Position).Magnitude
				if distance <= attackSize.Magnitude / 2 then
					hitPlayersDict[hitPlayer.Name] = true
				end
			end
		end
	end
	hitPlayers = {}
	for playerName in hitPlayersDict do
		table.insert(hitPlayers, playerName)
	end
	local attackData = {attackTime = attackTime, attackSize = attackSize, attackDirection = attackDirection, hitPlayers = hitPlayers}
	bufferWriter:writeStructs(clientSendStruct, attackData)
	local bufferMade = bufferWriter:createBuffer()
	network:fireServer("Attack", bufferMade)
end

mouse.Button1Down:Connect(onMouseClick)

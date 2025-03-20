local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local circularBuffer = require(ReplicatedStorage.CircularBuffer)

local lagCompensation = {}
lagCompensation.__index = lagCompensation

lagCompensation.visualizationEnabled = false 

local MAX_SHOTS = 10

local snapShots = {}

local function getInterpolatedCFrame(playerName, timestamp)
	local prevSnap, nextSnap = lagCompensation.getClosestSnapshots(playerName, timestamp)
	if not prevSnap then return nil end
	if not nextSnap then return prevSnap.cframe end
	local timeDiff = nextSnap.timestamp - prevSnap.timestamp
	local alpha = (timeDiff > 0) and ((timestamp - prevSnap.timestamp) / timeDiff) or 0
	return prevSnap.cframe:Lerp(nextSnap.cframe, math.clamp(alpha, 0, 1))
end

function lagCompensation.checkHits(attacker, timestamp, attackDirection, hitboxSize)
	local attackerCFrame = getInterpolatedCFrame(attacker.Name, timestamp)
	if not attackerCFrame then return {} end
	local attackPosition = attackerCFrame.Position + (attackDirection * (hitboxSize.Z / 2))
	local attackCFrame = CFrame.new(attackPosition, attackPosition + attackDirection)
	local hitCharacters = {}
	for playerName, _ in snapShots do
		if playerName ~= attacker.Name then
			local targetCFrame = getInterpolatedCFrame(playerName, timestamp)
			if targetCFrame then
				local targetPosition = targetCFrame.Position
				local relativePosition = attackCFrame:PointToObjectSpace(targetPosition)
				local halfSize = hitboxSize / 2
				if math.abs(relativePosition.X) <= halfSize.X and
					math.abs(relativePosition.Y) <= halfSize.Y and
					math.abs(relativePosition.Z) <= halfSize.Z then
					hitCharacters[playerName] = true
				end
			end
		end
	end
	local hitCharacterNames = {}
	for characterName in hitCharacters do
		table.insert(hitCharacterNames, characterName)
	end
	return hitCharacterNames
end

function lagCompensation.performAttack(attacker, timestamp, attackDirection, hitboxSize)
	if lagCompensation.visualizationEnabled then
		local attackerCFrame = getInterpolatedCFrame(attacker.Name, timestamp)
		if attackerCFrame then
			local attackPosition = attackerCFrame.Position + (attackDirection * (hitboxSize.Z / 2))
			lagCompensation.visualizeAttack(attackPosition, attackDirection, hitboxSize)
		end
	end
	return lagCompensation.checkHits(attacker, timestamp, attackDirection, hitboxSize)
end

function lagCompensation.visualizeAttack(attackPosition, attackDirection, hitboxSize)
	local attackCFrame = CFrame.new(attackPosition, attackPosition + attackDirection)
	local debugPart = Instance.new("Part")
	debugPart.Size = hitboxSize
	debugPart.CFrame = attackCFrame
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.Transparency = 0.5
	debugPart.BrickColor = BrickColor.new("Bright red")
	debugPart.Parent = Workspace
	task.delay(1, function()
		debugPart:Destroy()
	end)
end

function lagCompensation.addSnapshot(playerName, timestamp, cframe)
		if not snapShots[playerName] then
			snapShots[playerName] = circularBuffer.new(MAX_SHOTS)
		end
		snapShots[playerName]:addSnapshot(timestamp, cframe) 
end

function lagCompensation.getClosestSnapshots(playerName, targetTime)
	local buffer = snapShots[playerName]
	if not buffer then return nil, nil end
	local snapshots = buffer:getSnapShots()
	if #snapshots == 0 then return nil, nil end
	local prevSnap, nextSnap = nil, nil
	for i = 1, #snapshots do
		local snap = snapshots[i]
		if snap.timestamp <= targetTime then
			prevSnap = snap
		end
		if snap.timestamp > targetTime then
			nextSnap = snap
			break
		end
	end
	return prevSnap, nextSnap
end

function lagCompensation.getTrackedPlayers()
	return snapShots
end

return lagCompensation

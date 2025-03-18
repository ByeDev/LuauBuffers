local MAX_SNAPSHOTS = 10

local currentCounter = 1

local snapShot = {}
local snapShots = {}
local playerMapping = {}

local function return2Closest(playerSnapShots, target)
	if not playerSnapShots or #playerSnapShots == 0 then
		return nil, nil
	end
	local start, tableEnd = 1, #playerSnapShots
	local before, after = nil, nil
	while start <= tableEnd do
		local mid = math.floor((start + tableEnd) / 2)
		local snapShot = playerSnapShots[mid]
		if snapShot.originalTime < target then
			before = snapShot
			start = mid + 1
		else
			after = snapShot
			tableEnd = mid - 1
		end
	end
	return before, after
end

function snapShot.addPlayer(player)
	if snapShots[player.Name] then return end
	snapShots[player.Name] = {}
	playerMapping[player.Name] = currentCounter
	currentCounter += 1
end

function snapShot.removePlayer(player)
	if not snapShots[player.Name] then return end
	snapShots[player.Name] = nil
	for id, mappedPlayer in playerMapping do
		if mappedPlayer == player.Name then
			playerMapping[id] = nil 
			break
		end
	end
	currentCounter -= 1
end

function snapShot.addSnapShot(player, info)
	if not snapShots[player] then
		snapShots[player] = {}
	end
	local snapshots = snapShots[player]
	local low, high = 1, #snapshots
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if snapshots[mid].originalTime < info.originalTime then
			low = mid + 1
		else
			high = mid - 1
		end
	end
	table.insert(snapshots, low, info)
	if #snapshots > MAX_SNAPSHOTS then
		table.remove(snapshots, 1)
	end
end

function snapShot.getMapping()
	return playerMapping
end

function snapShot.interpolateSnapShot(player, targetTime)
	local playerSnapShots = snapShots[player]
	if not playerSnapShots then return nil end
	local before, after = return2Closest(playerSnapShots, targetTime)
	if not before then
		return after and after.writtenCFrame or nil
	end
	if not after then
		return before.writtenCFrame
	end
	local alpha = (targetTime - before.originalTime) / (after.originalTime - before.originalTime)
	return before.writtenCFrame:Lerp(after.writtenCFrame, alpha)
end

function snapShot.getPlayerValue(player)
	return playerMapping[player.Name]
end

return snapShot
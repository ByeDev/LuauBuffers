local playerMap = {}
local indexMap = {}  
local counter = 1 

function playerMap.addPlayer(playerName)
	indexMap[playerName] = counter
	counter += 1
end

function playerMap.removePlayer(playerName)
	local removedValue = indexMap[playerName]
	if not removedValue then return end
	local lastPlayer 
	for name, value in indexMap do
		lastPlayer = name
	end
	if  lastPlayer ~= playerName then
		indexMap[lastPlayer] = removedValue
	end
	indexMap[playerName] = nil
	counter -= 1
end

function playerMap.getPlayers()
	return indexMap
end

return playerMap

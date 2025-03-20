local ReplicatedStorage = game:GetService("ReplicatedStorage")

local circularBuffer = require(ReplicatedStorage.CircularBuffer)

local snapShots = {}
snapShots.__index = snapShots

function snapShots.new()
	local self = setmetatable({}, snapShots)
	self.snapShots = {}
	self.maxShots = 10
	return self
end

function snapShots:addSnapshot(playerName, timestamp, cframe)
	if not self.snapShots[playerName] then
		self.snapShots[playerName] = circularBuffer.new(self.maxShots)
	end
	self.snapShots[playerName]:addSnapshot(timestamp, cframe)
end

function snapShots:getClosestsnapShots(playerName, targetTime)
	local buffer = self.snapShots[playerName]
	if not buffer then return nil, nil end
	local snapShots = buffer:getSnapShots()
	if #snapShots == 0 then return nil, nil end
	local prev, next = nil, nil
	for i = 1, #snapShots do
		local snap = snapShots[i]
		if snap.timestamp <= targetTime then
			prev = snap
		end
		if snap.timestamp > targetTime then
			next = snap
			break
		end
	end
	return prev, next
end

function snapShots:interpolate(playerName, targetTime)
	local buffer = self.snapShots[playerName]
	if not buffer then return nil end
	local s1, s2 = self:getClosestsnapShots(playerName, targetTime)
	if not s1 then
		return nil 
	end  
	if not s2 then 
		return s1.cframe 
	end  
	local timeDiff = s2.timestamp - s1.timestamp
	if timeDiff == 0 then 
		return s1.cframe 
	end
	local alpha = (targetTime - s1.timestamp) / timeDiff
	return s1.cframe:Lerp(s2.cframe, math.clamp(alpha, 0, 1))
end

return snapShots

local circularBuffer = {}
circularBuffer.__index = circularBuffer

function circularBuffer.new(maxSize)
	local self = setmetatable({}, circularBuffer)
	self.buffer = {}  
	self.maxSize = maxSize  
	return self
end

function circularBuffer:addSnapshot(timestamp, cframe)
	local newSnapshot = {timestamp = timestamp, cframe = cframe}
	table.insert(self.buffer, newSnapshot)
	if #self.buffer > self.maxSize then
		table.remove(self.buffer, 1)
	end
end

function circularBuffer:getSnapShots()
	return self.buffer
end

return circularBuffer

local replicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local gameStateManager = require(replicatedStorage.Shared.Modules.FSM.GameStateManager).new()
local mapSetup = require(replicatedStorage.Shared.Modules.MapHandler.MapSetup)

gameStateManager:changeState("Lobby")

RunService.Heartbeat:Connect(function(dt)
    gameStateManager:update(dt)
end)

----------------
mapSetup.weldAllMaps()

-----------------


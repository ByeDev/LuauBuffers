local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local mapSetup = require(script.Parent.Parent.Parent.MapHandler.MapSetup)
local playerListHandler = require(script.Parent.Parent.Parent.PlayerHandler.PlayerList)
local mapLoader = require(script.Parent.Parent.Parent.MapHandler.MapLoader)

local mapNameBindable = ReplicatedStorage.Shared.Bindables.MapName

local InGame = {}
local playerList = {}

local DURATION = 300

local TARGET_PART = game.workspace.MapSpawn

local chosenMap = nil

function InGame.enter(StateMachine)
    print(`entering InGame`)
    print(`waiting {DURATION}`)
    for i, player in Players:GetPlayers() do
        table.insert(playerList, player)
    end
    print(chosenMap)
    mapSetup.spawnMap(chosenMap, TARGET_PART.CFrame)
    mapSetup.teleportPlayers(playerList)
    mapLoader.initMap(chosenMap)
    task.delay(DURATION, function()
        StateMachine:changeState("Lobby")
    end)
end

function InGame.leave(StateMachine)
    print(`exit InGame`)
    workspace:FindFirstChild(chosenMap.Name):Destroy()
end

function InGame.update(StateMachine)
end

mapNameBindable.Event:Connect(function(mapName)
    chosenMap = mapName
end)

return InGame


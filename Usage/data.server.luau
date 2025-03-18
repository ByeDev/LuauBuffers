local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lyra = require(ReplicatedStorage.Shared.Packages.Lyra)
local network = require(ReplicatedStorage.Shared.Modules.Network.Network)
local bufferWriter = require(ReplicatedStorage.Shared.Modules.Buffer.BufferWriter).new()
local bufferStructs = require(ReplicatedStorage.Shared.Modules.Buffer.BufferStructs)
local Template = require(script:FindFirstChild("Template"))

local playerDataStruct = bufferStructs.playerData

local lyraInit = {}
local playerData = {}
local changes = {}

local function createLogger()
    if RunService:IsStudio() then
        return function(message)
            print(`[Lyra][{message.level}] {message.message}`)
            if message.context then
                print("Context:", message.context)
            end
        end
    else
        return function(message)
            if message.level == "error" or message.level == "fatal" then
                warn(`[Lyra] {message.message}`)
            end
        end
    end
end

local function syncWithClient(key, newData, oldData)
    local player = Players:GetPlayerByUserId(tonumber(key))
    if not player then return end
    if oldData == nil then
        playerData[player.Name] = newData
        bufferWriter:writeStructs(playerDataStruct, newData)
        local bufferCreated = bufferWriter:createBuffer()
        network:fireClient("PlayerData", player, bufferCreated)
        return
    end
    changes = {}
    for i, data in newData do
        if newData.i ~= oldData.i then
            changes.i = newData.I
        end
    end
end

local storeTemplate =  {
    name = "TestPhase6",
    template = Template[1],
    schema = Template[2],
    logCallback = createLogger(),
    changedCallbacks = {syncWithClient},
}

local store = Lyra.createPlayerStore(storeTemplate)

local function onPlayerAdded(player)
    store:loadAsync(player)
end

local function onPlayerRemoving(player)
    store:unloadAsync(player)
end

local function firstTimeRun()
    for i, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end
end

local function onClose()
    store:closeAsync()
end

--------------------------------------------------------------------------

firstTimeRun()

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(onClose)

return lyraInit
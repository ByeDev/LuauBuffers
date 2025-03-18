local replicatedStorage = game:GetService("ReplicatedStorage")

local network = require(replicatedStorage.Shared.Modules.Network.Network)

local gameStateManager = {}
gameStateManager.__index = gameStateManager

-- initalize class gameStatemManager 
function gameStateManager.new()
     local self = {
        currentState = nil,
        states = {},
     }

     setmetatable(self, gameStateManager)
     self:getStates()
     return self
end

-- load in all child modules into states for use
function gameStateManager:getStates()
    for _, module in script:GetChildren() do
        if module:isA("ModuleScript") then
            self.states[module.Name] = require(module)
        end
    end
end
-- changes state, fires leave method from module if exists, updates states variable, fires new state module enter method
-- @params desired state
function gameStateManager:changeState(state)
    local currentState = self.currentState
    local newState = self.states[state]

    if not newState then error(`{state} does not exist`) end

    if currentState and currentState.leave then currentState.leave(self) end

    self.currentState = newState
    network:fireAllClients(state, state)

    if newState.enter then 
        newState.enter(self)
    end
end

-- calls the update method from module
function gameStateManager:update(deltaTime)
    if self.currentState and self.currentState.update then 
        self.currentState.update(self, deltaTime)
    end
end

return gameStateManager




local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local PlotService = Knit.CreateService({
    Name = "PlotService",
    Client = {}
})

local gameCache = {}
local playerAreas = {}
local assignedAreas = {}

local function initializeGameCache()
    if gameCache.initialized then return gameCache end
    
    gameCache.baseplate = game.Workspace.Baseplate
    gameCache.areaTemplate = ReplicatedStorage:WaitForChild("Area")
    gameCache.spawnPartsFolder = game.workspace:WaitForChild("SpawnParts")
    gameCache.areasFolder = game.Workspace:WaitForChild("Areas")
    gameCache.initialized = true
    
    return gameCache
end

local function calculateAreaPosition(part, areaClone)
    local cache = initializeGameCache()
    local baseHeight = cache.baseplate.Position.Y + cache.baseplate.Size.Y / 2
    local areaHeight = areaClone.PrimaryPart.Size.Y / 1.8
    return CFrame.new(part.Position.X, baseHeight + areaHeight, part.Position.Z) * part.CFrame - part.CFrame.Position
end

local function createAreaFromPart(part)
    local cache = initializeGameCache()
    local areaClone = cache.areaTemplate:Clone()
    areaClone.Name = part.Name
    areaClone:SetAttribute("OriginalName", part.Name)
    areaClone:SetPrimaryPartCFrame(calculateAreaPosition(part, areaClone))
    areaClone.Parent = cache.areasFolder
end

local function generateAreas()
    local cache = initializeGameCache()
    for _, part in pairs(cache.spawnPartsFolder:GetChildren()) do
        if part:IsA("BasePart") then
            createAreaFromPart(part)
        end
    end
end

local function getAvailableAreas()
    local cache = initializeGameCache()
    local availableAreas = {}
    for _, area in pairs(cache.areasFolder:GetChildren()) do
        if not assignedAreas[area.Name] then
            table.insert(availableAreas, area)
        end
    end
    return availableAreas
end

local function assignOwnershipToArea(player, area)
    local ownerTag = Instance.new("ObjectValue")
    ownerTag.Name = "Owner"
    ownerTag.Value = player
    ownerTag.Parent = area
    area.Name = player.Name
    
    playerAreas[player.Name] = area.Name
    assignedAreas[area.Name] = true
end

local function assignPlayerToArea(player)
    local availableAreas = getAvailableAreas()
    if #availableAreas == 0 then return end
    
    local randomArea = availableAreas[math.random(1, #availableAreas)]
    assignOwnershipToArea(player, randomArea)
    return randomArea
end

local function teleportPlayerToArea(player)
    task.wait(0.5)
    local cache = initializeGameCache()
    local playerArea = cache.areasFolder:FindFirstChild(player.Name)
    if playerArea then
        local spawnPart = playerArea:FindFirstChild("SpawnLocation"):FindFirstChild("Spawn")
        if spawnPart and player.Character then
            player.Character:MoveTo(spawnPart.Position + Vector3.new(0, 3, 0))
        end
    end
end

local function cleanupPlayerArea(player)
    local cache = initializeGameCache()
    for _, area in pairs(cache.areasFolder:GetChildren()) do
        local owner = area:FindFirstChild("Owner")
        if owner and owner.Value == player then
            owner:Destroy()
            area.Blocks:ClearAllChildren()
            area.Name = area:GetAttribute("OriginalName") or area.Name
            
            assignedAreas[area.Name] = nil
            playerAreas[player.Name] = nil
            break
        end
    end
end

local function onPlayerAdded(player)
    task.wait(0.5)
    assignPlayerToArea(player)
    
    player.CharacterAdded:Connect(function()
        teleportPlayerToArea(player)
    end)
end

function PlotService:GetPlayerArea(player)
    return playerAreas[player.Name]
end

function PlotService:GetPlayerAreaObject(player)
    local cache = initializeGameCache()
    local areaName = playerAreas[player.Name]
    return areaName and cache.areasFolder:FindFirstChild(areaName) or nil
end

function PlotService:KnitStart()
    generateAreas()
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(cleanupPlayerArea)
    
    for _, player in pairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
end

function PlotService:KnitInit()
    initializeGameCache()
end

return PlotService

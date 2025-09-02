local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local BuildingService = Knit.CreateService({
    Name = "BuildingService",
    Client = {
        PlaceBrick = Knit.CreateSignal(),
        DestroyBrick = Knit.CreateSignal(),
    }
})

function BuildingService:PlaceBrick(player, data)
    print("Player " .. player.Name .. " clicked with Build tool")
    return true
end

function BuildingService:DestroyBrick(player, data)
    print("Player " .. player.Name .. " clicked with Destroy tool")
    return true
end

function BuildingService.Client:PlaceBrick(player, data)
    local success = BuildingService:PlaceBrick(player, data)
    return success
end

function BuildingService.Client:DestroyBrick(player, data)
    local success = BuildingService:DestroyBrick(player, data)
    return success
end

function BuildingService:KnitStart()
    -- No need to manually connect RemoteEvents anymore
    -- Knit handles the client-server communication
end

function BuildingService:KnitInit()
end

return BuildingService

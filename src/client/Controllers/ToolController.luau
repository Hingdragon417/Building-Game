local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local ToolController = Knit.CreateController({
    Name = "ToolController",
})

local BuildingService = nil

function ToolController:PlaceBrick(data)
    if not BuildingService then
        return
    end
    
    return BuildingService:PlaceBrick(data)
end

function ToolController:DestroyBrick(data)
    if not BuildingService then
        return
    end
    
    return BuildingService:DestroyBrick(data)
end

function ToolController:KnitStart()
    BuildingService = Knit.GetService("BuildingService")
    
    -- Make this controller globally accessible for tools
    _G.ToolController = self
end

function ToolController:KnitInit()
end

return ToolController

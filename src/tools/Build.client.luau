local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent

local camera = workspace.CurrentCamera
local isBuilding = false
local previewPart = nil

-- Building configuration
local BLOCK_SIZE = Vector3.new(4, 4, 4)
local GRID_SIZE = 4

local function roundToGrid(position)
    return Vector3.new(
        math.floor(position.X / GRID_SIZE + 0.5) * GRID_SIZE,
        math.floor(position.Y / GRID_SIZE + 0.5) * GRID_SIZE,
        math.floor(position.Z / GRID_SIZE + 0.5) * GRID_SIZE
    )
end

local function createPreviewPart()
    if previewPart then
        previewPart:Destroy()
    end
    
    previewPart = Instance.new("Part")
    previewPart.Name = "BuildPreview"
    previewPart.Size = BLOCK_SIZE
    previewPart.Material = Enum.Material.ForceField
    previewPart.BrickColor = BrickColor.new("Bright green")
    previewPart.Transparency = 0.5
    previewPart.CanCollide = false
    previewPart.Anchored = true
    previewPart.Parent = workspace
    
    return previewPart
end

local function updatePreview()
    if not previewPart or not isBuilding then
        return
    end
    
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {previewPart}
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult then
        local hitPosition = raycastResult.Position
        local hitNormal = raycastResult.Normal
        
        -- Position the preview part one grid unit away from the hit surface
        local targetPosition = hitPosition + (hitNormal * (GRID_SIZE / 2))
        targetPosition = roundToGrid(targetPosition)
        
        previewPart.Position = targetPosition
    end
end

local function placeBrick()
    if not previewPart then
        return
    end
    
    local position = previewPart.Position
    
    -- Send place request to server via ToolController
    local toolController = _G.ToolController
    if toolController then
        toolController:PlaceBrick({
            position = position,
            size = BLOCK_SIZE,
            material = Enum.Material.Plastic,
            color = BrickColor.new("Medium stone grey")
        }):andThen(function(success)
            if not success then
                warn("Failed to place brick")
            end
        end):catch(function(err)
            warn("Error placing brick:", err)
        end)
    else
        warn("ToolController not available")
    end
end

-- Tool equipped
tool.Equipped:Connect(function()
    isBuilding = true
    createPreviewPart()
    
    -- Connect mouse events
    mouse.Button1Down:Connect(function()
        placeBrick()
    end)
    
    -- Connect heartbeat for preview updates
    RunService.Heartbeat:Connect(function()
        if isBuilding then
            updatePreview()
        end
    end)
end)

-- Tool unequipped
tool.Unequipped:Connect(function()
    isBuilding = false
    if previewPart then
        previewPart:Destroy()
        previewPart = nil
    end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local tool = script.Parent

local camera = workspace.CurrentCamera
local isDestroying = false
local highlightedPart = nil
local selectionBox = nil

local function createSelectionBox()
    if selectionBox then
        selectionBox:Destroy()
    end
    
    selectionBox = Instance.new("SelectionBox")
    selectionBox.Name = "DestroyHighlight"
    selectionBox.Color3 = Color3.new(1, 0, 0) -- Red
    selectionBox.Transparency = 0.5
    selectionBox.Parent = workspace
    
    return selectionBox
end

local function updateHighlight()
    if not isDestroying then
        return
    end
    
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult and raycastResult.Instance then
        local hit = raycastResult.Instance
        
        -- Only highlight parts that are not part of player characters
        if hit:IsA("Part") and not hit:IsDescendantOf(player.Character) and hit.Name ~= "DestroyHighlight" then
            if highlightedPart ~= hit then
                highlightedPart = hit
                if selectionBox then
                    selectionBox.Adornee = hit
                end
            end
        else
            highlightedPart = nil
            if selectionBox then
                selectionBox.Adornee = nil
            end
        end
    else
        highlightedPart = nil
        if selectionBox then
            selectionBox.Adornee = nil
        end
    end
end

local function destroyPart()
    if not highlightedPart then
        return
    end
    
    -- Send destroy request to server via ToolController
    local toolController = _G.ToolController
    if toolController then
        toolController:DestroyBrick({
            part = highlightedPart
        }):andThen(function(success)
            if not success then
                warn("Failed to destroy brick")
            end
        end):catch(function(err)
            warn("Error destroying brick:", err)
        end)
    else
        warn("ToolController not available")
    end
    
    -- Clear highlight
    highlightedPart = nil
    if selectionBox then
        selectionBox.Adornee = nil
    end
end

-- Tool equipped
tool.Equipped:Connect(function()
    isDestroying = true
    createSelectionBox()
    
    -- Connect mouse events
    mouse.Button1Down:Connect(function()
        destroyPart()
    end)
    
    -- Connect heartbeat for highlight updates
    RunService.Heartbeat:Connect(function()
        if isDestroying then
            updateHighlight()
        end
    end)
end)

-- Tool unequipped
tool.Unequipped:Connect(function()
    isDestroying = false
    highlightedPart = nil
    if selectionBox then
        selectionBox:Destroy()
        selectionBox = nil
    end
end)

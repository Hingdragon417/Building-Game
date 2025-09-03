local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local BuildToolHandler = {}

-- Private variables
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local currentTool = nil
local clickConnection = nil
local previewConnection = nil

-- Building system cache
local buildingSystemCache = {}

-- Initialize building system variables
local function initializeBuildingSystem()
    if buildingSystemCache.initialized then
        return buildingSystemCache
    end
    
    local cache = {
        cframeNew = CFrame.new,
        mathFloor = math.floor,
        ignoreModelForMouse = workspace:WaitForChild("IgnoreModelForMouse"),
        previewBlock = ReplicatedStorage:WaitForChild("PreviewBlock"),
        buildingModel = workspace.Areas:WaitForChild(player.Name).Blocks,
        baseplate = workspace:WaitForChild("Baseplate"),
        green = Color3.fromRGB(0, 255, 0),
        canUse = true,
        
        -- Surface normals
        surfaces = {
            bottom = Enum.NormalId.Bottom,
            top = Enum.NormalId.Top,
            front = Enum.NormalId.Front,
            left = Enum.NormalId.Left,
            right = Enum.NormalId.Right
        },
        
        -- Offsets
        offsets = {
            left = CFrame.new(-3, 0, 0),
            right = CFrame.new(3, 0, 0),
            front = CFrame.new(0, 0, -3),
            back = CFrame.new(0, 0, 3),
            bottom = CFrame.new(0, -3, 0),
            top = CFrame.new(0, 3, 0)
        },
        
        initialized = true
    }
    
    cache.selectionBox = cache.previewBlock:WaitForChild("SelectionBox")
    cache.y = (cache.baseplate.Size.Y + 3) / 2 + cache.baseplate.Position.Y
    
    buildingSystemCache = cache
    return cache
end

-- Get character and humanoid
local function getCharacterAndHumanoid()
    local character = player.Character
    if not character or not character.Parent then
        character = player.CharacterAdded:Wait()
    end
    local humanoid = character:WaitForChild("Humanoid")
    return character, humanoid
end

-- Calculate offset for grid alignment
local function calculateOffset(positionNumber)
    if positionNumber * 10 % 3 == 1 then
        return -1
    elseif positionNumber * 10 % 3 == 2 then
        return 1
    else
        return 0
    end
end

-- Check if the currently equipped tool is the Build tool
local function isEquippedToolBuild()
    local character = player.Character
    if not character then
        return false
    end
    
    local tool = character:FindFirstChild("Build")
    return tool ~= nil and tool:IsA("Tool")
end

-- Handle mouse click when build tool is equipped
local function onMouseClick()
    local cache = initializeBuildingSystem()
    
    if isEquippedToolBuild() and cache.canUse and cache.previewBlock.Parent == cache.ignoreModelForMouse then
        cache.canUse = false
        print("Build tool clicked! Block would be placed at:", cache.previewBlock.CFrame)
        -- Note: Removed remote event call as requested
        cache.canUse = true
    end
end

-- Start preview system
local function startPreviewSystem()
    local cache = initializeBuildingSystem()
    
    if previewConnection then
        previewConnection:Disconnect()
    end
    
    -- Set up mouse target filter
    mouse.TargetFilter = cache.ignoreModelForMouse
    
    -- Enable UI
    if player.PlayerGui.GUIs and player.PlayerGui.GUIs.ColorMaterialPicker then
        player.PlayerGui.GUIs.ColorMaterialPicker.Enabled = true
    end
    
    cache.selectionBox.Color3 = cache.green
    
    previewConnection = RunService.RenderStepped:Connect(function(deltaTime)
        local character, humanoid = getCharacterAndHumanoid()
        local mouseHit = mouse.Hit
        
        if (mouseHit.Position - character.PrimaryPart.Position).Magnitude <= (currentTool:GetAttribute("MaxDistance") or 50)
            and humanoid.Health > 0
        then
            local mouseTarget = mouse.Target
            if mouseTarget == cache.baseplate then
                local x, z = cache.mathFloor(mouseHit.X) + .5, cache.mathFloor(mouseHit.Z) + .5
                cache.previewBlock.CFrame = cache.cframeNew(
                    x + calculateOffset(x),
                    cache.y,
                    z + calculateOffset(z)
                )
                cache.previewBlock.Parent = cache.ignoreModelForMouse
                
            elseif mouseTarget and mouseTarget.Parent == cache.buildingModel then
                local mouseSurface = mouse.TargetSurface
                if mouseSurface == cache.surfaces.left then
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.left)
                elseif mouseSurface == cache.surfaces.right then
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.right)
                elseif mouseSurface == cache.surfaces.bottom then
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.bottom)
                elseif mouseSurface == cache.surfaces.top then
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.top)
                elseif mouseSurface == cache.surfaces.front then
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.front)
                else 
                    cache.previewBlock.CFrame = mouseTarget.CFrame:ToWorldSpace(cache.offsets.back)
                end
                
                cache.previewBlock.Parent = cache.ignoreModelForMouse
            else
                cache.previewBlock.Parent = ReplicatedStorage
            end
        else
            cache.previewBlock.Parent = ReplicatedStorage
        end
    end)
end

-- Stop preview system
local function stopPreviewSystem()
    if previewConnection then
        previewConnection:Disconnect()
        previewConnection = nil
    end
    
    -- Disable UI
    if player.PlayerGui.GUIs and player.PlayerGui.GUIs.ColorMaterialPicker then
        player.PlayerGui.GUIs.ColorMaterialPicker.Enabled = false
    end
    
    if buildingSystemCache.previewBlock then
        buildingSystemCache.previewBlock.Parent = ReplicatedStorage
    end
end

-- Start monitoring clicks and preview
local function startClickMonitoring()
    if clickConnection then
        clickConnection:Disconnect()
    end
    
    clickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            onMouseClick()
        end
    end)
    
    startPreviewSystem()
end

-- Stop monitoring clicks and preview
local function stopClickMonitoring()
    if clickConnection then
        clickConnection:Disconnect()
        clickConnection = nil
    end
    
    stopPreviewSystem()
end

-- Handle character events
local function onCharacterAdded(character)
    -- Monitor when tools are added to character
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") and child.Name == "Build" then
            currentTool = child
            startClickMonitoring()
            print("Build tool equipped!")
            
            -- Connect to the tool's Unequipped event
            child.Unequipped:Connect(function()
                currentTool = nil
                stopClickMonitoring()
                print("Build tool unequipped!")
            end)
        end
    end)
    
    -- Check if build tool is already equipped
    local buildTool = character:FindFirstChild("Build")
    if buildTool and buildTool:IsA("Tool") then
        currentTool = buildTool
        startClickMonitoring()
        print("Build tool was already equipped!")
        
        -- Connect to the tool's Unequipped event for already equipped tool
        buildTool.Unequipped:Connect(function()
            currentTool = nil
            stopClickMonitoring()
            print("Build tool unequipped!")
        end)
    end
end

-- Initialize the system
function BuildToolHandler:Init()
    -- Connect to current character if it exists
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    -- Connect to future characters
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Cleanup function
function BuildToolHandler:Cleanup()
    stopClickMonitoring()
    buildingSystemCache = {}
end

return BuildToolHandler
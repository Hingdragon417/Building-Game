local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local Items = require(ReplicatedStorage.Shared.Modules:WaitForChild("Items"))
local HotbarConfig = require(ReplicatedStorage.Shared.Modules:WaitForChild("HotbarConfig"))

local HotbarService = Knit.CreateService({
    Name = "HotbarService",
    Client = {}
})

function HotbarService:GetSpawnItems()
    local spawnItems = {}
    for itemName, itemData in Items do
        if itemData.SpawnWith then
            table.insert(spawnItems, itemName)
        end
    end
    return spawnItems
end

function HotbarService:GetDefaultHotbar()
    local hotbar = {}
    
    for i = 1, HotbarConfig.MAX_SLOTS do
        hotbar[i] = ""
    end
    
    local spawnItems = self:GetSpawnItems()
    for i, itemName in ipairs(spawnItems) do
        if i <= HotbarConfig.MAX_SLOTS then
            hotbar[i] = itemName
        end
    end
    
    return hotbar
end

function HotbarService:AssignTools(player, hotbar)
    local backpack = player:WaitForChild("Backpack")
    local toolsFolder = ServerStorage:WaitForChild("Tools")

    for _, itemName in hotbar do
        local tool = toolsFolder:FindFirstChild(itemName)
        if tool then
            local clone = tool:Clone()
            clone.Parent = backpack
        end
    end
end

function HotbarService.Client:EquipTool(player, slotIndex)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    
    if not session or not session.Data or not session.Data.hotbar then
        return
    end
    
    local itemName = session.Data.hotbar[slotIndex]
    if not itemName then
        return
    end
    
    local character = player.Character
    if not character then
        return
    end
    
    local toolsFolder = ServerStorage:WaitForChild("Tools")
    local equipped = {}
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            table.insert(equipped, child)
        end
    end
    local alreadyEquipped = false
    for _, toolInst in pairs(equipped) do
        if toolInst.Name == itemName then
            alreadyEquipped = true
        end
    end
    for _, toolInst in pairs(equipped) do
        toolInst:Destroy()
    end
    if not alreadyEquipped then
        local tool = toolsFolder:FindFirstChild(itemName)
        if tool then
            local clone = tool:Clone()
            clone.Parent = character
        end
    end
end

function HotbarService.Client:EquipBackpack(player, slotIndex)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    if not session or not session.Data or not session.Data.backpack then
        warn("[HotbarService] No session or backpack data for", player.Name)
        return
    end
    local itemName = session.Data.backpack[slotIndex]
    if not itemName or itemName == "" then
        return
    end
    local character = player.Character or player.CharacterAdded:Wait()
    if not character then
        warn("[HotbarService] EquipBackpack: No character for player", player.Name)
        return
    end
    local toolsFolder = ServerStorage:WaitForChild("Tools")
    local equipped = {}
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            table.insert(equipped, child)
        end
    end
    local alreadyEquipped = false
    for _, toolInst in pairs(equipped) do
        if toolInst.Name == itemName then
            alreadyEquipped = true
        end
    end
    for _, toolInst in pairs(equipped) do
        toolInst:Destroy()
    end
    if not alreadyEquipped then
        local tool = toolsFolder:FindFirstChild(itemName)
        if tool then
            local clone = tool:Clone()
            clone.Parent = character
        else
            warn("[HotbarService] Tool not found in ServerStorage.Tools:", itemName)
        end
    end
end

function HotbarService.Client:SwapHotbarSlots(player, fromSlot, toSlot)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    
    if not session or not session.Data or not session.Data.hotbar then
        return { success = false, hotbar = nil }
    end
    
    local hotbar = session.Data.hotbar
    local fromItem = hotbar[fromSlot]
    
    if not fromItem or fromItem == "" then
        return { success = false, hotbar = hotbar }
    end
    
    local toItem = hotbar[toSlot]
    
    hotbar[fromSlot] = toItem or ""
    hotbar[toSlot] = fromItem
    
    session.Data.hotbar = hotbar
    DataService:Replicate(player, "hotbar")
    
    return { success = true, hotbar = hotbar }
end

function HotbarService.Client:MoveHotbarToBackpack(player, hotbarSlot, backpackSlot)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    if not session or not session.Data then
        return { success = false }
    end
    local data = session.Data
    data.hotbar = data.hotbar or {}
    data.backpack = data.backpack or {}
    local hotbarItem = data.hotbar[hotbarSlot]
    local backpackItem = data.backpack[backpackSlot] or ""
    data.hotbar[hotbarSlot] = backpackItem
    data.backpack[backpackSlot] = hotbarItem
    DataService:Replicate(player, {"hotbar", "backpack"})
    return { success = true, hotbar = data.hotbar, backpack = data.backpack }
end

function HotbarService.Client:MoveBackpackToHotbar(player, backpackSlot, hotbarSlot)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    if not session or not session.Data then
        return { success = false }
    end
    local data = session.Data
    data.hotbar = data.hotbar or {}
    data.backpack = data.backpack or {}
    local backpackItem = data.backpack[backpackSlot]
    local hotbarItem = data.hotbar[hotbarSlot] or ""
    data.hotbar[hotbarSlot] = backpackItem
    if hotbarItem == "" then
        table.remove(data.backpack, backpackSlot)
    else
        data.backpack[backpackSlot] = hotbarItem
    end
    DataService:Replicate(player, {"hotbar", "backpack"})
    return { success = true, hotbar = data.hotbar, backpack = data.backpack }
end

function HotbarService.Client:GetHotbar(player)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    
    if session and session.Data and session.Data.hotbar then
        local hotbar = session.Data.hotbar
        local hasItems = false
        for i = 1, HotbarConfig.MAX_SLOTS do
            if hotbar[i] and hotbar[i] ~= "" then
                hasItems = true
                break
            end
        end
        
        if hasItems then
            return hotbar
        end
    end
    
    local defaultHotbar = HotbarService:GetDefaultHotbar()
    HotbarService:SetHotbar(player, defaultHotbar)
    return defaultHotbar
end

function HotbarService:SetHotbar(player, hotbarData)
    local DataService = Knit.GetService("DataService")
    local session = DataService.getSession(player)
    
    if session and session.Data then
        local formattedHotbar = {}
        for i = 1, HotbarConfig.MAX_SLOTS do
            formattedHotbar[i] = hotbarData[i] or ""
        end
        
        session.Data.hotbar = formattedHotbar
        DataService:Replicate(player, "hotbar")
    end
end

function HotbarService:KnitStart()
    local DataService = Knit.GetService("DataService")
    
    Players.PlayerAdded:Connect(function(player)
        local session = DataService.waitForSession(player)
        
        if session and session.Data then
            if not session.Data.hotbar then
                session.Data.hotbar = {}
            end
            
            local hotbar = session.Data.hotbar
            local hasValidStructure = true
            
            for i = 1, HotbarConfig.MAX_SLOTS do
                if hotbar[i] == nil then
                    hasValidStructure = false
                    break
                end
            end
            
            if not hasValidStructure then
                local defaultHotbar = self:GetDefaultHotbar()
                session.Data.hotbar = defaultHotbar
                DataService:Replicate(player, "hotbar")
            end
        end
    end)
end

function HotbarService:KnitInit() end

return HotbarService
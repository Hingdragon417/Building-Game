local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local HotbarConfig = require(ReplicatedStorage.Shared.Modules.HotbarConfig)
local Items = require(ReplicatedStorage.Shared.Modules.Items)

local HotbarController = Knit.CreateController({
	Name = "HotbarController",
})

local TWEEN_HOVER_TIME = 0.2
local TWEEN_CLICK_IN_TIME = 0.08
local TWEEN_CLICK_OUT_TIME = 0.15
local HOVER_SCALE = 1.1
local CLICK_SCALE = 0.9
local DEFAULT_SCALE = 1
local DRAG_THRESHOLD = 0.3

local NumberToEnumMap = {
	[1] = Enum.KeyCode.One,
	[2] = Enum.KeyCode.Two,
	[3] = Enum.KeyCode.Three,
	[4] = Enum.KeyCode.Four,
	[5] = Enum.KeyCode.Five,
	[6] = Enum.KeyCode.Six,
	[7] = Enum.KeyCode.Seven,
	[8] = Enum.KeyCode.Eight,
	[9] = Enum.KeyCode.Nine,
	[10] = Enum.KeyCode.Zero,
}

local function GetKeyCodeForSlot(slotIndex)
	return NumberToEnumMap[slotIndex]
end

function HotbarController:TweenToScale(item, scale, time, easingStyle, easingDirection)
	local uiScale = item:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", item)
	uiScale.Scale = DEFAULT_SCALE

	local currentTween = self._tweenMap[item]
	if currentTween then
		currentTween:Cancel()
	end

	local tween = TweenService:Create(uiScale, TweenInfo.new(time, easingStyle, easingDirection), { Scale = scale })
	self._tweenMap[item] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if self._tweenMap[item] == tween then
			self._tweenMap[item] = nil
		end
	end)
	return tween
end

function HotbarController:CreateDragPreview(originalFrame)
	local preview = originalFrame:Clone()
	preview.Name = "DragPreview"
	local screenGui = Players.LocalPlayer.PlayerGui.GUIs:WaitForChild("Toolbar")
	preview.Parent = screenGui
	preview.BackgroundTransparency = 0.5

	preview.Size = UDim2.new(0, originalFrame.AbsoluteSize.X, 0, originalFrame.AbsoluteSize.Y)
	preview.Position = originalFrame.Position
	preview.Active = false

	for _, child in preview:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 1000
			child.Active = false
		end
	end

	return preview
end

function HotbarController:StartDrag(item, slotIndex, hotbarData)
	if self._isDragging then
		return
	end

	if not hotbarData or not hotbarData[slotIndex] or hotbarData[slotIndex] == "" then
		return
	end

	self._isDragging = true
	self._dragStartSlot = slotIndex
	self._dragPreview = self:CreateDragPreview(item)
	self._dragHandledByGlobal = false

	self._dragOverSlot = nil

	local function updateDragPosition()
		if self._dragPreview then
			local mouse = Players.LocalPlayer:GetMouse()
			self._dragPreview.Position = UDim2.new(0, mouse.X - self._dragPreview.AbsoluteSize.X / 2, 0, mouse.Y - self._dragPreview.AbsoluteSize.Y / 2)

			local hoveredSlot = nil
			local guiObjects = Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)

			for _, obj in ipairs(guiObjects) do
				local checkObj = obj
				while checkObj do
					if checkObj.Name == "DragPreview" then
						checkObj = nil
						break
					end

					if checkObj:IsA("Frame") and checkObj.Name:match("SLOT_%d+") then
						hoveredSlot = checkObj
						break
					end
					checkObj = checkObj.Parent
				end
				if hoveredSlot then
					break
				end
			end
			if self._dragOverSlot and self._dragOverSlot ~= hoveredSlot then
				self:TweenToScale(self._dragOverSlot, DEFAULT_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end
			if hoveredSlot and self._dragOverSlot ~= hoveredSlot then
				self:TweenToScale(hoveredSlot, HOVER_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end
			self._dragOverSlot = hoveredSlot
		end
	end

	self._dragUpdateConnection = RunService.Heartbeat:Connect(updateDragPosition)

	if self._dragMonitorConnection then
		self._dragMonitorConnection:Disconnect()
		self._dragMonitorConnection = nil
	end
	self._dragMonitorConnection = RunService.Heartbeat:Connect(function()
		if self._isDragging and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			self:CancelDrag()
		end
	end)

	if self._dragEndConn then
		self._dragEndConn:Disconnect()
	end
	local playerMouse = Players.LocalPlayer:GetMouse()
	self._dragEndConn = playerMouse.Button1Up:Connect(function()
		if self._isDragging and not self._dragHandledByGlobal then
			self:HandleDragRelease()
		end
		self:CancelDrag()
	end)
end

function HotbarController:HandleDragRelease()
	if not self._isDragging then
		return
	end
	if self._dragHandledByGlobal then
		return
	end
	self._dragHandledByGlobal = true

	local mouse = Players.LocalPlayer:GetMouse()
	local targetSlot, targetContainer
	for _, obj in ipairs(Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)) do
		local isPreview = false
		local check = obj
		while check do
			if check.Name == "DragPreview" then
				isPreview = true
				break
			end
			check = check.Parent
		end
		if isPreview then
			continue
		end

		if self._backpackHolder and obj:IsDescendantOf(self._backpackHolder) then
			targetContainer = "backpack"
		end

		local current = obj
		while current do
			if current.Name:match("SLOT_%d+") then
				targetSlot = tonumber(current.Name:match("SLOT_(%d+)"))
				if self._backpackHolder and current:IsDescendantOf(self._backpackHolder) then
					targetContainer = "backpack"
				elseif self._hotbarGui and current:IsDescendantOf(self._hotbarGui) then
					targetContainer = "hotbar"
				end
				break
			end
			current = current.Parent
		end
		if targetSlot then
			break
		end
	end

	local HotbarService = Knit.GetService("HotbarService")
	if self._dragStartContext == "hotbar" and targetContainer ~= "backpack" and self._backpackHolder then
		local pos = self._backpackHolder.AbsolutePosition
		local size = self._backpackHolder.AbsoluteSize

		if mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y then
			targetContainer = "backpack"
			targetSlot = nil
		end
	end

	if targetSlot and self._dragStartContext == "hotbar" and targetContainer == "hotbar" and targetSlot ~= self._dragStartSlot then
		self:EndDrag(targetSlot)
	elseif self._dragStartContext == "hotbar" and targetContainer == "backpack" and self._backpackHolder and self._backpackHolder.Parent.Visible then
		local dropIndex = targetSlot or (#(self._currentBackpackData or {}) + 1)
		HotbarService:MoveHotbarToBackpack(self._dragStartSlot, dropIndex)
			:andThen(function(result)
				if result.success and self._backpackHolder then
					self:DisplayBackpackItems(self._backpackHolder, result.backpack)
				end
			end)
			:catch(function(err)
				warn("Error moving hotbar to backpack:", err)
			end)
		self:CancelDrag()

	elseif targetSlot and self._dragStartContext == "backpack" and targetContainer == "hotbar" then
		local startIndex = self._dragStartSlot

		HotbarService:MoveBackpackToHotbar(startIndex, targetSlot)
		:andThen(function(result)
			if result.success and self._backpackHolder then
				self:DisplayBackpackItems(self._backpackHolder, result.backpack)
			end
		end)
		:catch(function(err)
			warn("Error moving backpack to hotbar:", err)
		end)
		self:CancelDrag()
	else
		self:CancelDrag()
	end

	self:CancelDrag()
end

function HotbarController:CancelDrag()
	if not self._isDragging then
		return
	end

	if self._dragReleaseConnection then
		self._dragReleaseConnection:Disconnect()
		self._dragReleaseConnection = nil
	end

	if self._dragMonitorConnection then
		self._dragMonitorConnection:Disconnect()
		self._dragMonitorConnection = nil
	end

	if self._dragEndConn then
		self._dragEndConn:Disconnect()
		self._dragEndConn = nil
	end

	local dragStartSlot = self._dragStartSlot

	if self._dragUpdateConnection then
		self._dragUpdateConnection:Disconnect()
		self._dragUpdateConnection = nil
	end

	if self._dragPreview then
		self._dragPreview:Destroy()
		self._dragPreview = nil
	end

	self._isDragging = false
	self._dragStartSlot = nil
	self._dragHandledByGlobal = false
	self._dragStartContext = nil
	self._dragEndContext = nil

	if dragStartSlot and self._hotbarGui then
		local originalSlot = self._hotbarGui:FindFirstChild("SLOT_" .. dragStartSlot)
		if originalSlot and not self._hoverState[originalSlot] then
			self:TweenToScale(originalSlot, DEFAULT_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end
end

function HotbarController:EndDrag(targetSlot)
	if not self._isDragging then
		return
	end

	local HotbarService = Knit.GetService("HotbarService")
	local dragStartSlot = self._dragStartSlot

	if self._dragUpdateConnection then
		self._dragUpdateConnection:Disconnect()
		self._dragUpdateConnection = nil
	end

	if self._dragPreview then
		self._dragPreview:Destroy()
		self._dragPreview = nil
	end

	if targetSlot and targetSlot ~= self._dragStartSlot then
		HotbarService:SwapHotbarSlots(self._dragStartSlot, targetSlot)
		:andThen(function(result)
			if not result.success then
				warn("Failed to swap hotbar slots")
			end
		end)
		:catch(function(err)
			warn("Error swapping hotbar slots:", err)
		end)
	end

	self._isDragging = false
	self._dragStartSlot = nil
	self._dragHandledByGlobal = false

	if dragStartSlot and self._hotbarGui then
		local originalSlot = self._hotbarGui:FindFirstChild("SLOT_" .. dragStartSlot)
		if originalSlot and not self._hoverState[originalSlot] then
			self:TweenToScale(originalSlot, DEFAULT_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end
end

function HotbarController:PlayClickAnimation(item)
	local uiScale = item:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", item)
	uiScale.Scale = uiScale.Scale or DEFAULT_SCALE

	local scaleDown = self:TweenToScale(item, CLICK_SCALE, TWEEN_CLICK_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	scaleDown.Completed:Once(function()
		task.wait(0.05)
		if self._hoverState[item] then
			self:TweenToScale(item, HOVER_SCALE, TWEEN_CLICK_OUT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		else
			self:TweenToScale(item, DEFAULT_SCALE, TWEEN_CLICK_OUT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end)
end

function HotbarController:ConnectHotbarUI(hotbar)
	local HotbarService = Knit.GetService("HotbarService")

	for _, item in hotbar:GetChildren() do
		if item:IsA("Frame") and item.Name:match("SLOT_") then
			local slotIndex = tonumber(item.Name:match("SLOT_(%d+)"))
			self._hoverState[item] = false

			item.MouseEnter:Connect(function()
				self._hoverState[item] = true
				if not self._isDragging then
					self:TweenToScale(item, HOVER_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
			end)

			item.MouseLeave:Connect(function()
				self._hoverState[item] = false
				task.wait(0.1)
				if not self._hoverState[item] and (not self._isDragging or (self._isDragging and self._dragStartSlot ~= slotIndex)) then
					self:TweenToScale(item, DEFAULT_SCALE, TWEEN_HOVER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				end
			end)

			local keyCode = GetKeyCodeForSlot(slotIndex)
			if keyCode then
				UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if not gameProcessed and input.KeyCode == keyCode and not self._isDragging then
						HotbarService:EquipTool(slotIndex)
						self:PlayClickAnimation(item)
					end
				end)
			end

			local button = item:FindFirstChild(item.Name)
			if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
				local dragStartTime = 0
				local isDragThreshold = false
				local dragCheckConnection = nil

				button.MouseButton1Down:Connect(function()

					if self._dragPreview then
						self._dragPreview:Destroy()
						self._dragPreview = nil
					end

					if self._dragUpdateConnection then
						self._dragUpdateConnection:Disconnect()
						self._dragUpdateConnection = nil
					end

					self._isDragging = false
					self._dragHandledByGlobal = false
					self._dragStartContext = nil

					dragStartTime = os.clock()
					isDragThreshold = false

					if dragCheckConnection then
						task.cancel(dragCheckConnection)
						dragCheckConnection = nil
					end

					dragCheckConnection = task.spawn(function()
						task.wait(DRAG_THRESHOLD)
						if os.clock() - dragStartTime >= DRAG_THRESHOLD then
							isDragThreshold = true
							self._dragStartContext = "hotbar"
							self:StartDrag(item, slotIndex, self._currentHotbarData)
						end
					end)
				end)

				button.MouseButton1Up:Connect(function()
					if dragCheckConnection then
						task.cancel(dragCheckConnection)
						dragCheckConnection = nil
					end

					local timeSinceDown = os.clock() - dragStartTime

					if self._isDragging and not self._dragHandledByGlobal then
						self:HandleDragRelease()
					elseif timeSinceDown < 0.2 and not self._isDragging then
						HotbarService:EquipTool(slotIndex)
						self:PlayClickAnimation(item)

						self:CancelDrag()
					end

					isDragThreshold = false
					dragStartTime = 0
				end)
			end
		end
	end
end

function HotbarController:ConnectBackpackUI(backpackHolder)
	local HotbarService = Knit.GetService("HotbarService")

	for _, item in ipairs(backpackHolder:GetChildren()) do
		if item:IsA("Frame") and item.Name:match("SLOT_%d+") then
			local slotIndex = tonumber(item.Name:match("SLOT_(%d+)"))
			local button
			for _, obj in ipairs(item:GetDescendants()) do
				if obj.Name == "Dragging" and (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
					button = obj
					break
				end
			end

			if button then
				local dragStartTime = 0
				local dragConn = nil
				local isDragThreshold = false

				button.MouseButton1Down:Connect(function()

					if self._dragPreview then
						self._dragPreview:Destroy()
						self._dragPreview = nil
					end

					if self._dragUpdateConnection then
						self._dragUpdateConnection:Disconnect()
						self._dragUpdateConnection = nil
					end

					self._isDragging = false
					self._dragHandledByGlobal = false
					self._dragStartContext = nil

					dragStartTime = os.clock()
					isDragThreshold = false
					self._dragStartContext = "backpack"
					if dragConn then
						task.cancel(dragConn)
						dragConn = nil
					end
					dragConn = task.spawn(function()
						task.wait(DRAG_THRESHOLD)
						if os.clock() - dragStartTime >= DRAG_THRESHOLD then
							isDragThreshold = true
							self:StartDrag(item, slotIndex, self._currentBackpackData)
						end
					end)
				end)

				button.MouseButton1Up:Connect(function()

					local now = os.clock()
					if self._lastBackpackEquipTime and now - self._lastBackpackEquipTime < 0.2 then
						return
					end
					self._lastBackpackEquipTime = now
					if dragConn then
						task.cancel(dragConn)
						dragConn = nil
					end
					if self._isDragging and not self._dragHandledByGlobal then
						self:HandleDragRelease()
					elseif not self._isDragging then
						HotbarService:EquipBackpack(slotIndex)
						self:PlayClickAnimation(item)
						self:CancelDrag()
					end
					isDragThreshold = false
					dragStartTime = 0
				end)
			end
		end
	end
end

function HotbarController:DisplayHotbarItems(hotbarGui, hotbarData)
	if type(hotbarData) ~= "table" then
		hotbarData = {}
	end

	self._currentHotbarData = hotbarData

	for slotIndex = 1, HotbarConfig.MAX_SLOTS do

		local slot = hotbarGui:FindFirstChild("SLOT_" .. slotIndex)
		if slot and slot:IsA("Frame") then
			local itemName = hotbarData[slotIndex]
			local hasData = itemName and itemName ~= ""
			
			-- Show or hide the slot based on whether it has data
			slot.Visible = hasData
			
			local label = slot:FindFirstChild("Name")
			if label and label:IsA("TextLabel") then
				if hasData then
					label.Text = itemName
				else
					label.Text = ""
				end
			end
			-- Update the slot image based on the Items module
			local button = slot:FindFirstChild(slot.Name)
			if button and (button:IsA("ImageButton") or button:IsA("ImageLabel")) then
				if hasData and Items[itemName] and Items[itemName].Image then
					button.Image = Items[itemName].Image
				else
					button.Image = ""
				end
			end
		end
	end
end

function HotbarController:DisplayBackpackItems(backpackHolder, backpackData)

	if type(backpackData) ~= "table" then
		backpackData = {}
	end
	self._currentBackpackData = backpackData

	for _, child in ipairs(backpackHolder:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("SLOT_%d+") then
			child:Destroy()
		end
	end
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local uiTemplates = assets:WaitForChild("UITemplates")
	local template = uiTemplates:WaitForChild("BackpackTemplate")

	for index, itemName in ipairs(backpackData) do

		local slotName = "SLOT_" .. index
		local slotFrame = backpackHolder:FindFirstChild(slotName)

		if not slotFrame then
			slotFrame = template:Clone()
			slotFrame.Name = slotName
			slotFrame.Parent = backpackHolder
		end

		local label = slotFrame:FindFirstChild("Name", true)
		if label and label:IsA("TextLabel") then
			label.Text = itemName or ""
		end
		-- Update slot index label
		local indexLabel = slotFrame:FindFirstChild("Index", true)
		if indexLabel and indexLabel:IsA("TextLabel") then
			indexLabel.Text = tostring(index)
		end
		-- Update the backpack slot image based on the Items module
		local dragButton = nil
		for _, obj in ipairs(slotFrame:GetDescendants()) do
			if obj.Name == "Dragging" and (obj:IsA("ImageButton") or obj:IsA("ImageLabel")) then
				dragButton = obj
				break
			end
		end
		if dragButton then
			if itemName and Items[itemName] and Items[itemName].Image then
				dragButton.Image = Items[itemName].Image
			else
				dragButton.Image = ""
			end
		end

	end

	self:ConnectBackpackUI(backpackHolder)
end

function HotbarController:KnitStart()
	self._tweenMap = {}
	self._hoverState = {}
	self._isDragging = false
	self._dragStartSlot = nil
	self._dragPreview = nil
	self._dragUpdateConnection = nil
	self._dragHandledByGlobal = false
	self._currentHotbarData = {}
	self._hotbarConnection = nil

	local HotbarService = Knit.GetService("HotbarService")
	local DataController = Knit.GetController("DataController")

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local guisFolder = playerGui:WaitForChild("GUIs")
	local screenGui = guisFolder:WaitForChild("Toolbar")
	local hotbarGui = screenGui:WaitForChild("Hotbar")

	self._hotbarGui = hotbarGui

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local framesContainer = screenGui:WaitForChild("Frames")
	local backpackFrame = framesContainer:WaitForChild("Backpack")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.Backquote then
			backpackFrame.Visible = not backpackFrame.Visible
		end
	end)
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and self._isDragging) then
			self:HandleDragRelease()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and self._isDragging then
			self:CancelDrag()
		end
	end)

	self:ConnectHotbarUI(hotbarGui)
	local backpackHolder = backpackFrame:WaitForChild("Holder")
	backpackHolder.Active = true
	self._backpackHolder = backpackHolder
	self:ConnectBackpackUI(backpackHolder)

	self._hotbarConnection = DataController.onReplicated("hotbar"):Connect(function()

		local data = DataController.getData()
		if data.hotbar then
			self:DisplayHotbarItems(hotbarGui, data.hotbar)
		end
	end)

	self._backpackConnection = DataController.onReplicated("backpack"):Connect(function()
		local data = DataController.getData()
		if data.backpack then
			self:DisplayBackpackItems(backpackHolder, data.backpack)
		end
	end)

	task.spawn(function()
		local data = DataController.waitForData()
		if data.hotbar then
			self:DisplayHotbarItems(hotbarGui, data.hotbar)
		end
		if data.backpack then
			self:DisplayBackpackItems(backpackHolder, data.backpack)
		end
	end)
end

function HotbarController:KnitInit() end

return HotbarController
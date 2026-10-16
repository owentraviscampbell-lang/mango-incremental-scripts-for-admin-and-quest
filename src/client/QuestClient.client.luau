-- QUESTS (client): talking to the quest giver, the dialogue box, the quest tracker
-- and the ! / ? marker over his head. The rules and rewards are on the server (QuestService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local remote = ReplicatedStorage:WaitForChild("QuestAction")

local C = Color3.fromRGB

----------------------------------------------------------------
-- quest state helpers
----------------------------------------------------------------
local function currentQuest()
	return QuestConfig.Quests[player:GetAttribute("QuestStage") or 1]
end
local function isActive()
	return (player:GetAttribute("QuestActive") or 0) == 1
end
local function progress(quest)
	local have = (player:GetAttribute("Collected" .. quest.Mango) or 0) - (player:GetAttribute("QuestStart") or 0)
	return math.clamp(have, 0, quest.Amount)
end

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "QuestGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3 -- under the menus (Shop, Index, Settings...)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o end
local function stroke(o, t, col, border)
	local s = Instance.new("UIStroke"); s.Thickness = t; s.Color = col or C(15, 12, 20)
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = o
	return s
end

-- dialogue box
local box = Instance.new("Frame")
box.Name = "Dialog"
box.AnchorPoint = Vector2.new(0.5, 1)
box.Position = UDim2.new(0.5, 0, 1, -70)
box.Size = UDim2.new(0.62, 0, 0, 190)
box.BackgroundColor3 = C(25, 28, 38)
box.BackgroundTransparency = 0.05
box.Visible = false
box.SelectionGroup = true
corner(box, 18)
stroke(box, 3, C(255, 190, 40), true)
local bsc = Instance.new("UISizeConstraint"); bsc.MinSize = Vector2.new(320, 190); bsc.MaxSize = Vector2.new(820, 190); bsc.Parent = box
box.Parent = gui

local nameTag = Instance.new("TextLabel")
nameTag.Name = "Speaker"
nameTag.Position = UDim2.fromOffset(20, -20)
nameTag.Size = UDim2.fromOffset(200, 38)
nameTag.BackgroundColor3 = C(255, 190, 40)
nameTag.Font = Enum.Font.FredokaOne
nameTag.TextSize = 24
nameTag.TextColor3 = C(60, 30, 0)
nameTag.Text = QuestConfig.GiverName
nameTag.ZIndex = 3
corner(nameTag, 12)
nameTag.Parent = box

local body = Instance.new("TextButton") -- a button so clicking the text skips the typing
body.Name = "Body"
body.AutoButtonColor = false
body.Selectable = false
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(24, 30)
body.Size = UDim2.new(1, -48, 0, 96)
body.Font = Enum.Font.GothamMedium
body.TextSize = 20
body.TextColor3 = C(240, 240, 248)
body.TextWrapped = true
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.Text = ""
body.Parent = box

local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.BackgroundTransparency = 1
buttonRow.AnchorPoint = Vector2.new(1, 1)
buttonRow.Position = UDim2.new(1, -18, 1, -14)
buttonRow.Size = UDim2.new(1, -36, 0, 46)
buttonRow.Parent = box
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = buttonRow

local function makeButton(name, color, order)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(170, 46)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 22
	b.TextColor3 = Color3.new(1, 1, 1)
	b.LayoutOrder = order
	b.Visible = false
	corner(b, 12)
	stroke(b, 2.5, C(15, 12, 20), true)
	stroke(b, 2, C(15, 12, 20))
	b.Parent = buttonRow
	return b
end
local skipButton = makeButton("Skip", C(88, 94, 112), 1)
skipButton.Size = UDim2.fromOffset(100, 46)
skipButton.Text = "Skip"
local noButton = makeButton("No", C(200, 70, 70), 2)
local yesButton = makeButton("Yes", C(60, 190, 85), 3)
local nextButton = makeButton("Next", C(255, 170, 40), 4)

-- quest tracker (top middle, under the party bar)
local tracker = Instance.new("Frame")
tracker.Name = "Tracker"
tracker.AnchorPoint = Vector2.new(0.5, 0)
tracker.Position = UDim2.new(0.5, 0, 0, 50)
tracker.Size = UDim2.fromOffset(250, 66)
tracker.BackgroundColor3 = C(25, 28, 38)
tracker.BackgroundTransparency = 0.15
tracker.Visible = false
corner(tracker, 14)
local trackerStroke = stroke(tracker, 2.5, C(255, 190, 40), true)
tracker.Parent = gui
local tTitle = Instance.new("TextLabel")
tTitle.BackgroundTransparency = 1
tTitle.Position = UDim2.fromOffset(12, 6)
tTitle.Size = UDim2.new(1, -24, 0, 24)
tTitle.Font = Enum.Font.FredokaOne
tTitle.TextSize = 20
tTitle.TextColor3 = C(255, 205, 60)
tTitle.TextXAlignment = Enum.TextXAlignment.Left
tTitle.Text = "\u{1F4DC} Quest"
tTitle.Parent = tracker
local tText = Instance.new("TextLabel")
tText.BackgroundTransparency = 1
tText.Position = UDim2.fromOffset(12, 32)
tText.Size = UDim2.new(1, -24, 0, 26)
tText.Font = Enum.Font.GothamBold
tText.TextSize = 16
tText.TextColor3 = Color3.new(1, 1, 1)
tText.TextXAlignment = Enum.TextXAlignment.Left
tText.TextScaled = true
local tsc = Instance.new("UITextSizeConstraint"); tsc.MaxTextSize = 16; tsc.Parent = tText
tText.Parent = tracker

gui.Parent = playerGui

----------------------------------------------------------------
-- typing text
----------------------------------------------------------------
local typingId = 0
local fullText = ""
local function setText(text)
	typingId += 1
	local id = typingId
	fullText = text
	body.Text = ""
	task.spawn(function()
		for i = 1, #text do
			if typingId ~= id then return end
			body.Text = string.sub(text, 1, i)
			task.wait(0.018)
		end
	end)
end
local function finishTyping()
	typingId += 1
	body.Text = fullText
end
body.Activated:Connect(finishTyping)

----------------------------------------------------------------
-- dialogue flow
----------------------------------------------------------------
local isOpen = false
local pages, pageIndex, onLastPage = {}, 1, nil
local buttonHandlers = {}

local function focusFirstButton()
	if not (UserInputService.GamepadEnabled or UserInputService:GetLastInputType().Name:find("Gamepad")) then return end
	for _, b in ipairs({ yesButton, nextButton, noButton }) do
		if b.Visible then
			GuiService.SelectedObject = b
			return
		end
	end
end

local function showButtons(list)
	for _, b in ipairs({ skipButton, noButton, yesButton, nextButton }) do
		b.Visible = false
	end
	table.clear(buttonHandlers)
	for _, entry in ipairs(list) do
		local b = entry[1]
		b.Text = entry[2] or b.Text
		b.Visible = true
		buttonHandlers[b] = entry[3]
	end
	task.defer(focusFirstButton)
end

local function close()
	if not isOpen then return end
	isOpen = false
	typingId += 1
	box.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(box) then
		GuiService.SelectedObject = nil
	end
	ContextActionService:UnbindAction("QuestDialogClose")
end

-- one line, then a set of buttons
local function say(text, buttons)
	setText(text)
	showButtons(buttons)
end

local function sayThenClose(text)
	say(text, { { nextButton, "Bye!", close } })
end

local function showPage()
	local page = pages[pageIndex]
	if pageIndex < #pages then
		say(page, {
			{ skipButton, "Skip", function() pageIndex = #pages; showPage() end },
			{ nextButton, "Next", function() pageIndex += 1; showPage() end },
		})
	else
		onLastPage(page)
	end
end

-- opening a menu ends the conversation
local MENU_WINDOWS = { SeedShop = "Window", MangoIndex = "Window", SettingsGui = "Window", ResetProgressGui = "Backdrop" }
local function menuOpen()
	for guiName, windowName in pairs(MENU_WINDOWS) do
		local g = playerGui:FindFirstChild(guiName)
		local w = g and g:FindFirstChild(windowName)
		if w and w.Visible then return true end
	end
	local board = playerGui:FindFirstChild("BoardMenu")
	return board ~= nil and board.Enabled
end

local function open()
	if isOpen then return end
	isOpen = true
	box.Visible = true
	ContextActionService:BindActionAtPriority("QuestDialogClose", function(_, state)
		if state == Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end, false, 3500, Enum.KeyCode.ButtonB)

	local quest = currentQuest()
	if not quest then
		sayThenClose(QuestConfig.AllDone)
		return
	end

	if not isActive() then
		-- the story first, then the question
		pages = table.clone(quest.Story)
		table.insert(pages, quest.Ask)
		pageIndex = 1
		onLastPage = function(text)
			say(text, {
				{ noButton, quest.Decline, function() sayThenClose(quest.Declined) end },
				{ yesButton, quest.Accept, function()
					local ok = remote:InvokeServer("accept")
					if ok then
						sayThenClose(quest.Accepted)
					else
						close()
					end
				end },
			})
		end
		showPage()
		return
	end

	local have = progress(quest)
	if have < quest.Amount then
		sayThenClose(QuestConfig.Fill(quest.InProgress, have, quest.Amount))
	else
		say(QuestConfig.Fill(quest.Ready, have, quest.Amount), {
			{ yesButton, quest.Give, function()
				local ok = remote:InvokeServer("claim")
				if ok then
					sayThenClose(quest.Complete)
				else
					close()
				end
			end },
		})
	end
end

local busy = false
for _, b in ipairs({ skipButton, noButton, yesButton, nextButton }) do
	b.Activated:Connect(function()
		if busy then return end
		-- first click while it's still typing just shows the whole line
		if body.Text ~= fullText then
			finishTyping()
			return
		end
		local handler = buttonHandlers[b]
		if handler then
			busy = true
			local ok, err = pcall(handler)
			busy = false
			if not ok then warn(err) close() end
		end
	end)
end

----------------------------------------------------------------
-- the quest giver in the world (he can stream in and out)
----------------------------------------------------------------
local npc, prompt, marker
local function blocked()
	return playerGui:FindFirstChild("LoadingScreen") ~= nil or playerGui:FindFirstChild("IntroCutsceneGui") ~= nil
end

local function refreshMarker()
	if not marker or not marker.Parent then return end
	local quest = currentQuest()
	if not quest then
		marker.Text = ""
	elseif not isActive() then
		marker.Text = "!"
		marker.TextColor3 = C(255, 215, 40)
	elseif progress(quest) >= quest.Amount then
		marker.Text = "?"
		marker.TextColor3 = C(255, 215, 40)
	else
		marker.Text = "?"
		marker.TextColor3 = C(190, 190, 200)
	end
end

local function hookNpc(model)
	if npc == model then return end
	npc = model
	prompt = model:FindFirstChild("TalkPrompt", true)
	local tag = model:FindFirstChild("NameTag", true)
	marker = tag and tag:FindFirstChild("Marker")
	refreshMarker()
	if prompt then
		prompt.Triggered:Connect(function()
			if blocked() then return end
			open()
		end)
	end
end

task.spawn(function()
	local folder = workspace:WaitForChild("QuestNPCs")
	while true do
		local model = folder:FindFirstChild(QuestConfig.GiverName)
		if model and model ~= npc then
			hookNpc(model)
		end
		task.wait(1)
	end
end)

-- walk away (or open a menu) and the conversation ends
RunService.Heartbeat:Connect(function()
	if not isOpen then return end
	if menuOpen() then
		close()
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not npc or not npc.Parent or (npc:GetPivot().Position - root.Position).Magnitude > 18 then
		close()
	end
end)

----------------------------------------------------------------
-- tracker
----------------------------------------------------------------
local function refreshTracker()
	local quest = currentQuest()
	if not quest or not isActive() or blocked() then
		tracker.Visible = false
		return
	end
	tracker.Visible = true
	tTitle.Text = "\u{1F4DC} " .. quest.Title
	local have = progress(quest)
	if have >= quest.Amount then
		tText.Text = "Go back to " .. QuestConfig.GiverName .. "!"
		tText.TextColor3 = C(120, 255, 140)
		trackerStroke.Color = C(120, 255, 140)
	else
		tText.Text = string.format("%s mangoes: %d / %d", quest.Mango, have, quest.Amount)
		tText.TextColor3 = Color3.new(1, 1, 1)
		trackerStroke.Color = C(255, 190, 40)
	end
end

player.AttributeChanged:Connect(function(name)
	if name:match("^Quest") or name:match("^Collected") or name == "DataLoaded" then
		refreshTracker()
		refreshMarker()
	end
end)
-- No "Talk" (or any other) interact prompts while the loading screen or the intro cutscene is up
local ProximityPromptService = game:GetService("ProximityPromptService")
local function refreshPrompts()
	ProximityPromptService.Enabled = not blocked()
end

playerGui.ChildRemoved:Connect(function(c)
	if c.Name == "LoadingScreen" or c.Name == "IntroCutsceneGui" then
		task.defer(function()
			refreshTracker()
			refreshPrompts()
		end)
	end
end)
playerGui.ChildAdded:Connect(function(c)
	if c.Name == "LoadingScreen" or c.Name == "IntroCutsceneGui" then
		close()
		refreshTracker()
		refreshPrompts()
	end
end)
refreshTracker()
refreshPrompts()

-- little pop when the tracker gets a new mango
local lastHave = -1
player.AttributeChanged:Connect(function(name)
	local quest = currentQuest()
	if quest and name == "Collected" .. quest.Mango and isActive() then
		local have = progress(quest)
		if have ~= lastHave then
			lastHave = have
			local s = tracker:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", tracker)
			s.Scale = 1.15
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
end)

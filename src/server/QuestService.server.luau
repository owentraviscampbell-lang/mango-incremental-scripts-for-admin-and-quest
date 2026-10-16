-- QUESTS (server): accepting quests, checking progress, giving rewards.
-- Quest text and rewards live in ReplicatedStorage.QuestConfig.
-- Progress = how many of the quest's mango you've collected since accepting
-- (uses the same "Collected<Name>" counters as the Mango Index).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local SeedAPI = require(ServerScriptService:WaitForChild("SeedAPI"))

local MAX_DISTANCE = 25 -- you have to be standing near the quest giver

local remote = ReplicatedStorage:FindFirstChild("QuestAction")
if not remote then
	remote = Instance.new("RemoteFunction")
	remote.Name = "QuestAction"
	remote.Parent = ReplicatedStorage
end

local function giver()
	local folder = workspace:FindFirstChild("QuestNPCs")
	return folder and folder:FindFirstChild(QuestConfig.GiverName)
end

local function nearGiver(plr)
	local npc = giver()
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not (npc and root) then return false end
	return (npc:GetPivot().Position - root.Position).Magnitude <= MAX_DISTANCE
end

local function progress(plr, quest)
	local have = (plr:GetAttribute("Collected" .. quest.Mango) or 0) - (plr:GetAttribute("QuestStart") or 0)
	return math.clamp(have, 0, quest.Amount)
end

local function toast(plr, text)
	plr:SetAttribute("ToastText", text)
	plr:SetAttribute("ToastCount", (plr:GetAttribute("ToastCount") or 0) + 1)
end

remote.OnServerInvoke = function(plr, action)
	if not plr:GetAttribute("DataLoaded") then return false end
	if not nearGiver(plr) then return false end

	local stage = plr:GetAttribute("QuestStage") or 1
	local quest = QuestConfig.Quests[stage]
	if not quest then return false end -- every quest already done
	local active = (plr:GetAttribute("QuestActive") or 0) == 1

	if action == "accept" then
		if active then return true end
		plr:SetAttribute("QuestStart", plr:GetAttribute("Collected" .. quest.Mango) or 0)
		plr:SetAttribute("QuestActive", 1)
		toast(plr, "New quest: " .. quest.Title .. "!")
		return true

	elseif action == "claim" then
		if not active or progress(plr, quest) < quest.Amount then return false end
		-- move on first, so the reward can never be claimed twice
		plr:SetAttribute("QuestActive", 0)
		plr:SetAttribute("QuestStart", 0)
		plr:SetAttribute("QuestStage", stage + 1)

		local reward = quest.Reward or {}
		local parts = {}
		if reward.Seeds and reward.Seeds > 0 then
			SeedAPI.AddSeeds(plr, reward.Seeds)
			table.insert(parts, "+" .. reward.Seeds .. " seeds")
		end
		if reward.ExpPotions and reward.ExpPotions > 0 then
			plr:SetAttribute("ExpPotions", (plr:GetAttribute("ExpPotions") or 0) + reward.ExpPotions)
			table.insert(parts, "+" .. reward.ExpPotions .. " EXP Potion" .. (reward.ExpPotions == 1 and "" or "s"))
		end
		toast(plr, "Quest complete: " .. quest.Title .. "!  " .. table.concat(parts, "  "))
		plr:SetAttribute("QuestCelebrate", (plr:GetAttribute("QuestCelebrate") or 0) + 1)
		return true
	end
	return false
end

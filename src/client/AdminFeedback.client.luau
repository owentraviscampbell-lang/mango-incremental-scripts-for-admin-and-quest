-- Shows replies from the admin commands in your chat window (only you see them)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local event = ReplicatedStorage:WaitForChild("AdminFeedback")

local function channel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	return channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
end

event.OnClientEvent:Connect(function(text, isError)
	local ch = channel()
	if not ch then return end
	local color = isError and "#FF6B6B" or "#FFD24A"
	for line in string.gmatch(text, "[^\n]+") do
		line = line:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		ch:DisplaySystemMessage('<font color="' .. color .. '">[Admin] ' .. line .. "</font>")
	end
end)

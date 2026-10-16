-- ADMIN COMMANDS (custom, made for Mango incremental)
-- Type these in chat. Only people in ADMINS can use them; for anyone else they do nothing
-- (and the message never shows up in chat).
--
--   /admin                            list the commands
--   /kick <player> [reason]           kick someone from this server
--   /ban <player> [time] [reason]     ban from the whole game. time: 30m, 12h, 7d, or perm (default)
--   /unban <username>                 remove a ban
--   /party [minutes]                  start a Mango Party for everyone in this server (default 10)
--   /stopparty                        end the Mango Party in this server right now
--   /undo                             reverse your last command (type it again to go back further)
--   /seeds <player> <amount>          give seeds
--
-- <player> can be part of a username or display name, "me", "all" or "others".
-- /ban and /unban also take the exact username of someone who isn't in the server.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local SeedAPI = require(ServerScriptService:WaitForChild("SeedAPI"))

----------------------------------------------------------------
-- WHO IS AN ADMIN (add more user IDs here)
----------------------------------------------------------------
local ADMINS = {
	[3764307787] = true, -- Owenistopg
}

local MAX_SEEDS_PER_COMMAND = 1000000

----------------------------------------------------------------
-- private replies to the admin (shown in their chat window)
----------------------------------------------------------------
local feedback = ReplicatedStorage:FindFirstChild("AdminFeedback")
if not feedback then
	feedback = Instance.new("RemoteEvent")
	feedback.Name = "AdminFeedback"
	feedback.Parent = ReplicatedStorage
end
local function reply(admin, text, isError)
	feedback:FireClient(admin, text, isError == true)
end

local function toastAll(text)
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("ToastText", text)
		p:SetAttribute("ToastCount", (p:GetAttribute("ToastCount") or 0) + 1)
	end
end

local function toast(p, text)
	p:SetAttribute("ToastText", text)
	p:SetAttribute("ToastCount", (p:GetAttribute("ToastCount") or 0) + 1)
end

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
local function splitArgs(text)
	local args = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- the command itself
	return args
end

-- Finds players in this server. Returns a list (can be empty).
local function findPlayers(admin, query)
	if not query or query == "" then return {} end
	local q = string.lower(query)
	if q == "me" then return { admin } end
	if q == "all" then return Players:GetPlayers() end
	if q == "others" then
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= admin then table.insert(list, p) end
		end
		return list
	end
	-- exact match first, then "starts with"
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == q or string.lower(p.DisplayName) == q then
			return { p }
		end
	end
	local matches = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(p.Name), 1, #q) == q or string.sub(string.lower(p.DisplayName), 1, #q) == q then
			table.insert(matches, p)
		end
	end
	return matches
end

local function findOne(admin, query)
	local list = findPlayers(admin, query)
	if #list == 0 then
		reply(admin, "No player in this server matches \"" .. tostring(query) .. "\".", true)
		return nil
	elseif #list > 1 then
		local names = {}
		for _, p in ipairs(list) do table.insert(names, p.Name) end
		reply(admin, "More than one match: " .. table.concat(names, ", ") .. ". Type more of the name.", true)
		return nil
	end
	return list[1]
end

-- "30m" / "12h" / "7d" / "perm" -> seconds (-1 = forever). nil if it isn't a time.
local function parseDuration(word)
	if not word then return nil end
	local w = string.lower(word)
	if w == "perm" or w == "permanent" or w == "forever" then return -1 end
	local n, unit = string.match(w, "^(%d+)([smhdw]?)$")
	if not n then return nil end
	local mult = ({ s = 1, m = 60, h = 3600, d = 86400, w = 604800 })[unit] or 86400 -- no unit = days
	return tonumber(n) * mult
end

local function describeDuration(seconds)
	if seconds < 0 then return "permanently" end
	if seconds % 86400 == 0 then return "for " .. seconds // 86400 .. " day(s)" end
	if seconds % 3600 == 0 then return "for " .. seconds // 3600 .. " hour(s)" end
	return "for " .. math.floor(seconds / 60 + 0.5) .. " minute(s)"
end

-- user ID from someone in the server, or from an exact username of someone who isn't
local function resolveUserId(admin, query)
	local inServer = findPlayers(admin, query)
	if #inServer == 1 then
		return inServer[1].UserId, inServer[1].Name
	end
	local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, query)
	if ok and id then
		return id, query
	end
	return nil
end

----------------------------------------------------------------
-- UNDO HISTORY (per admin, only lasts while this server is running)
----------------------------------------------------------------
local history = {}
local function remember(admin, entry)
	local list = history[admin.UserId]
	if not list then
		list = {}
		history[admin.UserId] = list
	end
	table.insert(list, entry)
	while #list > 30 do
		table.remove(list, 1)
	end
end

----------------------------------------------------------------
-- THE COMMANDS
----------------------------------------------------------------
local commands = {}

commands.admin = function(admin)
	reply(admin, table.concat({
		"Admin commands:",
		"/kick <player> [reason]",
		"/ban <player> [30m | 12h | 7d | perm] [reason]",
		"/unban <username>",
		"/party [minutes]",
		"/stopparty",
		"/undo  (reverses your last command)",
		"/seeds <player> <amount>",
		"<player> can be part of a name, me, all or others.",
	}, "\n"))
end

commands.kick = function(admin, args)
	if not args[1] then
		reply(admin, "Usage: /kick <player> [reason]", true)
		return
	end
	local targets = findPlayers(admin, args[1])
	if #targets == 0 then
		reply(admin, "No player in this server matches \"" .. args[1] .. "\".", true)
		return
	end
	local reason = table.concat(args, " ", 2)
	if reason == "" then reason = "You were kicked by an admin." end
	local kicked = {}
	for _, p in ipairs(targets) do
		if ADMINS[p.UserId] then
			reply(admin, "Skipped " .. p.Name .. " (admin).")
		else
			p:Kick(reason)
			table.insert(kicked, p.Name)
		end
	end
	if #kicked > 0 then
		reply(admin, "Kicked: " .. table.concat(kicked, ", "))
	end
end

commands.ban = function(admin, args)
	if not args[1] then
		reply(admin, "Usage: /ban <player> [30m | 12h | 7d | perm] [reason]", true)
		return
	end
	local userId, name = resolveUserId(admin, args[1])
	if not userId then
		reply(admin, "Couldn't find a player called \"" .. args[1] .. "\".", true)
		return
	end
	if ADMINS[userId] then
		reply(admin, "You can't ban an admin.", true)
		return
	end

	local duration = parseDuration(args[2])
	local reasonStart = duration and 3 or 2
	duration = duration or -1
	local reason = table.concat(args, " ", reasonStart)
	if reason == "" then reason = "You are banned from Mango incremental." end

	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,   -- every server of the game
			Duration = duration,      -- seconds, -1 = forever
			DisplayReason = reason,   -- what they see
			PrivateReason = "Banned by " .. admin.Name .. " with /ban",
			ExcludeAltAccounts = false,
		})
	end)
	if ok then
		remember(admin, { kind = "ban", userId = userId, name = name })
		reply(admin, "Banned " .. name .. " " .. describeDuration(duration) .. ".")
	else
		reply(admin, "Ban failed: " .. tostring(err), true)
	end
end

commands.unban = function(admin, args)
	if not args[1] then
		reply(admin, "Usage: /unban <username>", true)
		return
	end
	local ok, userId = pcall(Players.GetUserIdFromNameAsync, Players, args[1])
	if not ok or not userId then
		reply(admin, "Couldn't find a Roblox user called \"" .. args[1] .. "\".", true)
		return
	end
	local ok2, err = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	if ok2 then
		reply(admin, "Unbanned " .. args[1] .. ".")
	else
		reply(admin, "Unban failed: " .. tostring(err), true)
	end
end

commands.party = function(admin, args)
	local minutes = tonumber(args[1]) or (Config.MangoParty.Duration / 60)
	minutes = math.clamp(minutes, 1, 240)
	local now = workspace:GetServerTimeNow()
	local startFrom = math.max(now, workspace:GetAttribute("PartyEnd") or 0) -- adds time if one is running
	workspace:SetAttribute("PartyEnd", startFrom + minutes * 60)
	remember(admin, { kind = "party", seconds = minutes * 60 })
	toastAll(string.format("An admin started a MANGO PARTY!  %dx rare mangoes for everyone", Config.MangoParty.ChanceMultiplier))
	reply(admin, string.format("Mango Party +%g minutes (%d minutes left in total).", minutes, math.floor((startFrom + minutes * 60 - now) / 60 + 0.5)))
end

commands.stopparty = function(admin)
	local left = (workspace:GetAttribute("PartyEnd") or 0) - workspace:GetServerTimeNow()
	if left <= 0 then
		reply(admin, "There's no Mango Party running.", true)
		return
	end
	workspace:SetAttribute("PartyEnd", 0)
	remember(admin, { kind = "stopparty", seconds = left })
	toastAll("The Mango Party has ended.")
	reply(admin, string.format("Stopped the Mango Party (%d:%02d was left).", math.floor(left / 60), math.floor(left % 60)))
end

commands.undo = function(admin)
	local list = history[admin.UserId]
	local entry = list and table.remove(list)
	if not entry then
		reply(admin, "Nothing to undo.", true)
		return
	end

	if entry.kind == "ban" then
		local ok, err = pcall(function()
			Players:UnbanAsync({ UserIds = { entry.userId }, ApplyToUniverse = true })
		end)
		if ok then
			reply(admin, "Undid ban: " .. entry.name .. " is unbanned.")
		else
			table.insert(list, entry) -- keep it so you can try again
			reply(admin, "Couldn't undo the ban: " .. tostring(err), true)
		end

	elseif entry.kind == "seeds" then
		local taken, missing = {}, {}
		for _, id in ipairs(entry.userIds) do
			local p = Players:GetPlayerByUserId(id)
			if p then
				local have = p:GetAttribute("Seeds") or 0
				local take = math.min(have, entry.amount) -- never below 0
				p:SetAttribute("Seeds", have - take)
				table.insert(taken, p.Name .. " (-" .. Config.Abbreviate(take) .. ")")
			else
				table.insert(missing, tostring(id))
			end
		end
		local msg = "Undid seeds: " .. (#taken > 0 and table.concat(taken, ", ") or "nobody")
		if #missing > 0 then
			msg ..= ". " .. #missing .. " player(s) already left, so their seeds stay."
		end
		reply(admin, msg)

	elseif entry.kind == "party" then
		local now = workspace:GetServerTimeNow()
		local newEnd = (workspace:GetAttribute("PartyEnd") or 0) - entry.seconds
		if newEnd <= now then
			workspace:SetAttribute("PartyEnd", 0)
			toastAll("The Mango Party has ended.")
			reply(admin, "Undid party: the Mango Party is over.")
		else
			workspace:SetAttribute("PartyEnd", newEnd)
			reply(admin, string.format("Undid party: removed %g minutes (%d:%02d left).", entry.seconds / 60, math.floor((newEnd - now) / 60), math.floor((newEnd - now) % 60)))
		end

	elseif entry.kind == "stopparty" then
		local now = workspace:GetServerTimeNow()
		local startFrom = math.max(now, workspace:GetAttribute("PartyEnd") or 0)
		workspace:SetAttribute("PartyEnd", startFrom + entry.seconds)
		toastAll("The MANGO PARTY is back on!")
		reply(admin, string.format("Undid stop: the Mango Party is back with %d:%02d left.", math.floor(entry.seconds / 60), math.floor(entry.seconds % 60)))
	end
end

commands.seeds = function(admin, args)
	local amount = math.floor(tonumber(args[2]) or 0)
	if not args[1] or amount <= 0 then
		reply(admin, "Usage: /seeds <player> <amount>", true)
		return
	end
	local targets = findPlayers(admin, args[1])
	if #targets == 0 then
		reply(admin, "No player in this server matches \"" .. args[1] .. "\".", true)
		return
	end
	amount = math.min(amount, MAX_SEEDS_PER_COMMAND)
	local given, givenIds = {}, {}
	for _, p in ipairs(targets) do
		if SeedAPI.AddSeeds(p, amount) then
			toast(p, "An admin gave you " .. Config.Abbreviate(amount) .. " seeds!")
			table.insert(given, p.Name)
			table.insert(givenIds, p.UserId)
		end
	end
	if #givenIds > 0 then
		remember(admin, { kind = "seeds", userIds = givenIds, amount = amount })
	end
	reply(admin, "Gave " .. Config.Abbreviate(amount) .. " seeds to: " .. table.concat(given, ", "))
end

----------------------------------------------------------------
-- hook the commands into chat
----------------------------------------------------------------
local folder = TextChatService:FindFirstChild("MangoAdminCommands")
if folder then folder:Destroy() end
folder = Instance.new("Folder")
folder.Name = "MangoAdminCommands"
folder.Parent = TextChatService

for name, run in pairs(commands) do
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "Admin_" .. name
	cmd.PrimaryAlias = "/" .. name
	cmd.SecondaryAlias = ";" .. name
	cmd.Parent = folder
	cmd.Triggered:Connect(function(textSource, text)
		local admin = Players:GetPlayerByUserId(textSource.UserId)
		if not admin or not ADMINS[admin.UserId] then
			return -- not an admin: do nothing
		end
		local ok, err = pcall(run, admin, splitArgs(text))
		if not ok then
			reply(admin, "Command error: " .. tostring(err), true)
		end
	end)
end

-- QUEST LINE
-- Quests are done in order. To add the next one, copy the block in Quests and change it.
--   Mango   = which special mango to collect (must match a Name in UpgradeConfig.MangoTypes)
--   Amount  = how many (only mangoes picked up AFTER accepting the quest count)
--   Reward  = Seeds and/or ExpPotions
-- In the text, {have} and {need} are replaced with the player's progress.

local QuestConfig = {}

QuestConfig.GiverName = "Obamabike34"

QuestConfig.Quests = {
	{
		Title = "The Lost Compass",
		Mango = "Amethyst",
		Amount = 10,
		Reward = { Seeds = 20, ExpPotions = 1 },

		-- what he says the first time you talk to him
		Story = {
			"Whoa! Are you the one who just face-planted out of the sky? Don't worry, it happens more than you'd think around here.",
			"The name's Obamabike34. I've been riding my bike all over Mango World for years, mapping every single grove.",
			"But last night a huge storm rolled through and knocked my Amethyst Compass right off my handlebars. It shattered into pieces!",
			"The little purple crystals flew everywhere... and now they're growing INSIDE the mangoes. Pretty weird, right?",
			"Without that compass I can't find my way out of this grove. And I was SO close to finding the path to the next world.",
		},
		Ask = "Could you bring me 10 Amethyst mangoes so I can put my compass back together? I'll make it worth your while, promise!",
		Accept = "I'll do it!",
		Decline = "Not right now",
		Declined = "No worries. I'll be right here with my bike if you change your mind.",
		Accepted = "Awesome! Amethyst mangoes are the shiny purple ones, and they're pretty rare. Keep picking mangoes and you'll find them!",

		-- while you're working on it
		InProgress = "Found any yet? You've got {have} / {need} Amethyst mangoes so far. They're rare, so keep at it!",

		-- when you have enough
		Ready = "No way... is that {need} Amethyst mangoes?! Hand them over, hand them over!",
		Give = "Give mangoes",
		Complete = "Look at that, the compass is glowing again! Here: 20 seeds for the upgrade board, and one of my homemade EXP potions. You earned it!",
	},
}

-- what he says once every quest is done
QuestConfig.AllDone = "Thanks again, buddy! I'm still figuring out where this compass is pointing... come back soon for my next adventure."

function QuestConfig.Fill(text, have, need)
	return (text:gsub("{have}", tostring(have)):gsub("{need}", tostring(need)))
end

return QuestConfig

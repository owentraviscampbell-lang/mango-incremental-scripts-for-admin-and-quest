# Mango Incremental: Quest Line & Admin Commands

Scripts from my Roblox game **Mango Incremental**, written in Luau.

## Quest line

An NPC quest giver (Obamabike34) who tells the player a short story, then hands out quests in order.

| File | Where it goes in Studio | What it does |
|---|---|---|
| `src/shared/QuestConfig.luau` | ReplicatedStorage (ModuleScript) | All quest text, goals and rewards. Adding a quest means copying one block. |
| `src/server/QuestService.server.luau` | ServerScriptService (Script) | Accepting quests, checking progress, giving rewards. The server checks everything, so rewards can't be faked or claimed twice. |
| `src/client/QuestClient.client.luau` | StarterPlayerScripts (LocalScript) | Hold-E talk prompt, typewriter dialogue with Skip/Next/Accept, on-screen quest tracker, and the `!` / `?` marker over the NPC. |

**Quest 1, "The Lost Compass":** collect 10 Amethyst mangoes. Reward: 20 seeds and 1 EXP Potion.

Features:
- Only mangoes collected *after* accepting count toward the quest
- Must be standing near the NPC to accept or hand in (checked on the server)
- Dialogue closes if you walk away or open another menu
- Works with mouse, touch and Xbox controller

## Admin commands

Chat commands that only listed admins can use. For anyone else they do nothing.

| File | Where it goes in Studio | What it does |
|---|---|---|
| `src/server/AdminCommands.server.luau` | ServerScriptService (Script) | All the commands, built on `TextChatCommand` |
| `src/client/AdminFeedback.client.luau` | StarterPlayerScripts (LocalScript) | Shows private `[Admin]` replies in the admin's chat window |

| Command | What it does |
|---|---|
| `/admin` | List the commands |
| `/kick <player> [reason]` | Kick from the server |
| `/ban <player> [30m \| 12h \| 7d \| perm] [reason]` | Game-wide ban using Roblox's `BanAsync` |
| `/unban <username>` | Remove a ban |
| `/party [minutes]` | Start a Mango Party (5x rare mangoes) for the whole server |
| `/stopparty` | End the Mango Party |
| `/seeds <player> <amount>` | Give seeds |
| `/undo` | Reverse your last ban, seeds, party or stopparty (repeatable) |

`<player>` can be part of a username or display name, `me`, `all` or `others`. Admins can't be kicked or banned.

## Dependencies

These scripts plug into the rest of the game and expect:
- `ReplicatedStorage.UpgradeConfig`: game config (Mango Party settings, number formatting)
- `ServerScriptService.SeedAPI`: `AddSeeds(player, amount)`
- Player data stored as attributes (`Seeds`, `Collected<MangoName>`, `QuestStage`, …), saved by the game's data script
- A `workspace.QuestNPCs.Obamabike34` model with a `TalkPrompt` ProximityPrompt and a `NameTag` billboard

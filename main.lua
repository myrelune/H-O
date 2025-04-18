-- Miner's Haven Automation Script
-- Author: myrelune
-- Uses Rayfield UI Library

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()


--// Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MoneyLib = require(ReplicatedStorage:WaitForChild("MoneyLib"))

--// Player Info

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

--// Game Remotes

local rebirthRemote = ReplicatedStorage:WaitForChild("Rebirth")
local layoutsRemote = ReplicatedStorage:WaitForChild("Layouts")

--// Player Values

local leaderstats = player:WaitForChild("leaderstats")
local life = leaderstats:WaitForChild("Life").Value
local cashValue = player:WaitForChild("PlayerGui").GUI.Money
local playerSettings = player:WaitForChild("PlayerSettings")

--// Script State

local rebirthEnabled = false
local layout = nil
local collectBox = false
local isRebirthing = false

--// Extra

local webhookURL = nil

--// UI Setup

local window = Rayfield:CreateWindow({
    Name = "Haven//O",
    Icon = 0,
    LoadingTitle = "Haven//Optimized",
    LoadingSubtitle = "Rayfield Interface by Sirius",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Miner's Haven",
        FileName = "Settings"
    }
})

local mainTab = window:CreateTab("Main")
local webhookTab = window:CreateTab("Webhook")
local miscTab = window:CreateTab("Misc")

--// Utility Functions

local function sendToDiscord(playerName, playerLife, itemName, tier)
    local payload = string.format([[
    {
        "embeds": [{
            "title": "🎉 ||%s||  -  (Life %s)",
            "description": "A shiny reborn has been obtained!",
            "color": 16753920,
            "fields": [
                {
                    "name": "%s",
                    "value": "%s",
                    "inline": false
                }
            ],
            "footer": {
                "text": "H//O"
            },
            "timestamp": "%s"
        }]
    }
    ]],
    playerName, playerLife, -- title
    tier, itemName,         -- field name & value
    os.date("!%Y-%m-%dT%H:%M:%SZ") -- timestamp (UTC)
    )

    local response = request({
        Url=webhookURL,
        Method="POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body=payload})
    print("[Embed sent to Discord] " .. response.Body)
end

local function getPlayerTycoon()
    local tycoons = Workspace:WaitForChild("Tycoons")
    for _, v in pairs(tycoons:GetDescendants()) do
        if v.Name == "Owner" and v.Value == player.Name then
            return v.Parent
        end
    end
    return nil
end

local function safeLoadLayout(attempts)
    local tycoon = getPlayerTycoon()
    if not tycoon then
        warn("Could not find player's tycoon.")
        return
    end

    attempts = attempts or 1
    local before = #tycoon:GetChildren()

    print("Loading layout attempt #" .. attempts)
    layoutsRemote:InvokeServer("Load", "Layout" .. layout)

    task.delay(2, function()
        local after = #tycoon:GetChildren()
        if after == before and attempts < 3 then
            print("Layout load failed or no change. Retrying...")
            safeLoadLayout(attempts + 1)
        elseif after > before then
            print("Layout load successful!")
        else
            warn("Layout failed after multiple attempts.")
        end
    end)
end

local function tryRebirth()
    if isRebirthing or not rebirthEnabled then return end
    isRebirthing = true

    print("Attempting rebirth...")
    task.wait(math.random(0.3, 0.7)/10)
    rebirthRemote:InvokeServer()
    task.wait(math.random(2,5)/10)
    safeLoadLayout()
    task.wait(math.random(1,3)/10)

    isRebirthing = false
end

local function onCashChanged()
    if not rebirthEnabled then return end

    local skipEnabled = playerSettings:WaitForChild("LifeSkip")
    local maxSkips = player:WaitForChild("MaxLivesSkipped").Value

    local skipCost = MoneyLib.CalculateLifeSkips(player, maxSkips)

    if cashValue.Value == "inf" then
        tryRebirth()
    end

    if skipEnabled then
        if cashValue.Value >= skipCost then
            tryRebirth()
        end
    else
        if cashValue.Value >= MoneyLib.RebornPrice(player) then
            tryRebirth()
        end
    end
end

local function listenForRebirthRewards()
    local rewardFolder = player:WaitForChild("PlayerGui"):WaitForChild("GUI"):WaitForChild("Notifications")

    rewardFolder.ChildAdded:Connect(function(child)
        if child.Name == "ItemTemplate" or child.Name == "ItemTemplateMini" then
            local title = child:FindFirstChild("Title")
            local tier = child:FindFirstChild("Tier")
            if title and title:IsA("TextLabel") and string.find(tier.Text, "Shiny") and webhookURL ~= nil then
                sendToDiscord(player.Name, life, title.Text, tier.Text)
            end
        end
    end)
end

local function onBoxSpawned(box)
    if collectBox and box:IsA("BasePart") then
        local tempPos = humanoidRootPart.CFrame
        humanoidRootPart.CFrame = box.CFrame
        task.wait(0.2)
        humanoidRootPart.CFrame = tempPos
    end
end

--// Main Tab Elements

mainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "Rebirth",
    Callback = function(value)
        rebirthEnabled = value
    end
})

mainTab:CreateInput({
    Name = "Load Layout",
    CurrentValue = "",
    PlaceholderText = "Layout to load (1-3)",
    RemoveTextAfterFocusLost = false,
    Flag = "Layout",
    Callback = function(text)
        layout = text
    end
})

mainTab:CreateParagraph({
    Title = "Guide",
    Content = "Enter the number of the layout you want to load and enable Auto Rebirth, load the layout manually once and it will begin to work."
})

mainTab:CreateDivider()

mainTab:CreateButton({
    Name = "Claim Dailies",
    Callback = function()
        ReplicatedStorage:WaitForChild("RedeemFreeBox"):FireServer()
        ReplicatedStorage:WaitForChild("RewardReady"):FireServer(false)
        task.wait(1)

        local prompt = Workspace.Map.Fargield.Internal.ProximityPrompt
        local tempPos = humanoidRootPart.CFrame

        humanoidRootPart.CFrame = prompt.Parent.CFrame + Vector3.new(0, 5, 0)
        task.wait(0.5)
        fireproximityprompt(prompt)
        task.wait(1)
        humanoidRootPart.CFrame = tempPos
    end
})

--// Webhook Tab Elements

local wbhURL = webhookTab:CreateInput({
    Name = "Webhook URL",
    CurrentValue = "",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = true,
    Flag = "wbhURL",
    Callback = function(Text)
        webhookURL = Text
    end,
 })

 local TestWebhook = webhookTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if webhookURL == nil then
            return Rayfield:Notify({
                Title = "Webhook Fail!",
                Content = "There was no webhook URL provided.",
                Duration = 3,
                Image = "octagon-alert",
            })
        end
        sendToDiscord("TestUser", "S+1,000,000", "⭐ Paranormal Tesla Resetter ⭐", "Shiny Reborn")
    end
})

local wbhGuide = webhookTab:CreateParagraph({
    Title = "Guide",
    Content = "Setting a webhook URL will enable Shiny tracking.\nPressing Test Webhook will send a example embed."
})

--// Misc Tab Elements

miscTab:CreateKeybind({
    Name = "Teleport to Base",
    CurrentKeybind = "V",
    HoldToInteract = false,
    Flag = "BaseKeybind",
    Callback = function()
        local tycoon = getPlayerTycoon()
        if not tycoon then return end
        local base = tycoon:FindFirstChild("Base")

        if base and base:IsA("BasePart") then
            humanoidRootPart.CFrame = base.CFrame + Vector3.new(0, 10, 0)
        else
            warn("Base not found in tycoon!")
        end
    end
})

miscTab:CreateButton({
    Name = "Increased Player Speed and Jump",
    Callback = function()
        humanoid.WalkSpeed = 125
        humanoid.JumpPower = 100
    end
})

miscTab:CreateDivider()

miscTab:CreateToggle({
    Name = "Auto Collect Crates",
    CurrentValue = false,
    Flag = "Boxes",
    Callback = function(value)
        collectBox = value
    end
})

--// Event Connections

listenForRebirthRewards()
cashValue.Changed:Connect(onCashChanged)
Workspace.Boxes.ChildAdded:Connect(onBoxSpawned)
onCashChanged()
Rayfield:LoadConfiguration()

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
local collectBox = false
local layout = nil
local availableMystery = {"None"}
local openingMystery = false

--// Extra

local webhook = {url = nil, shiny = false, stats = false}

--// UI Setup

local window = Rayfield:CreateWindow({
    Name = "Haven/O",
    Icon = 0,
    LoadingTitle = "Haven/Optimized",
    LoadingSubtitle = "Rayfield Interface by Sirius",
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = false,

    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Miner's Haven",
        FileName = "Settings"
    },

    Discord = {
        Enabled = true,
        Invite = "UwvTm57q",
        RememberJoins = true
    }
})

local mainTab = window:CreateTab("Main")
local webhookTab = window:CreateTab("Webhook")
local miscTab = window:CreateTab("Misc")

--// Utility Functions

local function sendWebhook(data)
    if not webhook.url or webhook.url == "" then
        return warn("[Webhook] No webhook URL")
    end

    --// Default Values
    data.title = data.title or "H/O Notification"
    data.description = data.description or ""
    data.color = data.color or 16753920
    data.fields = data.fields or {}

    local payload = {
        ["embeds"] = {{
            ["title"] = data.title,
            ["description"] = data.description,
            ["color"] = data.color,
            ["fields"] = data.fields,
            ["footer"] = {
                ["text"] = data.footer or "H/O"
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    local success, response = pcall(function()
        return request({
            Url = webhook.url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(payload)
        })
    end)

    if success then
        print("[Webhook] Sent!")
    else
        warn("[Webhook] Error: ", response)
    end
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
    if not rebirthEnabled and layout == nil then return end

    task.wait(math.random(3,7)/10)
    rebirthRemote:InvokeServer()
    task.wait(math.random(2,5)/10)
    safeLoadLayout()
end

local function initLayout()
    local tycoonState = getPlayerTycoon()
    local count = #tycoonState:GetChildren()
    if rebirthEnabled and layout ~= nil and count == 5 then
        safeLoadLayout()
    end
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

            if string.find(tier.Text, "Shiny") and webhook.shiny then
                sendWebhook({
                    title = "||" .. player.DisplayName .. "||  -  (Life " .. life .. ")",
                    description = "A " .. tier.Text .. "has been obtained!",
                    fields = {
                        {name = "Item", value = title.Text, inline = false}
                    }
                })
            elseif webhook.stats then
                print("stats")
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

task.spawn(function()
    local header = player:WaitForChild("PlayerGui"):WaitForChild("GUI"):WaitForChild("Boxes"):WaitForChild("Header")

    for _, child in ipairs(header:GetChildren()) do
        if child:IsA("Frame") and child.Visible then
            table.insert(availableMystery, child.Name)
        end
    end

    print("Available mystery boxes:", table.concat(availableMystery, ", "))
end)

local function openMystery(mystery)
    if mystery then
        Rayfield:Notify({
            Title = "Opening Boxes!",
            Content = "Now opening " .. mystery .. "!\nSelect None to stop.",
            Duration = 3,
            Image = "package-open"
        })
        while openingMystery do
            task.wait(1)
            game:GetService("ReplicatedStorage"):WaitForChild("MysteryBox"):InvokeServer(mystery)
        end
    end
end

--// Main Tab Elements

mainTab:CreateToggle({
    Name = "Auto Rebirth",
    CurrentValue = false,
    Flag = "Rebirth",
    Callback = function(value)
        rebirthEnabled = value
        initLayout()
        tryRebirth()
    end
})

mainTab:CreateDropdown({
    Name = "Load Layout",
    Options = {"1", "2", "3"},
    CurrentOption = {"1"},
    MultipleOptions = false,
    Flag = "LayoutDrop",
    Callback = function(Options)
        layout = Options[1]
        initLayout()
    end
})

mainTab:CreateDivider()

--game:GetService("ReplicatedStorage"):WaitForChild("MysteryBox"):InvokeServer(box)

mainTab:CreateButton({
    Name = "Claim Dailies",
    Callback = function()
        ReplicatedStorage:WaitForChild("RedeemFreeBox"):FireServer()
        ReplicatedStorage:WaitForChild("RewardReady"):FireServer(false)
        task.wait(0.3)

        local prompt = Workspace.Map.Fargield.Internal.ProximityPrompt
        local tempPos = humanoidRootPart.CFrame

        humanoidRootPart.CFrame = prompt.Parent.CFrame + Vector3.new(0, 5, 0)
        task.wait(0.5)
        fireproximityprompt(prompt)
        task.wait(0.5)
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
        webhook.url = Text
    end,
 })

 local wbhShiny = webhookTab:CreateToggle({
    Name = "Track Shinies",
    CurrentValue = false,
    Flag = "ShinyTracker",
    Callback = function(Value)
        webhook.shiny = Value
    end
 })

 local wbhStats = webhookTab:CreateToggle({
    Name = "Stat Summary",
    CurrentValue = false,
    Flag = "StatSummary",
    Callback = function(Value)
        webhook.stats = Value
    end
 })

 local TestWebhook = webhookTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        if not webhook.url or webhook.url == "" then
            return Rayfield:Notify({
                Title = "Webhook Fail!",
                Content = "There was no webhook URL provided.",
                Duration = 3,
                Image = "octagon-alert",
            })
        end

        sendWebhook({
            title = "Webhook Test",
            description = "This is a test embed sent from H/O.",
            color = 5763719,
            fields = {
                { name = "Webhook Status", value = "Active", inline = false },
            },
            footer = "H/O Webhook"
        })
    end
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

miscTab:CreateDropdown({
    Name = "Open Mystery Boxes",
    Options = availableMystery,
    CurrentOption = {"None"},
    MultipleOptions = false,
    Flag = "MysteryDropdown",
    Callback = function(Options)
        if Options[1] == "None" then
            openingMystery = false
            return
        else
            openingMystery = true
            openMystery(Options[1])
        end
    end
})

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

--// Event Connections

listenForRebirthRewards()
cashValue.Changed:Connect(onCashChanged)
Workspace.Boxes.ChildAdded:Connect(onBoxSpawned)
onCashChanged()
initLayout()
Rayfield:LoadConfiguration()

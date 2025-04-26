local Players = game:GetService("Players")
local player = Players.LocalPlayer

local EasterFolder = workspace:WaitForChild("Easter"):WaitForChild("EASTER ISLAND EGG SPAWNS")
local BoxesFolder = workspace:WaitForChild("Boxes")
local MapFolder = workspace:WaitForChild("Map"):WaitForChild("EGG_SPAWNS")
local EggClaim = game:GetService("ReplicatedStorage"):WaitForChild("EventControllers"):WaitForChild("Easter"):WaitForChild("EasterBadgeItem")

local character

local function bindCharacter()
	character = player.Character or player.CharacterAdded:Wait()
end

-- Initial bind
bindCharacter()

local function teleportTo(target)
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local hrp = character.HumanoidRootPart

    task.wait(math.random(math.random(3,7), math.random(7,10)))

	local tpCFrame
	if target:IsA("Model") then
		local part = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
		if part then
			tpCFrame = part.CFrame
		end
	elseif target:IsA("BasePart") then
		tpCFrame = target.CFrame
	end

	if tpCFrame then
		hrp.Anchored = true
		hrp.CFrame = tpCFrame + Vector3.new(0, -1, 0)
		task.wait(0.2)
		hrp.Anchored = false
	end
end

local function fireProximityPrompts(instance)
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			fireproximityprompt(desc)
		end
	end
end

local function scanFolderForEggs(folder)
	for _, container in ipairs(folder:GetChildren()) do
		for _, egg in ipairs(container:GetChildren()) do
			if egg:IsA("Model") or egg:IsA("BasePart") then
				teleportTo(egg)
                task.wait(math.random(1,2))
				fireProximityPrompts(egg)
                task.wait(math.random(2,3))
                EggClaim:InvokeServer(egg.Name)
			end
		end
	end
end

EasterFolder.DescendantAdded:Connect(function()
	scanFolderForEggs(EasterFolder)
end)

MapFolder.DescendantAdded:Connect(function()
	scanFolderForEggs(MapFolder)
end)

player.CharacterAdded:Connect(function()
	bindCharacter()
end)

scanFolderForEggs(EasterFolder)
scanFolderForEggs(MapFolder)

for _, connection in pairs(getconnections(game:GetService("Players").LocalPlayer.Idled)) do
    connection:Disable()
end

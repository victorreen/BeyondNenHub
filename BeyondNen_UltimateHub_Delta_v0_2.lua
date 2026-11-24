-- Beyond Nen Progression Hub v0.7 - data-driven mobile helper
-- Built from the user's live diagnostic report for PlaceId 78073853031462.
-- No external loaders, HTTP requests, webhooks, credential access, or hidden RemoteEvent calls.
-- Important: client-side automation may be rejected by the game/server and may violate game rules.
-- Unverified game actions are exposed as helpers/manual steps instead of fabricated remote calls.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
if not LP then return end

local PlayerGui = LP:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("BeyondNenProgressionHub")
if oldGui then oldGui:Destroy() end

local touch = UIS.TouchEnabled
local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(900, 700)
local portrait = touch and viewport.X < viewport.Y
local width = math.floor(math.clamp(viewport.X * (touch and 0.95 or 0.72), 330, 620))
local height = math.floor(math.clamp(viewport.Y * (portrait and 0.64 or 0.75), 410, 610))
height = math.min(height, viewport.Y - 20)
local sidebarWidth = width < 465 and 94 or 130
local fontScale = math.clamp(viewport.X / 440, 0.88, 1.14)
local buttonHeight = touch and 41 or 35

local C = {
    bg = Color3.fromRGB(17, 19, 25), panel = Color3.fromRGB(25, 29, 37), panel2 = Color3.fromRGB(35, 40, 50),
    accent = Color3.fromRGB(116, 221, 169), green = Color3.fromRGB(64, 166, 126), text = Color3.fromRGB(238, 241, 245),
    muted = Color3.fromRGB(157, 165, 178), red = Color3.fromRGB(170, 65, 72), blue = Color3.fromRGB(77, 132, 184), gold = Color3.fromRGB(193, 151, 72),
}

local function new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function corner(object, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end

local gui = new("ScreenGui", {
    Name = "BeyondNenProgressionHub", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10000,
}, PlayerGui)

local main = new("Frame", {
    Name = "Main", Size = UDim2.fromOffset(width, height), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, gui)
corner(main, 12)
new("UIStroke", {Color = C.green, Transparency = 0.2, Thickness = 1.25}, main)

local top = new("Frame", {Name = "TopBar", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.panel, BorderSizePixel = 0}, main)
corner(top, 12)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -100, 1, 0),
    Font = Enum.Font.GothamBold, Text = "BEYOND NEN / PROGRESSION v0.7", TextColor3 = C.text,
    TextSize = math.floor(12 * fontScale), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, top)
local minimize = new("TextButton", {
    Name = "Minimize", Position = UDim2.new(1, -78, 0, 7), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.panel2, Text = "−", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 21, BorderSizePixel = 0,
}, top)
corner(minimize, 7)
local close = new("TextButton", {
    Name = "Close", Position = UDim2.new(1, -41, 0, 7), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.red, Text = "×", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 20, BorderSizePixel = 0,
}, top)
corner(close, 7)

local sidebar = new("Frame", {
    Name = "Sidebar", Position = UDim2.fromOffset(9, 52), Size = UDim2.new(0, sidebarWidth, 1, -61),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
corner(sidebar, 8)
new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, sidebar)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)

local content = new("ScrollingFrame", {
    Name = "Content", Position = UDim2.fromOffset(sidebarWidth + 17, 52), Size = UDim2.new(1, -(sidebarWidth + 26), 1, -88),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, ScrollBarThickness = touch and 3 or 4,
    ScrollBarImageColor3 = C.green, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, main)
corner(content, 8)
new("UIPadding", {PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, content)
local contentLayout = new("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, content)
local status = new("TextLabel", {
    Name = "Status", Position = UDim2.new(0, sidebarWidth + 18, 1, -30), Size = UDim2.new(1, -(sidebarWidth + 28), 0, 22),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Ready", TextColor3 = C.muted,
    TextSize = math.floor(10 * fontScale), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, main)
local function say(message, color)
    if status and status.Parent then status.Text = tostring(message); status.TextColor3 = color or C.muted end
end

-- Touch/mouse drag and minimize.
local dragging, dragStart, dragOrigin, dragInput = false, nil, nil, nil
local minimized, expandedSize = false, main.Size
local function setMinimized(value)
    minimized = value
    sidebar.Visible = not value
    content.Visible = not value
    status.Visible = not value
    main.Size = value and UDim2.fromOffset(math.min(width, 270), 44) or expandedSize
    minimize.Text = value and "+" or "−"
end
minimize.Activated:Connect(function() setMinimized(not minimized) end)
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, dragOrigin = true, input.Position, main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y)
    end
end)

local function clearPage()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= contentLayout and not child:IsA("UIPadding") then child:Destroy() end
    end
end
local function section(title, description, color)
    local h = description and 62 or 34
    local frame = new("Frame", {Size = UDim2.new(1, -2, 0, h), BackgroundColor3 = C.panel2, BorderSizePixel = 0}, content)
    corner(frame, 7)
    new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 7)}, frame)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 21), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        Text = title, TextColor3 = color or C.accent, TextSize = math.floor(12 * fontScale), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)
    if description then
        new("TextLabel", {
            Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, Text = description, TextColor3 = C.muted, TextSize = math.floor(10 * fontScale),
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        }, frame)
    end
    return frame
end
local function button(title, callback, color)
    local b = new("TextButton", {
        Size = UDim2.new(1, -2, 0, buttonHeight), BackgroundColor3 = color or C.panel2, BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold, Text = title, TextColor3 = C.text, TextSize = math.floor(11 * fontScale),
        TextWrapped = true, AutoButtonColor = true,
    }, content)
    corner(b, 7)
    b.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[Beyond Nen v0.7] " .. tostring(err)); say("Action error: " .. tostring(err), C.red) end
    end)
    return b
end
local function toggle(title, initial, callback)
    local value = initial == true
    local b = new("TextButton", {
        Size = UDim2.new(1, -2, 0, buttonHeight), BackgroundColor3 = C.panel2, BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold, TextColor3 = C.text, TextSize = math.floor(11 * fontScale), TextWrapped = true,
    }, content)
    corner(b, 7)
    local function refresh() b.Text = title .. (value and "   [ON]" or "   [OFF]"); b.BackgroundColor3 = value and C.green or C.panel2 end
    b.Activated:Connect(function()
        value = not value; refresh()
        local ok, err = pcall(callback, value)
        if not ok then warn("[Beyond Nen v0.7] " .. tostring(err)); say("Toggle error", C.red) end
    end)
    refresh()
    return function() return value end
end

local function lower(value) return string.lower(tostring(value or "")) end
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function humanoidOf(model) return model and model:FindFirstChildOfClass("Humanoid") end
local function getCharacter() return LP.Character end
local function getRoot() return rootOf(getCharacter()) end
local function getHumanoid() return humanoidOf(getCharacter()) end
local function isPlayerCharacter(model)
    for _, player in ipairs(Players:GetPlayers()) do if player.Character == model then return true end end
    return false
end
local function isAliveNPC(model)
    if not model or not model:IsA("Model") or isPlayerCharacter(model) then return false end
    local hum = humanoidOf(model)
    return hum and hum.Health > 0 and rootOf(model) ~= nil
end

-- Exact enemy names seen in the user's in-game scans.
local enemyGroups = {
    "Zombie", "Big Zombie", "Stone Soldier", "Green Goblin", "Forest Brawler", "Cave Brawler",
    "Angry Farmer", "Farm Keeper", "Chief Farmer", "Phantom Raider", "Port Invader", "Port Marksman",
    "Fox Bear Hunter", "Lost Hunter", "Beach Warrior", "Beach Brawler", "Flame Worshipper",
    "Volcano Warrior", "Crimson Swordsman", "Fire Spirit",
}
local bossNames = {"Stone Eye", "Mole Rat", "The Crimson Flame", "Crimson Flame", "Master of the Swamp", "Sandy Storm", "Beach King", "Black Blick"}
local selectedEnemy = "Zombie"
local selectedOre = "Iron"
local oreTypes = {"Iron", "Aluminium", "Ruby", "Gold", "Lime Stone", "Refined Stone"}

local function findEnemyByName(name)
    local myRoot = getRoot()
    if not myRoot then return nil end
    local best, bestDistance = nil, math.huge
    -- The scan placed the combat NPCs directly under Workspace (for example Workspace.Zombie).
    -- Use direct children first to keep scans light on mobile.
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == name and isAliveNPC(model) then
            local root = rootOf(model)
            local distance = root and (root.Position - myRoot.Position).Magnitude
            if distance and distance < bestDistance then best, bestDistance = model, distance end
        end
    end
    return best, bestDistance
end

local objectivePath = {"QuestsHud", "QuestHolder", "Objectives", "ObjectiveScroller", "Objective", "ObjectiveName"}
local function descend(root, names)
    local current = root
    for _, name in ipairs(names) do current = current and current:FindFirstChild(name) end
    return current
end
local function getActiveObjective()
    local direct = descend(PlayerGui, objectivePath)
    if direct and direct:IsA("TextLabel") and direct.Text ~= "" then return direct.Text end
    local holder = descend(PlayerGui, {"QuestsHud", "QuestHolder"})
    if holder then
        for _, obj in ipairs(holder:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible and obj.Text ~= "" then
                local txt = lower(obj.Text)
                if string.find(txt, "defeat", 1, true) or string.find(txt, "derrote", 1, true) or string.find(txt, "rushdown", 1, true) then return obj.Text end
            end
        end
    end
    return nil
end
local function enemyFromObjective(text)
    local t = lower(text)
    if string.find(t, "big zombie", 1, true) then return "Big Zombie" end
    if string.find(t, "zombie", 1, true) then return "Zombie" end
    if string.find(t, "stone soldier", 1, true) then return "Stone Soldier" end
    if string.find(t, "green goblin", 1, true) then return "Green Goblin" end
    if string.find(t, "forest brawler", 1, true) then return "Forest Brawler" end
    if string.find(t, "cave brawler", 1, true) then return "Cave Brawler" end
    if string.find(t, "angry farmer", 1, true) then return "Angry Farmer" end
    if string.find(t, "farm keeper", 1, true) then return "Farm Keeper" end
    if string.find(t, "chief farmer", 1, true) then return "Chief Farmer" end
    if string.find(t, "phantom raider", 1, true) then return "Phantom Raider" end
    if string.find(t, "port invader", 1, true) then return "Port Invader" end
    if string.find(t, "port marksman", 1, true) then return "Port Marksman" end
    if string.find(t, "fox bear hunter", 1, true) then return "Fox Bear Hunter" end
    if string.find(t, "lost hunter", 1, true) then return "Lost Hunter" end
    if string.find(t, "beach warrior", 1, true) then return "Beach Warrior" end
    if string.find(t, "beach brawler", 1, true) then return "Beach Brawler" end
    if string.find(t, "flame worshipper", 1, true) then return "Flame Worshipper" end
    if string.find(t, "volcano warrior", 1, true) then return "Volcano Warrior" end
    if string.find(t, "crimson swordsman", 1, true) then return "Crimson Swordsman" end
    if string.find(t, "fire spirit", 1, true) then return "Fire Spirit" end
    if string.find(t, "stone eye", 1, true) then return "Stone Eye" end
    if string.find(t, "mole rat", 1, true) then return "Mole Rat" end
    if string.find(t, "crimson flame", 1, true) then return "Crimson Flame" end
    if string.find(t, "master of the swamp", 1, true) then return "Master of the Swamp" end
    if string.find(t, "sandy storm", 1, true) then return "Sandy Storm" end
    if string.find(t, "beach king", 1, true) then return "Beach King" end
    if string.find(t, "black blick", 1, true) then return "Black Blick" end
    return nil
end

local function findToolByName(names)
    local character = getCharacter()
    local backpack = LP:FindFirstChildOfClass("Backpack")
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                local n = lower(item.Name)
                for _, wanted in ipairs(names) do if n == lower(wanted) then return item end end
            end
        end
    end
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local n = lower(item.Name)
                for _, wanted in ipairs(names) do if n == lower(wanted) then return item end end
            end
        end
    end
    return nil
end
local function equipTool(tool)
    if not tool then return false end
    if tool.Parent == getCharacter() then return true end
    local hum = getHumanoid()
    if not hum then return false end
    local ok = pcall(function() hum:EquipTool(tool) end)
    return ok and tool.Parent == getCharacter()
end
local function chooseWeapon()
    local candidates = {}
    local backpack = LP:FindFirstChildOfClass("Backpack")
    local character = getCharacter()
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute("CombatTool") == true then
                    local stat = lower(item:GetAttribute("Stat"))
                    if stat == "weapon" or lower(item.Name) == "fists" then table.insert(candidates, item) end
                end
            end
        end
    end
    for _, item in ipairs(candidates) do if lower(item.Name) == "archive sword" then return item end end
    for _, item in ipairs(candidates) do if lower(item.Name) == "fists" then return item end end
    return candidates[1]
end

local function activateTool(tool)
    if not tool then return false end
    local ok = pcall(function() tool:Activate() end)
    return ok
end
local function moveNear(position, distance)
    local hum, root = getHumanoid(), getRoot()
    if not hum or not root then return false end
    local direction = root.Position - position
    if direction.Magnitude < 0.1 then direction = Vector3.new(0, 0, 1) end
    local destination = position + direction.Unit * (distance or 6)
    return pcall(function() hum:MoveTo(destination) end)
end

-- Board and Accept paths confirmed by the user's scan.
local function isGuiVisible(object)
    local current = object
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end
local function getAcceptButton()
    local buttonObject = descend(PlayerGui, {"QuestGui", "QuestBoard", "Container", "Accept"})
    if buttonObject and buttonObject:IsA("GuiButton") and isGuiVisible(buttonObject) then return buttonObject end
    return nil
end
local function acceptSelectedQuest()
    local accept = getAcceptButton()
    if not accept then return false end
    return pcall(function() accept:Activate() end)
end
local function activatePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(0.12, prompt.HoldDuration + 0.08))
        prompt:InputHoldEnd()
    end)
    return ok
end
local function nearestBoardPrompt()
    local root = getRoot()
    local boards = descend(Workspace, {"World", "Quest Boards"})
    if not root or not boards then return nil, math.huge end
    local best, bestDistance = nil, math.huge
    for _, obj in ipairs(boards:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and lower(obj.ActionText) == "view quest board" and obj.Enabled then
            local part = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart", true))
            local distance = part and (part.Position - root.Position).Magnitude
            if distance and distance < bestDistance then best, bestDistance = obj, distance end
        end
    end
    return best, bestDistance
end

-- Quest target matching: use the actual objective text, not a fixed Forest/Cave filter.
local function farmStep(targetName)
    local enemyName = targetName
    if not enemyName then
        local objective = getActiveObjective()
        enemyName = objective and enemyFromObjective(objective) or nil
    end
    if not enemyName then say("No supported kill objective. Choose a target in Farm or select a kill quest.", C.gold); return false end
    local target, distance = findEnemyByName(enemyName)
    if not target then say("No living " .. enemyName .. " found in Workspace", C.muted); return false end
    local targetRoot = rootOf(target)
    if not targetRoot then return false end
    if distance > 280 then say(enemyName .. " is too far (" .. math.floor(distance) .. " studs)", C.gold); return false end
    if distance > 10 then
        moveNear(targetRoot.Position, 5)
        say("Moving to " .. enemyName .. " • " .. math.floor(distance) .. " studs", C.accent)
    else
        local weapon = chooseWeapon()
        if not weapon then say("No verified combat Tool found. Equip a weapon manually.", C.red); return false end
        if equipTool(weapon) then
            activateTool(weapon)
            say("Attack attempt: " .. enemyName .. " with " .. weapon.Name, C.accent)
        else
            say("Could not equip " .. weapon.Name, C.red)
        end
    end
    return true
end

-- Mining uses only the ore folders and tool name confirmed in the scan.
local function nearestOre(oreName)
    local root = getRoot()
    if not root then return nil, math.huge end
    local best, bestDistance = nil, math.huge
    local oreFolder = Workspace:FindFirstChild(oreName)
    if not oreFolder then return nil, math.huge end
    for _, obj in ipairs(oreFolder:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Transparency < 1 then
            local d = (obj.Position - root.Position).Magnitude
            if d < bestDistance then best, bestDistance = obj, d end
        end
    end
    return best, bestDistance
end
local function mineStep()
    local pickaxe = findToolByName({"Super PickAxe", "PickAxe", "Pickaxe"})
    if not pickaxe then say("No pickaxe Tool found; your scan showed Super PickAxe in Backpack", C.red); return false end
    local ore, distance = nearestOre(selectedOre)
    if not ore then say("No " .. selectedOre .. " ore part found. Choose another ore.", C.muted); return false end
    if distance > 10 then
        moveNear(ore.Position, 5)
        say("Moving to " .. selectedOre .. " • " .. math.floor(distance) .. " studs", C.accent)
    else
        if equipTool(pickaxe) then
            activateTool(pickaxe)
            say("Mining attempt: " .. selectedOre .. " with " .. pickaxe.Name, C.accent)
        else
            say("Could not equip pickaxe", C.red)
        end
    end
    return true
end

-- Read-only build helpers based on the confirmed PlayerGui paths.
local function textAt(path)
    local object = descend(PlayerGui, path)
    if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then return object.Text end
    return nil
end
local function readBuildInfo()
    local stats = {}
    local statNames = {"Strength", "Durability", "Nen", "Weapons", "Stamina"}
    for _, statName in ipairs(statNames) do
        local text = textAt({"Inventory", "Inventory", "CharacterTab", "Tab", "Sub", statName, "Name"})
        local value = text and tonumber(string.match(text, "(%d+)%s*$"))
        stats[statName] = value
    end
    local pointsText = textAt({"Inventory", "Inventory", "CharacterTab", "AP"})
    local points = pointsText and tonumber(string.match(pointsText, "(%d+)%s*Stat Points"))
    local nenType = textAt({"Main", "SkillTrees", "Info", "NenType"})
    local skillPointsText = textAt({"Main", "SkillTrees", "Info", "SkillPoints"})
    local skillPoints = skillPointsText and tonumber(skillPointsText)
    return stats, points, nenType, skillPoints
end
local function buildRecommendation()
    local stats, points = readBuildInfo()
    local amount = points or 8
    local weaponPoints = math.floor(amount / 2)
    local nenPoints = amount - weaponPoints
    local values = {}
    for key, value in pairs(stats) do values[#values + 1] = key .. ": " .. tostring(value or "not visible") end
    table.sort(values)
    say("Current: " .. table.concat(values, " | ") .. " • Available: " .. tostring(points or "?") .. " • Suggestion: +" .. weaponPoints .. " Weapons, +" .. nenPoints .. " Nen", C.accent)
end

-- State.
local autoFarmOn, autoQuestOn, autoMineOn, autoChestOn = false, false, false, false
local pEspOn, nEspOn = false, false
local speedOn, jumpOn, noclipOn = false, false, false
local oldSpeed, oldJump = nil, nil
local oldCollision = {}
local savedWaypoint = nil
local lastQuestAction, lastFarmAction, lastMineAction, lastChestAction = 0, 0, 0, 0
local function stopAutomation()
    autoFarmOn, autoQuestOn, autoMineOn, autoChestOn = false, false, false, false
end

-- Lightweight ESP for mobile.
local esp = {}
local function removeEsp(model)
    local data = esp[model]
    if data then
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
        esp[model] = nil
    end
end
local function clearEsp(kind)
    for model, data in pairs(esp) do if not kind or data.kind == kind then removeEsp(model) end end
end
local function addEsp(model, kind, color)
    if esp[model] or not model.Parent then return end
    local adornee = model:FindFirstChild("Head") or rootOf(model)
    if not adornee then return end
    local highlight = new("Highlight", {Adornee = model, FillColor = color, OutlineColor = color, FillTransparency = 0.86, OutlineTransparency = 0.14}, Workspace)
    local billboard = new("BillboardGui", {Adornee = adornee, Size = UDim2.fromOffset(170, 22), StudsOffset = Vector3.new(0, 2.7, 0), AlwaysOnTop = true}, PlayerGui)
    new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = color, TextStrokeTransparency = 0.3, TextSize = 10, Text = kind .. " " .. model.Name}, billboard)
    esp[model] = {highlight = highlight, billboard = billboard, kind = kind}
end

local function restoreNoclip()
    for part, value in pairs(oldCollision) do if part and part.Parent then part.CanCollide = value end end
    table.clear(oldCollision)
end
RunService.Stepped:Connect(function()
    if noclipOn and getCharacter() then
        for _, part in ipairs(getCharacter():GetDescendants()) do
            if part:IsA("BasePart") then
                if oldCollision[part] == nil then oldCollision[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end)

-- One worker; slow polling is intentional for POCO X6 Pro/mobile thermals.
task.spawn(function()
    while gui.Parent do
        local ok, err = pcall(function()
            local now = os.clock()
            if autoQuestOn and now - lastQuestAction >= 1.2 then
                lastQuestAction = now
                local objective = getActiveObjective()
                local enemyName = objective and enemyFromObjective(objective)
                local current, total
                if objective then current, total = string.match(objective, "(%d+)%s*/%s*(%d+)") end
                if enemyName then
                    if current and total and tonumber(current) >= tonumber(total) then
                        say("Quest counter complete • return to board to claim", C.accent)
                    elseif now - lastFarmAction >= 0.8 then
                        lastFarmAction = now
                        farmStep(enemyName)
                    end
                else
                    local accept = getAcceptButton()
                    if accept then
                        pcall(function() accept:Activate() end)
                        say("Pressed Accept on the currently selected board mission. Choose the card manually first.", C.accent)
                    else
                        local prompt, distance = nearestBoardPrompt()
                        local root = getRoot()
                        local part = prompt and prompt.Parent and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true))
                        if prompt and part and root then
                            if distance <= (prompt.MaxActivationDistance + 1) then
                                activatePrompt(prompt)
                                say("Opened nearby quest board. Select a mission card; hub will press Accept.", C.accent)
                            else
                                say("Go near a quest board (" .. math.floor(distance) .. " studs) and choose a kill mission.", C.gold)
                            end
                        else
                            say("No quest board prompt found. Open a board manually.", C.gold)
                        end
                    end
                end
            elseif autoFarmOn and now - lastFarmAction >= 0.8 then
                lastFarmAction = now
                farmStep(selectedEnemy)
            end
            if autoMineOn and now - lastMineAction >= (touch and 1.4 or 1.0) then
                lastMineAction = now
                mineStep()
            end
            if autoChestOn and now - lastChestAction >= 1.5 then
                lastChestAction = now
                local backpack = LP:FindFirstChildOfClass("Backpack")
                local chestTool = nil
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") and string.find(lower(item.Name), "chest", 1, true) then chestTool = item; break end
                    end
                end
                if chestTool then
                    if equipTool(chestTool) then activateTool(chestTool); say("Chest activation attempted: " .. chestTool.Name, C.accent) end
                else
                    say("Chest names were visible in inventory UI, but no chest Tool was found in Backpack. Open them manually.", C.gold)
                    autoChestOn = false
                end
            end
            if pEspOn then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LP and player.Character and not esp[player.Character] then
                        addEsp(player.Character, "PLAYER", Color3.fromRGB(100, 190, 255))
                    end
                end
            else
                clearEsp("PLAYER")
            end
            if nEspOn then
                local count = 0
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if count >= (touch and 25 or 50) then break end
                    if obj:IsA("Model") and isAliveNPC(obj) then
                        addEsp(obj, "NPC", Color3.fromRGB(255, 205, 100))
                        count += 1
                    end
                end
            else
                clearEsp("NPC")
            end
        end)
        if not ok then warn("[Beyond Nen v0.7 worker] " .. tostring(err)) end
        task.wait(touch and 0.65 or 0.45)
    end
end)

local function openCraftingPrompt()
    local prompt = descend(Workspace, {"World", "CraftingNpcs", "Crafting", "HumanoidRootPart", "ProximityPrompt"})
    if not prompt then say("Crafting NPC prompt not found at scanned path", C.red); return end
    local root = getRoot()
    local part = prompt.Parent
    local distance = root and part and (part.Position - root.Position).Magnitude
    if distance and distance <= prompt.MaxActivationDistance + 1 then
        activatePrompt(prompt)
        say("Opened Crafting NPC. Review recipe, materials, level and confirm manually.", C.accent)
    else
        say("Blacksmith is " .. tostring(distance and math.floor(distance) or "far") .. " studs away. Travel to Port Town first.", C.gold)
    end
end

local function openPage(name)
    clearPage()
    if name == "Home" then
        section("Welcome, " .. LP.Name, "v0.7 built from your live scans. Android layout is touch-sized and can be minimized.")
        section("Confirmed paths", "Quest Accept: PlayerGui.QuestGui.QuestBoard.Container.Accept • Tracker: PlayerGui.QuestsHud.QuestHolder • Craft NPC: Workspace.World.CraftingNpcs.Crafting")
        button("Read active quest objective", function()
            local objective = getActiveObjective()
            say(objective or "No active objective visible", objective and C.accent or C.gold)
        end)
        button("Show build recommendation", buildRecommendation, C.blue)
        section("Limits", "Auto Quest accepts the currently selected card; you must select the mission card yourself. Craft/Stats/Skill Tree controls are not fully mapped yet.", C.gold)
        button("Stop all automation", function() stopAutomation(); say("All automation stopped", C.red) end, C.red)
    elseif name == "Quests" then
        section("Auto Quest", "The scan confirmed QuestGui.QuestBoard.Container.Accept. Select the desired mission on the board once; the hub can press Accept and then farm supported kill objectives.")
        toggle("Auto Quest (accept + farm objective)", autoQuestOn, function(value)
            autoQuestOn = value
            if value then autoFarmOn = false; autoMineOn = false end
            say(value and "Auto Quest on • open/select a kill quest" or "Auto Quest off", value and C.accent or C.muted)
        end)
        button("Press Accept on selected quest", function()
            if acceptSelectedQuest() then say("Accept button activated", C.accent) else say("QuestGui Accept not visible. Open board and select a mission first.", C.gold) end
        end)
        button("Read quest tracker", function()
            local objective = getActiveObjective()
            say(objective or "No objective label found", objective and C.accent or C.gold)
        end)
        button("Open nearest board (within range)", function()
            local prompt, distance = nearestBoardPrompt()
            if prompt and distance <= prompt.MaxActivationDistance + 1 then
                activatePrompt(prompt); say("Quest board prompt activated", C.accent)
            else
                say(prompt and ("Move closer: " .. math.floor(distance) .. " studs") or "No quest board prompt found", C.gold)
            end
        end)
        section("Selection limitation", "Your scan found the Accept button but did not expose the mission-card selection control. Select the card manually; the hub will accept it.", C.gold)
    elseif name == "Farm" then
        section("Auto Farm", "Uses the real mob names from your scans and the active quest objective when Auto Quest is enabled.")
        button("Target: " .. selectedEnemy .. " (tap to cycle)", function()
            local index = table.find(enemyGroups, selectedEnemy) or 1
            selectedEnemy = enemyGroups[index % #enemyGroups + 1]
            openPage("Farm")
            say("Farm target: " .. selectedEnemy, C.accent)
        end, C.blue)
        toggle("Auto Farm selected enemy", autoFarmOn, function(value)
            autoFarmOn = value
            if value then autoQuestOn = false; autoMineOn = false end
            say(value and ("Farming " .. selectedEnemy) or "Auto Farm off", value and C.accent or C.muted)
        end)
        button("Find nearest " .. selectedEnemy, function()
            local model, distance = findEnemyByName(selectedEnemy)
            say(model and (model.Name .. " • " .. math.floor(distance) .. " studs") or "No matching living enemy", model and C.accent or C.gold)
        end)
        button("Equip verified weapon (Archive Sword / Fists)", function()
            local weapon = chooseWeapon()
            if weapon and equipTool(weapon) then say("Equipped " .. weapon.Name, C.accent) else say("No verified combat weapon available", C.red) end
        end)
        section("Known targets", "Mines: Zombie, Big Zombie, Stone Soldier, Green Goblin. Other boards: Forest/Cave Brawler, Farmers, Phantom Raider, Port Invader, Flame Worshipper, Volcano Warrior and more.")
    elseif name == "Mining" then
        section("Auto Mine", "Ore roots confirmed: Workspace.Iron, Aluminium, Ruby, Gold, Lime Stone and Refined Stone. Scan also found Super PickAxe.")
        button("Ore: " .. selectedOre .. " (tap to cycle)", function()
            local index = table.find(oreTypes, selectedOre) or 1
            selectedOre = oreTypes[index % #oreTypes + 1]
            openPage("Mining")
            say("Mining target: " .. selectedOre, C.accent)
        end, C.blue)
        toggle("Auto Mine selected ore", autoMineOn, function(value)
            autoMineOn = value
            if value then autoFarmOn = false; autoQuestOn = false end
            say(value and ("Mining " .. selectedOre) or "Auto Mine off", value and C.accent or C.muted)
        end)
        button("Find nearest " .. selectedOre, function()
            local ore, distance = nearestOre(selectedOre)
            say(ore and (selectedOre .. " • " .. math.floor(distance) .. " studs") or "No matching ore part found", ore and C.accent or C.gold)
        end)
        button("Equip Super PickAxe", function()
            local pickaxe = findToolByName({"Super PickAxe", "PickAxe", "Pickaxe"})
            if pickaxe and equipTool(pickaxe) then say("Equipped " .. pickaxe.Name, C.accent) else say("Pickaxe not found in Backpack/Character", C.red) end
        end)
        section("Mining caveat", "Auto Mine approaches the visible ore and tries normal Tool activation. Your scan did not reveal the server-side mining handler; the game may still require aiming/tapping the ore manually.", C.gold)
    elseif name == "Craft" then
        section("Crafting", "Your scan found Workspace.World.CraftingNpcs.Crafting.HumanoidRootPart.ProximityPrompt. The crafting screen itself was not captured.")
        button("Open nearby Blacksmith interaction", openCraftingPrompt, C.blue)
        section("Craft checklist", "Recipe + (usually) Schematic + materials + level + Jenny at the Port Town Blacksmith. Check the live Recipe Book before crafting.")
        button("List recipe/schematic Tools", function()
            local backpack = LP:FindFirstChildOfClass("Backpack")
            local names = {}
            if backpack then
                for _, item in ipairs(backpack:GetChildren()) do
                    if item:IsA("Tool") and (string.find(lower(item.Name), "recipe", 1, true) or string.find(lower(item.Name), "schematic", 1, true)) then
                        names[#names + 1] = item.Name
                    end
                end
            end
            say(#names > 0 and table.concat(names, " | ") or "No recipe Tools visible in Backpack", C.accent)
        end)
        section("Not automated", "Craft button, material slots, Recipe Book level field and confirmation control were not exposed in the scan. Manual review avoids spending materials blindly.", C.gold)
    elseif name == "Build" then
        section("Hybrid / Max Damage", "Your scan showed 8 Stat Points, Nen Type Specialist, 12 Skill Points and current combat style Fists.")
        button("Read current stats + recommendation (+4 Weapons / +4 Nen)", buildRecommendation, C.blue)
        button("Read Nen type and skill points", function()
            local _, points, nenType, skillPoints = readBuildInfo()
            say("Nen: " .. tostring(nenType) .. " • Skill Points: " .. tostring(skillPoints) .. " • Stat Points: " .. tostring(points), C.accent)
        end)
        section("Auto Stats", "Suggested for the 8 points you reported: +4 Weapons and +4 Nen. The plus/confirm button paths were not in the report, so this helper does not spend points automatically.", C.gold)
        section("Auto Skill Tree", "The visible tree says current combat style Fists. Skill nodes and prerequisites were not captured, so automatic unlocking could spend points on the wrong branch.", C.gold)
        button("Equip Archive Sword if available", function()
            local sword = findToolByName({"Archive Sword"})
            if sword and equipTool(sword) then say("Archive Sword equipped. Verify the active combat style in game.", C.accent) else say("Archive Sword not found", C.gold) end
        end)
    elseif name == "Chests" then
        section("Chest inventory", "Your Inventory UI showed Common, Uncommon, Rare and Legendary Chests. Tool scan did not find chest items as Backpack Tools.")
        button("List visible chest items", function()
            local inventory = descend(PlayerGui, {"Inventory", "Inventory", "ItemScroller", "Holder"})
            local counts = {}
            if inventory then
                for _, item in ipairs(inventory:GetChildren()) do
                    local label = item:FindFirstChild("ItemName", true)
                    if label and label:IsA("TextLabel") and string.find(lower(label.Text), "chest", 1, true) then
                        counts[label.Text] = (counts[label.Text] or 0) + 1
                    end
                end
            end
            local out = {}
            for itemName, count in pairs(counts) do out[#out + 1] = itemName .. " x" .. count end
            table.sort(out)
            say(#out > 0 and table.concat(out, " | ") or "Open Inventory; chest labels not visible", C.accent)
        end)
        toggle("Auto Open Chest Tools (if present)", autoChestOn, function(value)
            autoChestOn = value
            say(value and "Looking for chest Tools in Backpack" or "Auto chest off", value and C.accent or C.muted)
        end)
        section("Chest caveat", "The scan found chest labels in inventory slots but not their item-use control or a chest Tool. If these are data records, Tool activation cannot open them.", C.gold)
    elseif name == "ESP" then
        section("Visuals", "Low-frequency mobile ESP with a capped number of overlays.")
        toggle("NPC ESP", nEspOn, function(value) nEspOn = value; if not value then clearEsp("NPC") end; say("NPC ESP " .. (value and "ON" or "OFF"), C.accent) end)
        toggle("Player ESP", pEspOn, function(value) pEspOn = value; if not value then clearEsp("PLAYER") end; say("Player ESP " .. (value and "ON" or "OFF"), C.accent) end)
        button("Clear ESP", function() pEspOn = false; nEspOn = false; clearEsp(); say("ESP cleared", C.accent) end, C.red)
    elseif name == "Utility" then
        section("Mobile utility", "Touch-sized buttons, draggable window and minimize/restore.")
        button("Save current waypoint", function() local root = getRoot(); if root then savedWaypoint = root.CFrame; say("Waypoint saved", C.accent) end end)
        button("Return to waypoint", function() local root = getRoot(); if root and savedWaypoint then root.CFrame = savedWaypoint; say("Returned to waypoint (server may correct)", C.accent) else say("No waypoint saved", C.gold) end end)
        toggle("WalkSpeed helper (24)", speedOn, function(value)
            speedOn = value; local hum = getHumanoid()
            if hum then if value then oldSpeed = oldSpeed or hum.WalkSpeed; hum.WalkSpeed = 24 elseif oldSpeed then hum.WalkSpeed = oldSpeed; oldSpeed = nil end end
            say(value and "WalkSpeed changed locally" or "WalkSpeed restored", C.accent)
        end)
        toggle("JumpPower helper (60)", jumpOn, function(value)
            jumpOn = value; local hum = getHumanoid()
            if hum then if value then oldJump = oldJump or hum.JumpPower; hum.UseJumpPower = true; hum.JumpPower = 60 elseif oldJump then hum.JumpPower = oldJump; oldJump = nil end end
            say(value and "JumpPower changed locally" or "JumpPower restored", C.accent)
        end)
        toggle("Noclip helper", noclipOn, function(value) noclipOn = value; if not value then restoreNoclip() end; say("Noclip " .. (value and "ON" or "OFF"), C.accent) end)
        button("Restore movement", function()
            speedOn, jumpOn, noclipOn = false, false, false
            local hum = getHumanoid()
            if hum then if oldSpeed then hum.WalkSpeed = oldSpeed end; if oldJump then hum.JumpPower = oldJump end end
            oldSpeed, oldJump = nil, nil; restoreNoclip(); say("Movement restored", C.accent); openPage("Utility")
        end, C.red)
    end
end

local tabs = {"Home", "Quests", "Farm", "Mining", "Craft", "Build", "Chests", "ESP", "Utility"}
for index, name in ipairs(tabs) do
    local tab = new("TextButton", {
        Name = "Tab_" .. name, Size = UDim2.new(1, 0, 0, buttonHeight), BackgroundColor3 = index == 1 and C.green or C.panel2,
        BorderSizePixel = 0, Font = Enum.Font.GothamSemibold, Text = name, TextColor3 = C.text,
        TextSize = math.floor(10 * fontScale), TextWrapped = true, LayoutOrder = index,
    }, sidebar)
    corner(tab, 7)
    tab.Activated:Connect(function()
        for _, child in ipairs(sidebar:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = C.panel2 end end
        tab.BackgroundColor3 = C.green
        openPage(name)
    end)
end

local closed = false
local function cleanup()
    if closed then return end
    closed = true
    stopAutomation()
    pEspOn, nEspOn = false, false
    clearEsp()
    restoreNoclip()
    local hum = getHumanoid()
    if hum then
        if oldSpeed then hum.WalkSpeed = oldSpeed end
        if oldJump then hum.JumpPower = oldJump end
    end
    gui:Destroy()
end
close.Activated:Connect(cleanup)

openPage("Home")
say("v0.7 loaded • built from your scans • no hidden remote calls", C.accent)
print("[Beyond Nen Progression Hub] v0.7 loaded for PlaceId 78073853031462")

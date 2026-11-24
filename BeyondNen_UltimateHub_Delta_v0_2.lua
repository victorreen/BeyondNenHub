-- Beyond Nen Field Tracker v0.8 - mobile/read-only helper
-- Built from the user's live diagnostic reports for PlaceId 78073853031462.
-- Reads visible Workspace/PlayerGui/Backpack data only.
-- No RemoteEvent/RemoteFunction calls, no HTTP, no loadstring, no movement, no attacks,
-- no noclip, no prompt activation, no inventory changes, and no anti-cheat bypass.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer
if not LP then return end

local PLAYER_GUI = LP:WaitForChild("PlayerGui")
local GUI_NAME = "BeyondNenFieldTrackerV08"
local previous = PLAYER_GUI:FindFirstChild(GUI_NAME)
if previous then previous:Destroy() end

local TOUCH = UserInputService.TouchEnabled
local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(900, 700)
local width = math.floor(math.clamp(viewport.X * (TOUCH and 0.96 or 0.76), 330, 720))
local height = math.floor(math.clamp(viewport.Y * (TOUCH and 0.78 or 0.78), 390, 680))
height = math.min(height, math.max(360, viewport.Y - 16))
local portrait = viewport.X < viewport.Y
local compact = width < 470
local buttonHeight = TOUCH and 42 or 34
local fontScale = math.clamp(viewport.X / 430, 0.86, 1.18)

local COLORS = {
    bg = Color3.fromRGB(16, 19, 25),
    panel = Color3.fromRGB(25, 30, 39),
    panel2 = Color3.fromRGB(36, 43, 54),
    green = Color3.fromRGB(75, 184, 139),
    accent = Color3.fromRGB(140, 230, 184),
    text = Color3.fromRGB(239, 243, 247),
    muted = Color3.fromRGB(165, 174, 187),
    red = Color3.fromRGB(189, 75, 82),
    gold = Color3.fromRGB(223, 178, 85),
    blue = Color3.fromRGB(103, 170, 232),
}

local function create(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function addCorner(obj, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function fmtDistance(number)
    if not number then return "?" end
    return string.format("%.0f studs", number)
end

local function getRoot(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
end

local function getHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end

local function getMyRoot()
    return getRoot(LP.Character)
end

local function isPlayerCharacter(model)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then return true end
    end
    return false
end

local function fullName(instance)
    local ok, result = pcall(function() return instance:GetFullName() end)
    return ok and result or instance.Name
end

local enemyNames = {
    ["zombie"] = true, ["big zombie"] = true, ["stone soldier"] = true,
    ["green goblin"] = true, ["forest brawler"] = true, ["cave brawler"] = true,
    ["angry farmer"] = true, ["farm keeper"] = true, ["chief farmer"] = true,
    ["phantom raider"] = true, ["port invader"] = true, ["port marksman"] = true,
    ["fox bear hunter"] = true, ["foxbear hunter"] = true, ["lost hunter"] = true,
    ["beach warrior"] = true, ["beach brawler"] = true, ["flame worshipper"] = true,
    ["volcano warrior"] = true, ["crimson swordsman"] = true, ["fire spirit"] = true,
}

local bossNames = {
    ["stone eye"] = true, ["mole rat"] = true, ["the mole rat"] = true,
    ["crimson flame"] = true, ["the crimson flame"] = true,
    ["master of the swamp"] = true, ["sandy storm"] = true,
    ["beach king"] = true, ["black blick"] = true,
}

local oreNames = {"Iron", "Gold", "Ruby", "Aluminium", "Lime Stone", "Refined Stone"}
local oreLookup = {}
for _, name in ipairs(oreNames) do oreLookup[lower(name)] = name end

local trackedInstance = nil
local pageRoute -- forward declaration for buttons created on earlier pages
local globalConnections = {}
local trackedTitle = "No target selected"
local trackedKind = "Route"
local lastNpcResults = {}
local lastOreResults = {}
local lastQuestResults = {}
local refreshBusy = false
local currentPage = "Home"
local alive = true

local gui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 10000,
}, PLAYER_GUI)

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(width, height),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.53),
    BackgroundColor3 = COLORS.bg,
    BorderSizePixel = 0,
}, gui)
addCorner(main, 12)
create("UIStroke", {Color = COLORS.green, Transparency = 0.2, Thickness = 1.3}, main)

local top = create("Frame", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
}, main)
addCorner(top, 12)
create("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(11, 0),
    Size = UDim2.new(1, -104, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "BEYOND NEN / FIELD TRACKER v0.8",
    TextColor3 = COLORS.text,
    TextSize = math.floor(12 * fontScale),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, top)

local minimize = create("TextButton", {
    Name = "Minimize", Position = UDim2.new(1, -79, 0, 7), Size = UDim2.fromOffset(31, 30),
    BackgroundColor3 = COLORS.panel2, Text = "−", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold, TextSize = 20, BorderSizePixel = 0,
}, top)
addCorner(minimize, 7)
local close = create("TextButton", {
    Name = "Close", Position = UDim2.new(1, -42, 0, 7), Size = UDim2.fromOffset(31, 30),
    BackgroundColor3 = COLORS.red, Text = "×", TextColor3 = COLORS.text,
    Font = Enum.Font.GothamBold, TextSize = 20, BorderSizePixel = 0,
}, top)
addCorner(close, 7)

local sidebarWidth = compact and 91 or 125
local sidebar = create("Frame", {
    Name = "Sidebar", Position = UDim2.fromOffset(8, 52),
    Size = UDim2.new(0, sidebarWidth, 1, -61),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
}, main)
addCorner(sidebar, 8)
create("UIPadding", {
    PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
}, sidebar)
create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)

local content = create("ScrollingFrame", {
    Name = "Content", Position = UDim2.fromOffset(sidebarWidth + 16, 52),
    Size = UDim2.new(1, -(sidebarWidth + 24), 1, -89),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
    ScrollBarThickness = TOUCH and 3 or 5,
    ScrollBarImageColor3 = COLORS.green,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, main)
addCorner(content, 8)
create("UIPadding", {
    PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, content)
local contentLayout = create("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, content)

local status = create("TextLabel", {
    Name = "Status", Position = UDim2.new(0, sidebarWidth + 17, 1, -30),
    Size = UDim2.new(1, -(sidebarWidth + 25), 0, 22),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham,
    Text = "Ready • read-only", TextColor3 = COLORS.muted,
    TextSize = math.floor(10 * fontScale), TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, main)

local function setStatus(text, color)
    if status and status.Parent then
        status.Text = tostring(text)
        status.TextColor3 = color or COLORS.muted
    end
end

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= contentLayout and not child:IsA("UIPadding") then child:Destroy() end
    end
end

local function section(title, description, color)
    local frameHeight = description and 60 or 34
    local frame = create("Frame", {
        Size = UDim2.new(1, -2, 0, frameHeight),
        BackgroundColor3 = COLORS.panel2, BorderSizePixel = 0,
    }, content)
    addCorner(frame, 7)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 7),
    }, frame)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, Text = title, TextColor3 = color or COLORS.accent,
        TextSize = math.floor(12 * fontScale), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)
    if description then
        create("TextLabel", {
            Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            Text = description, TextColor3 = COLORS.muted,
            TextSize = math.floor(10 * fontScale), TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        }, frame)
    end
    return frame
end

local function actionButton(text, callback, color)
    local button = create("TextButton", {
        Size = UDim2.new(1, -2, 0, buttonHeight),
        BackgroundColor3 = color or COLORS.panel2, BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold, Text = text, TextColor3 = COLORS.text,
        TextSize = math.floor(11 * fontScale), TextWrapped = true, AutoButtonColor = true,
    }, content)
    addCorner(button, 7)
    button.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then
            warn("[Beyond Nen Field Tracker] " .. tostring(err))
            setStatus("Error: " .. tostring(err), COLORS.red)
        end
    end)
    return button
end

local function outputBox(defaultText, boxHeight)
    local box = create("TextBox", {
        Size = UDim2.new(1, -2, 0, boxHeight or 180),
        BackgroundColor3 = Color3.fromRGB(12, 15, 20),
        BorderSizePixel = 0, ClearTextOnFocus = false,
        Font = Enum.Font.Code, Text = defaultText or "",
        TextColor3 = COLORS.text, TextSize = math.floor(10 * fontScale),
        TextWrapped = false, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true,
    }, content)
    addCorner(box, 7)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7),
    }, box)
    return box
end

local function getDistanceFromMe(part)
    local root = getMyRoot()
    if not root or not part then return nil end
    return (part.Position - root.Position).Magnitude
end

local function listQuestBoards()
    local results = {}
    local world = Workspace:FindFirstChild("World")
    local boards = world and world:FindFirstChild("Quest Boards")
    if not boards then return results end

    for _, board in ipairs(boards:GetChildren()) do
        local boardPart = board:FindFirstChild("Board")
        local interactor = board:FindFirstChild("Interactor")
        local prompt = interactor and interactor:FindFirstChildOfClass("ProximityPrompt")
        local boardRoot = boardPart and (boardPart:IsA("BasePart") and boardPart or boardPart:FindFirstChildWhichIsA("BasePart", true))
        if not boardRoot then boardRoot = board:FindFirstChildWhichIsA("BasePart", true) end
        local boardDistance = getDistanceFromMe(boardRoot)

        if boardPart then
            for _, card in ipairs(boardPart:GetChildren()) do
                for _, descendant in ipairs(card:GetDescendants()) do
                    if descendant:IsA("TextLabel") and descendant.Name == "Title" then
                        local title = descendant.Text or ""
                        if title ~= "" then
                            table.insert(results, {
                                board = board.Name,
                                title = title,
                                distance = boardDistance,
                                promptEnabled = prompt and prompt.Enabled or false,
                                path = fullName(descendant),
                            })
                            break
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.distance or math.huge) < (b.distance or math.huge)
    end)
    return results
end

local function getActiveQuestText()
    local holder = PLAYER_GUI:FindFirstChild("QuestsHud")
    holder = holder and holder:FindFirstChild("QuestHolder")
    if not holder then return "Quest tracker not found" end
    local lines = {}
    for _, object in ipairs(holder:GetDescendants()) do
        if object:IsA("TextLabel") and object.Visible then
            local text = tostring(object.Text or "")
            if text ~= "" and text ~= "Quest Active" then
                table.insert(lines, text)
            end
        end
    end
    if #lines == 0 then return "No visible objective text" end
    return table.concat(lines, "\n")
end

local function getQuestAcceptState()
    local questGui = PLAYER_GUI:FindFirstChild("QuestGui")
    local board = questGui and questGui:FindFirstChild("QuestBoard")
    local container = board and board:FindFirstChild("Container")
    local accept = container and container:FindFirstChild("Accept")
    if not accept then return "Accept button not currently present" end
    local title = accept:FindFirstChild("Title", true)
    local titleText = title and title:IsA("TextLabel") and title.Text or "[Accept]"
    return string.format("%s | Visible=%s | Active=%s", titleText, tostring(accept.Visible), tostring(accept.Active))
end

local function scanNPCs()
    local results = {}
    local myRoot = getMyRoot()
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and not isPlayerCharacter(model) then
            local name = lower(model.Name)
            local isEnemy = enemyNames[name] == true
            local isBoss = bossNames[name] == true
            if isEnemy or isBoss then
                local humanoid = getHumanoid(model)
                local root = getRoot(model)
                if humanoid and humanoid.Health > 0 and root then
                    local distance = myRoot and (root.Position - myRoot.Position).Magnitude or nil
                    table.insert(results, {
                        model = model,
                        name = model.Name,
                        health = humanoid.Health,
                        maxHealth = humanoid.MaxHealth,
                        distance = distance,
                        isBoss = isBoss,
                        root = root,
                    })
                end
            end
        end
    end
    table.sort(results, function(a, b)
        return (a.distance or math.huge) < (b.distance or math.huge)
    end)
    return results
end

local function scanOres()
    local results = {}
    local myRoot = getMyRoot()
    for _, containerName in ipairs(oreNames) do
        local container = Workspace:FindFirstChild(containerName)
        if container then
            local parts = {}
            if container:IsA("BasePart") then table.insert(parts, container) end
            for _, descendant in ipairs(container:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    table.insert(parts, descendant)
                end
            end
            local bestPart, bestDistance = nil, math.huge
            for _, part in ipairs(parts) do
                local distance = myRoot and (part.Position - myRoot.Position).Magnitude or nil
                if distance and distance < bestDistance then
                    bestPart, bestDistance = part, distance
                end
            end
            if bestPart then
                table.insert(results, {
                    name = containerName,
                    part = bestPart,
                    distance = bestDistance,
                    count = #parts,
                    path = fullName(bestPart),
                })
            end
        end
    end
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

local function scanTools()
    local results = {}
    local containers = {LP:FindFirstChildOfClass("Backpack"), LP.Character}
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    local attrs = item:GetAttributes()
                    local display = attrs.DisplayName or item.Name
                    local category = attrs.Category or attrs.Type or "Item"
                    local rarity = attrs.Rarity or ""
                    local level = attrs.RequiredLevel or attrs.LevelRequirement or attrs.MinLevel or attrs.Level or "?"
                    table.insert(results, {
                        name = tostring(display),
                        rawName = item.Name,
                        category = tostring(category),
                        rarity = tostring(rarity),
                        level = tostring(level),
                        equipped = container == LP.Character,
                        handler = tostring(attrs.Handler or ""),
                        path = fullName(item),
                    })
                end
            end
        end
    end
    table.sort(results, function(a, b)
        if a.equipped ~= b.equipped then return a.equipped end
        return a.name < b.name
    end)
    return results
end

local function scanStats()
    local output = {}
    local inventory = PLAYER_GUI:FindFirstChild("Inventory")
    inventory = inventory and inventory:FindFirstChild("Inventory")
    local charTab = inventory and inventory:FindFirstChild("CharacterTab")
    local sub = charTab and charTab:FindFirstChild("Tab")
    sub = sub and sub:FindFirstChild("Sub")
    if sub then
        for _, stat in ipairs({"Strength", "Durability", "Nen", "Weapons", "Stamina"}) do
            local frame = sub:FindFirstChild(stat)
            local label = frame and frame:FindFirstChild("Name")
            if label and label:IsA("TextLabel") then
                table.insert(output, label.Text)
            end
        end
    end
    local statPoints = charTab and charTab:FindFirstChild("AP")
    if statPoints and statPoints:IsA("TextLabel") then
        table.insert(output, statPoints.Text)
    end

    local mainGui = PLAYER_GUI:FindFirstChild("Main")
    local skillTrees = mainGui and mainGui:FindFirstChild("SkillTrees")
    local info = skillTrees and skillTrees:FindFirstChild("Info")
    if info then
        for _, field in ipairs({"NenType", "SkillPoints"}) do
            local label = info:FindFirstChild(field)
            if label and label:IsA("TextLabel") then
                table.insert(output, field .. ": " .. label.Text)
            end
        end
    end
    if #output == 0 then return "Open Inventory / Stats / Skill Tree first, then refresh." end
    return table.concat(output, "\n")
end

local function scanChestItems(tools)
    local results = {}
    for _, tool in ipairs(tools) do
        if string.find(lower(tool.name), "chest", 1, true) then
            table.insert(results, string.format("%s | %s", tool.name, tool.equipped and "Equipped" or "Inventory"))
        end
    end
    if #results == 0 then return "No chest items detected in Backpack/Character." end
    return table.concat(results, "\n")
end

local function directionTo(part)
    local myRoot = getMyRoot()
    if not myRoot or not part then return "Direction unavailable" end
    local localPosition = myRoot.CFrame:PointToObjectSpace(part.Position)
    local horizontal = math.abs(localPosition.X) > math.abs(localPosition.Z) and "side" or "front/back"
    local lateral = localPosition.X > 0 and "right" or "left"
    local forward = localPosition.Z < 0 and "ahead" or "behind"
    if horizontal == "side" then return lateral end
    return forward
end

local function setTracked(instance, title, kind)
    if not instance or not instance.Parent then
        trackedInstance = nil
        trackedTitle = "No target selected"
        trackedKind = "Route"
        return
    end
    trackedInstance = instance
    trackedTitle = tostring(title or instance.Name)
    trackedKind = tostring(kind or "Target")
    setStatus("Tracking: " .. trackedTitle, COLORS.accent)
end

local function getTrackedPart()
    if not trackedInstance or not trackedInstance.Parent then return nil end
    if trackedInstance:IsA("BasePart") then return trackedInstance end
    if trackedInstance:IsA("Model") then return getRoot(trackedInstance) or trackedInstance:FindFirstChildWhichIsA("BasePart", true) end
    return trackedInstance:FindFirstChildWhichIsA("BasePart", true)
end

local function refreshAll()
    if refreshBusy then return end
    refreshBusy = true
    local ok, err = pcall(function()
        lastNpcResults = scanNPCs()
        lastOreResults = scanOres()
        lastQuestResults = listQuestBoards()
    end)
    refreshBusy = false
    if not ok then
        setStatus("Refresh failed: " .. tostring(err), COLORS.red)
    else
        setStatus(string.format("Updated • %d hostiles • %d ore groups • %d quest cards", #lastNpcResults, #lastOreResults, #lastQuestResults), COLORS.accent)
    end
end

local function pageHome()
    clearContent()
    section("Welcome, " .. LP.Name, "Field Tracker v0.8 • read-only helper for Beyond Nen. Mobile layout enabled.")
    section("Current character", "PlaceId: " .. tostring(game.PlaceId) .. " • Level is read from the game only when exposed in visible UI.", COLORS.blue)
    actionButton("Refresh all scanners", refreshAll, COLORS.green)
    actionButton("Show active quest objective", function()
        local report = getActiveQuestText()
        local acceptState = getQuestAcceptState()
        setStatus("Quest UI inspected", COLORS.accent)
        local box = outputBox("ACTIVE QUEST\n" .. report .. "\n\nQUEST BOARD UI\n" .. acceptState, 170)
    end)
    actionButton("Open route tracker", function()
        currentPage = "Route"
        pageRoute()
    end)
    section("Safety / scope", "This version does not attack, mine, open chests, craft, equip, spend points, teleport, fly, use noclip or trigger game prompts. It only reads visible client state.", COLORS.gold)
end

local function pageQuests()
    clearContent()
    section("Quest Board Scanner", "Reads Workspace.World[Quest Boards] cards and ranks them by board distance. It does not accept missions automatically.")
    actionButton("Scan quest boards", function()
        lastQuestResults = listQuestBoards()
        local lines = {}
        for index, quest in ipairs(lastQuestResults) do
            table.insert(lines, string.format("%02d. %s\n    %s\n    Board: %s | %s studs", index, quest.title, quest.board, fmtDistance(quest.distance), quest.promptEnabled and "Prompt enabled" or "Prompt unavailable"))
        end
        if #lines == 0 then table.insert(lines, "No quest card titles found. Stand in a loaded area and scan again.") end
        outputBox(table.concat(lines, "\n\n"), math.min(430, math.max(190, #lines * 54)))
        setStatus("Quest cards scanned: " .. tostring(#lastQuestResults), COLORS.accent)
    end, COLORS.green)
    actionButton("Read active quest progress", function()
        outputBox("ACTIVE OBJECTIVE\n" .. getActiveQuestText() .. "\n\nACCEPT UI\n" .. getQuestAcceptState(), 180)
        setStatus("Active quest read", COLORS.accent)
    end)
    section("Level guidance", "Your last reported level was 19 and you already have Hunter License. The tracker does not infer or change level restrictions; check locked boards in-game before choosing a card.", COLORS.gold)
end

local function pageTargets()
    clearContent()
    section("Hostile NPC Tracker", "Only the exact hostile names found in your scans are included. Player characters and named quest-givers are excluded.")
    actionButton("Scan hostiles", function()
        lastNpcResults = scanNPCs()
        local lines = {}
        for index, entry in ipairs(lastNpcResults) do
            local tag = entry.isBoss and "BOSS" or "MOB"
            table.insert(lines, string.format("%02d. [%s] %s\n    HP %.0f / %.0f | %s", index, tag, entry.name, entry.health, entry.maxHealth, fmtDistance(entry.distance)))
        end
        if #lines == 0 then table.insert(lines, "No known hostiles found. Make sure the area is loaded and scan again.") end
        outputBox(table.concat(lines, "\n\n"), math.min(500, math.max(200, #lines * 49)))
        setStatus("Hostiles found: " .. tostring(#lastNpcResults), COLORS.accent)
    end, COLORS.green)
    for index, entry in ipairs(lastNpcResults) do
        if index > 12 then break end
        actionButton(string.format("Track %s • %s", entry.name, fmtDistance(entry.distance)), function()
            setTracked(entry.model, entry.name, entry.isBoss and "Boss" or "Mob")
            currentPage = "Route"
            pageRoute()
        end, entry.isBoss and COLORS.red or COLORS.panel2)
    end
    if #lastNpcResults == 0 then section("Tip", "Press Scan Hostiles to populate the nearby NPC list.") end
end

local function pageMining()
    clearContent()
    section("Mining Tracker", "Reads ore containers found in your scan: Iron, Gold, Ruby, Aluminium, Lime Stone and Refined Stone. It does not mine or activate the pickaxe.")
    actionButton("Scan ore groups", function()
        lastOreResults = scanOres()
        local lines = {}
        for index, ore in ipairs(lastOreResults) do
            table.insert(lines, string.format("%02d. %s\n    Parts: %d | Nearest: %s\n    %s", index, ore.name, ore.count, fmtDistance(ore.distance), ore.path))
        end
        if #lines == 0 then table.insert(lines, "No ore containers found. Move to a loaded mining region and rescan.") end
        outputBox(table.concat(lines, "\n\n"), math.min(460, math.max(190, #lines * 55)))
        setStatus("Ore groups found: " .. tostring(#lastOreResults), COLORS.accent)
    end, COLORS.green)
    for index, ore in ipairs(lastOreResults) do
        if index > 8 then break end
        actionButton(string.format("Track %s • %s", ore.name, fmtDistance(ore.distance)), function()
            setTracked(ore.part, ore.name, "Ore")
            currentPage = "Route"
            pageRoute()
        end, COLORS.panel2)
    end
    section("Known pickaxe", "Your diagnostic found Super PickAxe in Backpack. Mining interaction still needs the game's documented control; this tracker will not simulate or bypass it.", COLORS.gold)
end

local function pageInventory()
    clearContent()
    section("Inventory / Equipment Reader", "Lists visible Tool objects, attributes, chest items and known build stats. It does not equip, consume or open items.")
    actionButton("Scan tools and chests", function()
        local tools = scanTools()
        local lines = {}
        for index, item in ipairs(tools) do
            table.insert(lines, string.format("%02d. %s %s\n    Category: %s | Rarity: %s | Required level field: %s\n    Handler: %s", index, item.equipped and "[EQUIPPED]" or "", item.name, item.category, item.rarity, item.level, item.handler))
        end
        if #lines == 0 then table.insert(lines, "No Tool objects found in Backpack/Character.") end
        table.insert(lines, "\nCHEST ITEMS\n" .. scanChestItems(tools))
        outputBox(table.concat(lines, "\n\n"), 380)
        setStatus("Tools found: " .. tostring(#tools), COLORS.accent)
    end, COLORS.green)
    actionButton("Read stats and skill tree", function()
        outputBox("CURRENT STATS / SKILL TREE\n" .. scanStats(), 190)
        setStatus("Stats and Skill Tree inspected", COLORS.accent)
    end)
    section("Build profile", "Hybrid / Max Damage • planned weights: Weapons 45%, Nen 45%, Stamina 10%. This is a planning preference, not an automatic point-spending action.", COLORS.gold)
end

local routeLabel
pageRoute = function()
    clearContent()
    section("Route Tracker", "Select a mob, boss, ore or board from its tab. This page calculates distance and relative direction only; it will not move your character.")
    routeLabel = create("TextLabel", {
        Size = UDim2.new(1, -2, 0, 120), BackgroundColor3 = Color3.fromRGB(12, 15, 20),
        BorderSizePixel = 0, Font = Enum.Font.Code, Text = "No target selected",
        TextColor3 = COLORS.text, TextSize = math.floor(11 * fontScale), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, content)
    addCorner(routeLabel, 7)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, routeLabel)
    actionButton("Track nearest hostile", function()
        local results = scanNPCs()
        if results[1] then
            setTracked(results[1].model, results[1].name, results[1].isBoss and "Boss" or "Mob")
            setStatus("Tracking nearest " .. results[1].name, COLORS.accent)
        else
            setStatus("No hostile NPC found", COLORS.gold)
        end
    end, COLORS.green)
    actionButton("Track nearest ore", function()
        local results = scanOres()
        if results[1] then
            setTracked(results[1].part, results[1].name, "Ore")
            setStatus("Tracking nearest " .. results[1].name, COLORS.accent)
        else
            setStatus("No ore found", COLORS.gold)
        end
    end)
    actionButton("Clear route target", function()
        setTracked(nil)
        if routeLabel then routeLabel.Text = "No target selected" end
        setStatus("Route target cleared")
    end, COLORS.red)

    local function updateRouteLabel()
        if not routeLabel or not routeLabel.Parent then return end
        local part = getTrackedPart()
        if not part then
            routeLabel.Text = trackedTitle .. "\nTarget not available / not loaded"
            return
        end
        local distance = getDistanceFromMe(part)
        local position = part.Position
        routeLabel.Text = string.format(
            "TARGET: %s\nTYPE: %s\nDISTANCE: %s\nDIRECTION: %s\nPOSITION: %.1f, %.1f, %.1f\n\nRoute indicator only — no automatic movement.",
            trackedTitle, trackedKind, fmtDistance(distance), directionTo(part), position.X, position.Y, position.Z
        )
    end
    updateRouteLabel()
    task.spawn(function()
        while alive and gui.Parent and routeLabel and routeLabel.Parent do
            updateRouteLabel()
            task.wait(0.5)
        end
    end)
end

local pages = {
    {name = "Home", build = pageHome},
    {name = "Quests", build = pageQuests},
    {name = "Targets", build = pageTargets},
    {name = "Mining", build = pageMining},
    {name = "Inventory", build = pageInventory},
    {name = "Route", build = pageRoute},
}

local function showPage(name)
    for _, page in ipairs(pages) do
        if page.name == name then
            currentPage = name
            page.build()
            return
        end
    end
end

for index, page in ipairs(pages) do
    local nav = create("TextButton", {
        Name = "Tab_" .. page.name,
        Size = UDim2.new(1, 0, 0, buttonHeight),
        BackgroundColor3 = index == 1 and COLORS.green or COLORS.panel2,
        BorderSizePixel = 0, Font = Enum.Font.GothamSemibold,
        Text = page.name, TextColor3 = COLORS.text,
        TextSize = math.floor((compact and 10 or 11) * fontScale),
        TextWrapped = true, LayoutOrder = index,
    }, sidebar)
    addCorner(nav, 7)
    nav.Activated:Connect(function()
        for _, child in ipairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then child.BackgroundColor3 = COLORS.panel2 end
        end
        nav.BackgroundColor3 = COLORS.green
        showPage(page.name)
    end)
end

local dragging, dragStart, startPosition, dragInput = false, nil, nil, nil
local minimized = false
local expandedSize = main.Size
local function setMinimized(value)
    minimized = value
    sidebar.Visible = not value
    content.Visible = not value
    status.Visible = not value
    main.Size = value and UDim2.fromOffset(math.min(width, 275), 44) or expandedSize
    minimize.Text = value and "+" or "−"
end
minimize.Activated:Connect(function() setMinimized(not minimized) end)

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPosition = true, input.Position, main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
table.insert(globalConnections, UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end))

local function cleanup()
    alive = false
    for _, connection in ipairs(globalConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(globalConnections)
    if gui and gui.Parent then gui:Destroy() end
end
close.Activated:Connect(cleanup)

refreshAll()
showPage("Home")
setStatus("Loaded • read-only Field Tracker v0.8", COLORS.accent)
print("[Beyond Nen Field Tracker] v0.8 loaded. Read-only: no remotes, no movement, no combat.")

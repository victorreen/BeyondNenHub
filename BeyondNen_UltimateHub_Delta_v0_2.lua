-- Beyond Nen Diagnostic v0.5 (mobile/touch friendly)
-- Read-only inspection helper for NPC names, quest UI text, and nearby prompts.
-- No remote calls, attacks, movement, teleports, HTTP requests, webhooks, or anti-cheat bypass.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local previous = PlayerGui:FindFirstChild("BeyondNenDiagnosticV05")
if previous then previous:Destroy() end

local function safeFullName(instance)
    local ok, value = pcall(function() return instance:GetFullName() end)
    return ok and value or instance.Name
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function rootOf(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
end

local function isVisible(instance)
    local current = instance
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("LayerCollector") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

local function addText(list, value, maxLength)
    value = tostring(value or "")
    value = value:gsub("\r", " "):gsub("\n", " / ")
    value = value:gsub("%s+", " ")
    if value ~= "" then
        if #value > (maxLength or 110) then value = value:sub(1, maxLength or 110) .. "…" end
        table.insert(list, value)
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BeyondNenDiagnosticV05"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10001
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(430, 900)
local touch = UserInputService.TouchEnabled
local width = math.floor(math.clamp(viewport.X * (touch and 0.94 or 0.62), 310, 620))
local height = math.floor(math.clamp(viewport.Y * (touch and 0.60 or 0.66), 390, 620))
if height > viewport.Y - 20 then height = viewport.Y - 20 end

local colors = {
    bg = Color3.fromRGB(17, 19, 25),
    panel = Color3.fromRGB(27, 31, 40),
    button = Color3.fromRGB(44, 53, 67),
    green = Color3.fromRGB(57, 145, 111),
    text = Color3.fromRGB(240, 242, 246),
    muted = Color3.fromRGB(166, 175, 188),
    red = Color3.fromRGB(158, 61, 67),
}

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(width, height),
    Position = UDim2.new(0.5, -width / 2, 0.5, -height / 2),
    BackgroundColor3 = colors.bg,
    BorderSizePixel = 0,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, main)
make("UIStroke", {Color = colors.green, Transparency = 0.2, Thickness = 1.2}, main)

local top = make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = colors.panel,
    BorderSizePixel = 0,
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 10)}, top)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -94, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "BEYOND NEN  /  DIAGNOSTIC v0.5",
    TextColor3 = colors.text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, top)

local minimized = false
local expandedSize = main.Size
local minimizeButton = make("TextButton", {
    Position = UDim2.new(1, -76, 0, 6), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = colors.button, BorderSizePixel = 0, Text = "−",
    TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 20,
}, top)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, minimizeButton)
local closeButton = make("TextButton", {
    Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = colors.red, BorderSizePixel = 0, Text = "×",
    TextColor3 = colors.text, Font = Enum.Font.GothamBold, TextSize = 19,
}, top)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, closeButton)

local toolbar = make("Frame", {
    Position = UDim2.fromOffset(8, 49), Size = UDim2.new(1, -16, 0, 42),
    BackgroundTransparency = 1,
}, main)
local toolbarLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 5),
}, toolbar)

local output = make("TextBox", {
    Name = "Report",
    Position = UDim2.fromOffset(8, 96),
    Size = UDim2.new(1, -16, 1, -132),
    BackgroundColor3 = colors.panel,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    MultiLine = true,
    TextEditable = false,
    TextWrapped = false,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextColor3 = colors.text,
    Text = "Use SCAN NPCs with enemies nearby.\nUse SCAN QUEST UI while the mission board is open.\nUse SCAN PROMPTS while standing near the board.\n\nThis tool only reads client-visible names and UI; it does not attack, move, or send game requests.",
}, main)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, output)
make("UIPadding", {
    PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, output)

local status = make("TextLabel", {
    Position = UDim2.new(0, 8, 1, -29), Size = UDim2.new(1, -16, 0, 22),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Ready • read-only",
    TextColor3 = colors.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, main)

local function setReport(title, lines)
    local report = {"BEYOND NEN DIAGNOSTIC v0.5", title, "PlaceId: " .. tostring(game.PlaceId), "Time: " .. os.date("!%Y-%m-%d %H:%M:%S UTC"), ""}
    for _, line in ipairs(lines) do table.insert(report, line) end
    if #lines == 0 then table.insert(report, "No matching objects found in the scanned area/UI.") end
    output.Text = table.concat(report, "\n")
    output.CursorPosition = 1
    status.Text = title .. " • " .. tostring(#lines) .. " lines"
    print(table.concat(report, "\n"))
end

local function scanNPCs()
    local myRoot = rootOf(LocalPlayer.Character)
    local found = {}
    local relatedWithoutHumanoid = {}
    local scanned = 0
    local terms = {"forest", "floresta", "brawler", "fighter", "lutador", "cave", "caverna", "bandit", "farmer", "phantom", "raider"}

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") then
            scanned += 1
            local hum = object:FindFirstChildOfClass("Humanoid")
            local root = rootOf(object)
            local modelName = lower(object.Name)
            local displayName = hum and lower(hum.DisplayName) or ""
            local attrName = lower(object:GetAttribute("DisplayName"))
            local isRelated = false
            local combined = modelName .. " " .. displayName .. " " .. attrName
            for _, term in ipairs(terms) do
                if string.find(combined, term, 1, true) then isRelated = true break end
            end

            if hum and root and hum.Health > 0 then
                local isPlayer = false
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character == object then isPlayer = true break end
                end
                if not isPlayer then
                    local distance = myRoot and (root.Position - myRoot.Position).Magnitude or math.huge
                    table.insert(found, {
                        model = object, distance = distance, display = hum.DisplayName,
                        health = hum.Health, maxHealth = hum.MaxHealth, position = root.Position,
                    })
                end
            elseif isRelated then
                table.insert(relatedWithoutHumanoid, safeFullName(object))
            end
        end
    end

    table.sort(found, function(a, b) return a.distance < b.distance end)
    local lines = {"NPC models scanned: " .. scanned, "Living non-player Humanoid models: " .. #found, "", "NEAREST NPC MODELS (up to 30):"}
    for index = 1, math.min(30, #found) do
        local entry = found[index]
        local model = entry.model
        local labels = {}
        addText(labels, model.Name, 70)
        addText(labels, entry.display, 70)
        addText(labels, model:GetAttribute("DisplayName"), 50)
        local billboardTexts = {}
        for _, descendant in ipairs(model:GetDescendants()) do
            if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text ~= "" then
                addText(billboardTexts, descendant.Text, 45)
                if #billboardTexts >= 2 then break end
            end
        end
        local nameLine = table.concat(labels, " | ")
        local textLine = #billboardTexts > 0 and (" | GuiText=" .. table.concat(billboardTexts, " / ")) or ""
        local distanceText = entry.distance == math.huge and "unknown" or (math.floor(entry.distance) .. " studs")
        table.insert(lines, string.format("%02d) %s | %s | HP %.0f/%.0f | Pos %s%s", index, nameLine, distanceText, entry.health, entry.maxHealth, tostring(entry.position), textLine))
        table.insert(lines, "    Path: " .. safeFullName(model))
    end

    if #relatedWithoutHumanoid > 0 then
        table.insert(lines, "")
        table.insert(lines, "RELATED MODELS WITHOUT HUMANOID (up to 15):")
        for index = 1, math.min(15, #relatedWithoutHumanoid) do
            table.insert(lines, "- " .. relatedWithoutHumanoid[index])
        end
    end
    setReport("NPC SCAN", lines)
end

local function scanQuestUI()
    local keywords = {"quest", "miss", "derrote", "defeat", "aceitar", "accept", "floresta", "forest", "caverna", "cave", "brawler", "lutador", "0/", "1/", "2/", "3/"}
    local lines = {"Scanning PlayerGui AND Workspace GUI objects (ScreenGui, SurfaceGui, BillboardGui).", "", "VISIBLE QUEST-RELATED TEXT:"}
    local textCount, buttonCount, guiRoots = 0, 0, 0
    local seen = {}

    for _, root in ipairs({PlayerGui, Workspace}) do
        for _, object in ipairs(root:GetDescendants()) do
            if object:IsA("ScreenGui") or object:IsA("SurfaceGui") or object:IsA("BillboardGui") then
                if isVisible(object) then
                    guiRoots += 1
                    if guiRoots <= 35 then table.insert(lines, "GUI ROOT: " .. object.ClassName .. " | " .. safeFullName(object)) end
                end
            end
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                if isVisible(object) and object.Text and object.Text ~= "" then
                    local text = object.Text
                    local normalized = lower(text)
                    local relevant = false
                    for _, keyword in ipairs(keywords) do
                        if string.find(normalized, keyword, 1, true) then relevant = true break end
                    end
                    if relevant and not seen[object] then
                        seen[object] = true
                        textCount += 1
                        if textCount <= 55 then
                            table.insert(lines, string.format("TEXT %02d [%s] = %s", textCount, object.ClassName, text:gsub("\n", " / "):sub(1, 150)))
                            table.insert(lines, "    Path: " .. safeFullName(object))
                        end
                    end
                end
            end
            if object:IsA("GuiButton") and isVisible(object) then
                local buttonTexts = {}
                if object:IsA("TextButton") then addText(buttonTexts, object.Text, 80) end
                for _, child in ipairs(object:GetDescendants()) do
                    if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text ~= "" then
                        addText(buttonTexts, child.Text, 80)
                    end
                end
                local combined = lower(object.Name .. " " .. table.concat(buttonTexts, " "))
                local relevant = false
                for _, keyword in ipairs(keywords) do
                    if string.find(combined, keyword, 1, true) then relevant = true break end
                end
                if relevant then
                    buttonCount += 1
                    if buttonCount <= 35 then
                        table.insert(lines, string.format("BUTTON %02d [%s] %s", buttonCount, object.ClassName, table.concat(buttonTexts, " / ")))
                        table.insert(lines, "    Path: " .. safeFullName(object))
                        table.insert(lines, "    Position=" .. tostring(object.AbsolutePosition) .. " Size=" .. tostring(object.AbsoluteSize))
                    end
                end
            end
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Summary: GUI roots=" .. guiRoots .. ", relevant text objects=" .. textCount .. ", relevant buttons=" .. buttonCount)
    setReport("QUEST UI SCAN", lines)
end

local function scanPrompts()
    local myRoot = rootOf(LocalPlayer.Character)
    local found = {}
    local namedObjects = {}
    local terms = {"quest", "mission", "miss", "quadro", "board", "hunter", "Sarah", "Rohan"}
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local parent = object.Parent
            local part = parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart", true))
            local distance = (myRoot and part) and (part.Position - myRoot.Position).Magnitude or math.huge
            table.insert(found, {
                prompt = object, distance = distance,
                text = tostring(object.ActionText) .. " | " .. tostring(object.ObjectText),
                path = safeFullName(object),
            })
        end
        local name = lower(object.Name)
        for _, term in ipairs(terms) do
            if string.find(name, lower(term), 1, true) then
                table.insert(namedObjects, safeFullName(object))
                break
            end
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    local lines = {"PROXIMITY PROMPTS (nearest first):"}
    for index = 1, math.min(35, #found) do
        local item = found[index]
        local distance = item.distance == math.huge and "unknown" or (math.floor(item.distance) .. " studs")
        table.insert(lines, string.format("%02d) %s | %s | Enabled=%s | MaxDistance=%.1f | %s", index, item.text, distance, tostring(item.prompt.Enabled), item.prompt.MaxActivationDistance, item.path))
    end
    table.insert(lines, "")
    table.insert(lines, "OBJECTS WITH QUEST/BOARD/NPC-LIKE NAMES (up to 35):")
    for index = 1, math.min(35, #namedObjects) do table.insert(lines, "- " .. namedObjects[index]) end
    table.insert(lines, "Prompt count=" .. #found .. ", named object count=" .. #namedObjects)
    setReport("PROMPT / BOARD SCAN", lines)
end

local function makeButton(title, callback, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.25, -4, 1, 0)
    button.BackgroundColor3 = color or colors.button
    button.BorderSizePixel = 0
    button.Text = title
    button.TextColor3 = colors.text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.TextWrapped = true
    button.Parent = toolbar
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
    button.Activated:Connect(function()
        status.Text = "Scanning..."
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then status.Text = "Scan error: " .. tostring(err); warn(err) end
        end)
    end)
    return button
end

makeButton("SCAN NPCs", scanNPCs, colors.green)
makeButton("SCAN QUEST UI", scanQuestUI)
makeButton("SCAN PROMPTS", scanPrompts)
makeButton("COPY", function()
    local ok = pcall(function() setclipboard(output.Text) end)
    status.Text = ok and "Report copied to clipboard" or "Clipboard unavailable: select/copy the report text"
end, colors.blue)

local function setMinimized(value)
    minimized = value
    toolbar.Visible = not value
    output.Visible = not value
    status.Visible = not value
    main.Size = value and UDim2.fromOffset(math.min(width, 270), 42) or expandedSize
    minimizeButton.Text = value and "+" or "−"
end
minimizeButton.Activated:Connect(function() setMinimized(not minimized) end)
closeButton.Activated:Connect(function() gui:Destroy() end)

-- Touch/mouse drag support for the floating diagnostic window.
local dragging, dragStart, startPosition, dragInput = false, nil, nil, nil
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
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

print("[Beyond Nen Diagnostic v0.5] Loaded. Run SCAN NPCs near enemies, SCAN QUEST UI with the board open, and SCAN PROMPTS near the board.")

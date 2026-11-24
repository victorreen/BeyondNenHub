-- Beyond Nen Ultimate Hub v0.4 - Mobile-first build for Delta Android
-- Readable Luau. No external downloads, webhooks, credential access, or hidden remote calls.
-- Auto Farm: finds matching living NPC models, moves with Humanoid:MoveTo, and activates an equipped weapon Tool.
-- Auto Quest: scans visible quest UI buttons and tries to select/accept the chosen board mission.
-- Game-specific APIs were not documented publicly; UI/target recognition may need adjustments after in-game testing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
if not LP then return end

local PlayerGui = LP:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("BeyondNenUltimateHub")
if oldGui then oldGui:Destroy() end

local touchMode = UIS.TouchEnabled
local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
local mobilePortrait = touchMode and viewport.X < viewport.Y
local windowW = math.floor(math.clamp(viewport.X * (touchMode and 0.94 or 0.72), 330, 610))
local windowH = math.floor(math.clamp(viewport.Y * (mobilePortrait and 0.58 or 0.72), 390, 570))
if windowH > viewport.Y - 24 then windowH = viewport.Y - 24 end
local compact = windowW < 470
local sidebarW = compact and 94 or 132
local fontScale = math.clamp(viewport.X / 440, 0.9, 1.15)
local buttonH = touchMode and 40 or 34

local C = {
    bg = Color3.fromRGB(17, 19, 25),
    panel = Color3.fromRGB(25, 29, 37),
    panel2 = Color3.fromRGB(34, 39, 49),
    accent = Color3.fromRGB(116, 221, 169),
    green = Color3.fromRGB(64, 166, 126),
    text = Color3.fromRGB(238, 241, 245),
    muted = Color3.fromRGB(157, 165, 178),
    red = Color3.fromRGB(170, 65, 72),
    blue = Color3.fromRGB(89, 151, 205),
}

local function new(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        obj[key] = value
    end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local gui = new("ScreenGui", {
    Name = "BeyondNenUltimateHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 10000,
    IgnoreGuiInset = false,
}, PlayerGui)

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(windowW, windowH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.52),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
}, gui)
corner(main, 12)
new("UIStroke", {Color = C.green, Transparency = 0.22, Thickness = 1.3}, main)

local top = new("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
corner(top, 12)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -100, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "BEYOND NEN  /  ULTIMATE HUB  v0.4",
    TextColor3 = C.text,
    TextSize = math.floor(12 * fontScale),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, top)

local minimize = new("TextButton", {
    Name = "MinimizeButton",
    Position = UDim2.new(1, -78, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.panel2,
    Text = "−",
    TextColor3 = C.text,
    Font = Enum.Font.GothamBold,
    TextSize = 21,
    BorderSizePixel = 0,
}, top)
corner(minimize, 7)
local close = new("TextButton", {
    Name = "CloseButton",
    Position = UDim2.new(1, -41, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = C.red,
    Text = "×",
    TextColor3 = C.text,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    BorderSizePixel = 0,
}, top)
corner(close, 7)

local sidebar = new("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(9, 52),
    Size = UDim2.new(0, sidebarW, 1, -61),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)
corner(sidebar, 8)
new("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
}, sidebar)
new("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

local content = new("ScrollingFrame", {
    Name = "Content",
    Position = UDim2.fromOffset(sidebarW + 17, 52),
    Size = UDim2.new(1, -(sidebarW + 26), 1, -90),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    ScrollBarThickness = touchMode and 3 or 4,
    ScrollBarImageColor3 = C.green,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, main)
corner(content, 8)
new("UIPadding", {
    PaddingTop = UDim.new(0, 9),
    PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
}, content)
local contentLayout = new("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, content)

local status = new("TextLabel", {
    Name = "Status",
    Position = UDim2.new(0, sidebarW + 18, 1, -32),
    Size = UDim2.new(1, -(sidebarW + 28), 0, 23),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Ready",
    TextColor3 = C.muted,
    TextSize = math.floor(10 * fontScale),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, main)

local function say(message, color)
    if status and status.Parent then
        status.Text = tostring(message)
        status.TextColor3 = color or C.muted
    end
end

-- Drag works with both mouse and touch. The minimize control remains available.
local drag, dragStart, startPosition, dragInput
local function updateDrag(input)
    if drag and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag = true
        dragStart = input.Position
        startPosition = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then drag = false end
        end)
    end
end)
top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(updateDrag)

local minimized = false
local expandedSize = main.Size
local function setMinimized(value)
    minimized = value
    sidebar.Visible = not value
    content.Visible = not value
    status.Visible = not value
    main.Size = value and UDim2.fromOffset(math.min(windowW, 270), 44) or expandedSize
    minimize.Text = value and "+" or "−"
    minimize.BackgroundColor3 = value and C.green or C.panel2
end
minimize.Activated:Connect(function() setMinimized(not minimized) end)

local function clearPage()
    for _, child in ipairs(content:GetChildren()) do
        if child ~= contentLayout and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function section(title, description)
    local height = description and 61 or 34
    local frame = new("Frame", {
        Size = UDim2.new(1, -2, 0, height),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
    }, content)
    corner(frame, 7)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 7),
    }, frame)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 21),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = C.accent,
        TextSize = math.floor(12 * fontScale),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)
    if description then
        new("TextLabel", {
            Position = UDim2.fromOffset(0, 22),
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = description,
            TextColor3 = C.muted,
            TextSize = math.floor(10 * fontScale),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, frame)
    end
    return frame
end

local function button(title, callback, color)
    local b = new("TextButton", {
        Size = UDim2.new(1, -2, 0, buttonH),
        BackgroundColor3 = color or C.panel2,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        Text = title,
        TextColor3 = C.text,
        TextSize = math.floor(11 * fontScale),
        TextWrapped = true,
        AutoButtonColor = true,
    }, content)
    corner(b, 7)
    b.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[Beyond Nen Hub] " .. tostring(err)); say("Action error", C.red) end
    end)
    return b
end

local function toggle(title, initial, callback)
    local value = initial == true
    local b = new("TextButton", {
        Size = UDim2.new(1, -2, 0, buttonH),
        BackgroundColor3 = C.panel2,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        TextColor3 = C.text,
        TextSize = math.floor(11 * fontScale),
        TextWrapped = true,
        AutoButtonColor = true,
    }, content)
    corner(b, 7)
    local function refresh()
        b.Text = title .. (value and "   [ON]" or "   [OFF]")
        b.BackgroundColor3 = value and C.green or C.panel2
    end
    b.Activated:Connect(function()
        value = not value
        refresh()
        local ok, err = pcall(callback, value)
        if not ok then warn("[Beyond Nen Hub] " .. tostring(err)); say("Toggle error", C.red) end
    end)
    refresh()
    return function() return value end
end

local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function humanoidOf(model)
    return model and model:FindFirstChildOfClass("Humanoid")
end
local function isPlayerCharacter(model)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == model then return true end
    end
    return false
end
local function isAliveNPC(model)
    if not model or not model:IsA("Model") or isPlayerCharacter(model) then return false end
    local hum = humanoidOf(model)
    return hum ~= nil and hum.Health > 0 and rootOf(model) ~= nil
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local targetMode = "Forest"
local targetTerms = {
    Forest = {"forest", "floresta"},
    Cave = {"cave", "caverna"},
}

local function matchesTarget(model, mode)
    local name = lower(model.Name)
    local display = lower(model:GetAttribute("DisplayName"))
    local text = name .. " " .. display
    for _, term in ipairs(targetTerms[mode] or {}) do
        if string.find(text, term, 1, true) then return true end
    end
    return false
end

-- Cache world NPC models so repeated farm/ESP polling does not rescan every instance on each frame.
local npcCache = {}
local lastNpcScan = 0
local function refreshNpcCache(force)
    local now = os.clock()
    local scanInterval = touchMode and 2.4 or 1.4
    if not force and now - lastNpcScan < scanInterval then return end
    lastNpcScan = now
    local fresh = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and isAliveNPC(obj) then
            table.insert(fresh, obj)
        end
    end
    npcCache = fresh
end

local function getNPCs(mode)
    refreshNpcCache(false)
    local result = {}
    for _, model in ipairs(npcCache) do
        if model.Parent and isAliveNPC(model) and (not mode or matchesTarget(model, mode)) then
            table.insert(result, model)
        end
    end
    return result
end

local function nearestNPC(mode)
    local myRoot = rootOf(LP.Character)
    if not myRoot then return nil end
    local best, bestDistance = nil, math.huge
    for _, model in ipairs(getNPCs(mode)) do
        local part = rootOf(model)
        if part then
            local distance = (part.Position - myRoot.Position).Magnitude
            if distance < bestDistance then best, bestDistance = model, distance end
        end
    end
    return best, bestDistance
end

-- Reads the visible active quest tracker, including the objective format shown in your screenshots (0/4 ...).
local function getActiveQuestInfo()
    local bestInfo = nil
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local text = obj.Text or ""
            local current, total = string.match(text, "(%d+)%s*/%s*(%d+)")
            if current and total and (string.find(lower(text), "derrote", 1, true) or string.find(lower(text), "defeat", 1, true)) then
                bestInfo = {
                    text = text,
                    current = tonumber(current),
                    total = tonumber(total),
                }
                break
            end
        end
    end
    return bestInfo
end

local function questModeFromInfo(info)
    if not info then return targetMode end
    local text = lower(info.text)
    if string.find(text, "caverna", 1, true) or string.find(text, "cave", 1, true) then return "Cave" end
    if string.find(text, "floresta", 1, true) or string.find(text, "forest", 1, true) then return "Forest" end
    return targetMode
end

local function visibleInTree(obj)
    local current = obj
    while current and current ~= PlayerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        current = current.Parent
    end
    return true
end

local function guiButtonText(buttonObject)
    local parts = {buttonObject.Name or ""}
    if buttonObject:IsA("TextButton") then table.insert(parts, buttonObject.Text or "") end
    for _, child in ipairs(buttonObject:GetDescendants()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            table.insert(parts, child.Text or "")
        end
    end
    return lower(table.concat(parts, " "))
end

-- Executor signal helpers are optional. If Delta blocks them, the script asks the player to open/click the board manually.
local function activateGuiButton(buttonObject)
    if not buttonObject or not buttonObject:IsA("GuiButton") or not visibleInTree(buttonObject) then return false end

    if typeof(firesignal) == "function" then
        local ok = pcall(function() firesignal(buttonObject.Activated) end)
        if ok then return true end
        if buttonObject:IsA("TextButton") then
            ok = pcall(function() firesignal(buttonObject.MouseButton1Click) end)
            if ok then return true end
        end
    end

    if typeof(getconnections) == "function" then
        local signals = {buttonObject.Activated}
        if buttonObject:IsA("TextButton") then table.insert(signals, buttonObject.MouseButton1Click) end
        for _, signal in ipairs(signals) do
            local ok, connections = pcall(getconnections, signal)
            if ok and type(connections) == "table" then
                for _, connection in ipairs(connections) do
                    if connection.Enabled ~= false then
                        if type(connection.Fire) == "function" then
                            if pcall(function() connection:Fire() end) then return true end
                        end
                        if type(connection.Function) == "function" then
                            if pcall(connection.Function) then return true end
                        end
                    end
                end
            end
        end
    end

    -- Last-resort input simulation; may be unavailable on some Delta Android builds.
    local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok and vim then
        local center = buttonObject.AbsolutePosition + buttonObject.AbsoluteSize / 2
        local touchMethod = pcall(function() return vim.SendTouchEvent end)
        if touchMethod then
            local touchOk = pcall(function()
                vim:SendTouchEvent(0, center, true, game)
                task.wait(0.06)
                vim:SendTouchEvent(0, center, false, game)
            end)
            if touchOk then return true end
        end
        local mouseMethod = pcall(function() return vim.SendMouseButtonEvent end)
        if mouseMethod then
            local mouseOk = pcall(function()
                vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                task.wait(0.06)
                vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
            end)
            if mouseOk then return true end
        end
    end
    return false
end

local function findVisibleButton(needles)
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("GuiButton") and visibleInTree(obj) then
            local text = guiButtonText(obj)
            for _, needle in ipairs(needles) do
                if string.find(text, needle, 1, true) then return obj end
            end
        end
    end
    return nil
end

local function tryAcceptQuest()
    local info = getActiveQuestInfo()
    if info and info.current < info.total then
        say("Active quest: " .. info.text, C.accent)
        return true
    end

    local now = os.clock()
    if now - (tryAcceptQuest.lastAction or 0) < 1.3 then return false end

    -- If the board is open, choose the card first, then press Accept on a later poll.
    -- The short pending window prevents the same card from being clicked repeatedly.
    local pendingSelection = tryAcceptQuest.pendingSelectionAt or 0
    local accept = findVisibleButton({"aceitar", "accept"})
    if accept and (pendingSelection > 0 or not findVisibleButton({"lutadores da floresta", "forest fighters", "forest fighter", "floresta", "lutadores da caverna", "cave fighters", "cave fighter", "caverna"})) then
        if activateGuiButton(accept) then
            tryAcceptQuest.lastAction = now
            tryAcceptQuest.pendingSelectionAt = 0
            say("Quest accept button activated", C.accent)
            return true
        end
    end

    local cardNeedles
    if targetMode == "Forest" then
        cardNeedles = {"lutadores da floresta", "forest fighters", "forest fighter", "floresta"}
    else
        cardNeedles = {"lutadores da caverna", "cave fighters", "cave fighter", "caverna"}
    end

    local card = findVisibleButton(cardNeedles)
    if card and (pendingSelection == 0 or now - pendingSelection > 7) then
        if activateGuiButton(card) then
            tryAcceptQuest.lastAction = now
            tryAcceptQuest.pendingSelectionAt = now
            say("Quest card selected; looking for Accept...", C.accent)
            return true
        end
    end

    if accept and pendingSelection == 0 then
        if activateGuiButton(accept) then
            tryAcceptQuest.lastAction = now
            say("Quest accept button activated", C.accent)
            return true
        end
    end

    -- Use a nearby, clearly labelled quest-board prompt only when the executor exposes this helper.
    if typeof(fireproximityprompt) == "function" and now - (tryAcceptQuest.lastPromptScan or 0) >= 2.5 then
        tryAcceptQuest.lastPromptScan = now
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local promptText = lower((obj.ActionText or "") .. " " .. (obj.ObjectText or "") .. " " .. (obj.Parent and obj.Parent.Name or ""))
                if string.find(promptText, "quest", 1, true) or string.find(promptText, "miss", 1, true) or string.find(promptText, "quadro", 1, true) then
                    local myRoot = rootOf(LP.Character)
                    local promptPart = obj.Parent and (obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart", true))
                    if myRoot and promptPart and (promptPart.Position - myRoot.Position).Magnitude <= (obj.MaxActivationDistance + 5) then
                        local ok = pcall(function() fireproximityprompt(obj) end)
                        if ok then
                            tryAcceptQuest.lastAction = now
                            say("Quest board prompt activated", C.accent)
                            return true
                        end
                    end
                end
            end
        end
    end

    say("Open the mission board; Auto Quest will select the visible " .. targetMode .. " card", C.muted)
    return false
end

local function tryClaimQuest()
    local claim = findVisibleButton({"entregar", "claim", "concluir", "complete", "finalizar", "finish"})
    if claim then
        return activateGuiButton(claim)
    end
    return false
end

local function equippedWeapon()
    local character = LP.Character
    if not character then return nil end
    local function isWeapon(tool)
        local name = lower(tool.Name)
        return string.find(name, "sword", 1, true)
            or string.find(name, "espada", 1, true)
            or string.find(name, "blade", 1, true)
            or string.find(name, "katana", 1, true)
            or string.find(name, "weapon", 1, true)
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and isWeapon(child) then return child end
    end
    local backpack = LP:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and isWeapon(child) then
                local hum = humanoidOf(character)
                if hum then pcall(function() hum:EquipTool(child) end) end
                return child
            end
        end
    end
    -- If the game equips a custom weapon tool with a different name, use the currently equipped Tool as a fallback.
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
end

local autoFarmOn = false
local autoQuestOn = false
local pEspOn = false
local nEspOn = false
local speedOn = false
local jumpOn = false
local noclipOn = false
local oldSpeed, oldJump = nil, nil
local oldCollision = {}
local savedWaypoint = nil
local lastMoveAt, lastAttackAt = 0, 0
local lastStatusAt = 0
local automationBusy = false

local function farmStep(modeOverride)
    local mode = modeOverride or targetMode
    local character = LP.Character
    local myRoot = rootOf(character)
    local myHumanoid = humanoidOf(character)
    if not myRoot or not myHumanoid or myHumanoid.Health <= 0 then
        say("Waiting for your character...", C.muted)
        return
    end

    local target, distance = nearestNPC(mode)
    if not target then
        if os.clock() - lastStatusAt > 2 then
            say("No " .. mode .. " target found. Check NPC name/area.", C.muted)
            lastStatusAt = os.clock()
        end
        return
    end

    local targetRoot = rootOf(target)
    if not targetRoot then return end

    -- Avoid dragging the character into a target across the entire map.
    if distance > 320 then
        say("Nearest " .. mode .. " target is far away (" .. math.floor(distance) .. "m)", C.muted)
        return
    end

    if distance > 9 and os.clock() - lastMoveAt >= 0.65 then
        lastMoveAt = os.clock()
        local direction = (myRoot.Position - targetRoot.Position)
        if direction.Magnitude < 0.1 then direction = Vector3.new(0, 0, 1) end
        local destination = targetRoot.Position + direction.Unit * 5
        pcall(function() myHumanoid:MoveTo(destination) end)
    elseif distance <= 12 and os.clock() - lastAttackAt >= 0.48 then
        lastAttackAt = os.clock()
        local weapon = equippedWeapon()
        if weapon then
            pcall(function() weapon:Activate() end)
            say("Attacking " .. target.Name, C.accent)
        else
            say("Equip your sword/weapon first", C.muted)
        end
    end
end

-- ESP helpers kept lightweight for phones.
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
    for model, data in pairs(esp) do
        if not kind or data.kind == kind then removeEsp(model) end
    end
end
local function addEsp(model, kind, color)
    if esp[model] or not model.Parent then return end
    local adornee = model:FindFirstChild("Head") or rootOf(model)
    if not adornee then return end
    local highlight = new("Highlight", {
        Adornee = model,
        FillColor = color,
        OutlineColor = color,
        FillTransparency = 0.84,
        OutlineTransparency = 0.12,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    }, Workspace)
    local billboard = new("BillboardGui", {
        Adornee = adornee,
        Size = UDim2.fromOffset(170, 22),
        StudsOffset = Vector3.new(0, 2.8, 0),
        AlwaysOnTop = true,
    }, PlayerGui)
    new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextColor3 = color,
        TextStrokeTransparency = 0.3,
        TextSize = 10,
        Text = kind .. "  " .. model.Name,
    }, billboard)
    esp[model] = {highlight = highlight, billboard = billboard, kind = kind}
end

local function teleportNear(part, name)
    local myRoot = rootOf(LP.Character)
    if not myRoot or not part then say("Character/target not found", C.red); return end
    myRoot.CFrame = part.CFrame * CFrame.new(0, 0, 5)
    say("Moved near " .. tostring(name or "target") .. " (server may correct it)", C.accent)
end

RunService.Stepped:Connect(function()
    if noclipOn and LP.Character then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if oldCollision[part] == nil then oldCollision[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
end)

local function restoreNoclip()
    for part, value in pairs(oldCollision) do
        if part and part.Parent then part.CanCollide = value end
    end
    table.clear(oldCollision)
end

-- One low-frequency worker for target scans and quest UI polling; interval is mobile-friendly.
task.spawn(function()
    while gui.Parent do
        local ok, err = pcall(function()
            if autoQuestOn then
                local info = getActiveQuestInfo()
                if info then
                    if info.current >= info.total then
                        if not tryClaimQuest() then
                            say("Quest objective complete; return to board/NPC to claim", C.accent)
                        end
                    else
                        farmStep(questModeFromInfo(info))
                    end
                else
                    tryAcceptQuest()
                end
            elseif autoFarmOn then
                farmStep(targetMode)
            end

            if pEspOn then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LP and player.Character then
                        addEsp(player.Character, "PLAYER", Color3.fromRGB(100, 190, 255))
                    end
                end
            else
                clearEsp("PLAYER")
            end

            if nEspOn then
                local count = 0
                for _, model in ipairs(getNPCs(nil)) do
                    if count >= (touchMode and 28 or 55) then break end
                    local name = lower(model.Name)
                    local kind = (string.find(name, "boss", 1, true) or string.find(name, "chief", 1, true) or string.find(name, "leader", 1, true)) and "BOSS" or "NPC"
                    local color = kind == "BOSS" and Color3.fromRGB(255, 105, 95) or Color3.fromRGB(255, 205, 100)
                    addEsp(model, kind, color)
                    count += 1
                end
            else
                clearEsp("NPC")
                clearEsp("BOSS")
            end

            local myRoot = rootOf(LP.Character)
            for model, data in pairs(esp) do
                if not model.Parent then
                    removeEsp(model)
                elseif myRoot and data.billboard then
                    local part = rootOf(model)
                    local label = data.billboard:FindFirstChildOfClass("TextLabel")
                    if part and label then
                        label.Text = data.kind .. "  " .. model.Name .. "  •  " .. math.floor((part.Position - myRoot.Position).Magnitude) .. "m"
                    end
                end
            end
        end)
        if not ok then warn("[Beyond Nen Hub worker] " .. tostring(err)) end
        task.wait(touchMode and 0.85 or 0.55)
    end
end)

local function page(name)
    clearPage()
    if name == "Home" then
        section("Welcome, " .. LP.Name, "Mobile-first hub for Beyond Nen. Minimize with −; use + to restore.")
        section("Automation", "Auto Farm follows Forest/Cave fighter NPCs and activates an equipped weapon. Auto Quest reads the visible quest tracker and board buttons.")
        button("Scan active quest", function()
            local info = getActiveQuestInfo()
            if info then say(info.text, C.accent) else say("No active kill quest text detected", C.muted) end
        end)
        button("Find nearest " .. targetMode .. " fighter", function()
            local model, distance = nearestNPC(targetMode)
            say(model and (model.Name .. " • " .. math.floor(distance) .. "m") or "No matching NPC found", model and C.accent or C.muted)
        end)
        section("Note", "If the game uses a custom combat UI instead of a Tool, Auto Farm may need one more adjustment after testing on your phone.")
    elseif name == "Farm" then
        section("Auto Farm", "Moves toward matching enemies using Humanoid:MoveTo; attacks with an equipped sword/weapon Tool.")
        button("Target filter: " .. targetMode .. "  (tap to switch)", function()
            targetMode = targetMode == "Forest" and "Cave" or "Forest"
            page("Farm")
            say("Target filter: " .. targetMode, C.accent)
        end, C.blue)
        toggle("Auto Farm", autoFarmOn, function(value)
            autoFarmOn = value
            say(value and ("Farming " .. targetMode .. " fighters") or "Auto Farm stopped", value and C.accent or C.muted)
        end)
        button("Scan matching enemies", function()
            local found = getNPCs(targetMode)
            local names = {}
            for i = 1, math.min(5, #found) do table.insert(names, found[i].Name) end
            say(#found > 0 and ("Found " .. #found .. ": " .. table.concat(names, ", ")) or "No matching enemies in Workspace", #found > 0 and C.accent or C.muted)
        end)
        button("Find nearest enemy", function()
            local model, distance = nearestNPC(targetMode)
            if model then say(model.Name .. " • " .. math.floor(distance) .. "m", C.accent) else say("No target for " .. targetMode, C.muted) end
        end)
        button("Stop farm and quest", function()
            autoFarmOn = false
            autoQuestOn = false
            say("All automation stopped", C.red)
            page("Farm")
        end, C.red)
    elseif name == "Quests" then
        section("Auto Quest", "Select Forest or Cave below. Open the mission board once; the hub will try to select the matching card and press Aceitar.")
        button("Quest board target: " .. targetMode .. "  (tap to switch)", function()
            targetMode = targetMode == "Forest" and "Cave" or "Forest"
            page("Quests")
            say("Quest target: " .. targetMode, C.accent)
        end, C.blue)
        toggle("Auto Quest (accept + farm objective)", autoQuestOn, function(value)
            autoQuestOn = value
            say(value and "Auto Quest enabled; open the mission board if no quest is active" or "Auto Quest stopped", value and C.accent or C.muted)
        end)
        button("Read active mission", function()
            local info = getActiveQuestInfo()
            if info then say(info.text .. " (" .. info.current .. "/" .. info.total .. ")", C.accent) else say("Active tracker not found. Open the mission board/mission tracker.", C.muted) end
        end)
        button("Try select + accept quest now", function()
            if not tryAcceptQuest() then say("No matching visible card/button. Open the board and try again.", C.muted) end
        end)
        section("Important", "Auto Quest can only press visible UI buttons it recognizes. It cannot force a server quest or claim reward using undocumented RemoteEvents.")
    elseif name == "ESP" then
        section("Visuals", "Reduced scan rate and overlay cap for Android performance.")
        toggle("Player ESP", pEspOn, function(value)
            pEspOn = value
            if not value then clearEsp("PLAYER") end
            say("Player ESP " .. (value and "ON" or "OFF"), C.accent)
        end)
        toggle("NPC / Boss ESP", nEspOn, function(value)
            nEspOn = value
            if not value then clearEsp("NPC"); clearEsp("BOSS") end
            say("NPC/Boss ESP " .. (value and "ON" or "OFF"), C.accent)
        end)
        button("Clear ESP", function()
            pEspOn = false
            nEspOn = false
            clearEsp()
            say("ESP cleared", C.accent)
        end, C.red)
    elseif name == "Teleport" then
        section("Teleport", "Local CFrame movement is not guaranteed server-side and may be rolled back.")
        button("Teleport near nearest matching mob", function()
            local model = nearestNPC(targetMode)
            teleportNear(model and rootOf(model), model and model.Name or "mob")
        end)
        button("Save current position", function()
            local root = rootOf(LP.Character)
            if root then savedWaypoint = root.CFrame; say("Waypoint saved", C.accent) end
        end)
        button("Return to saved position", function()
            local root = rootOf(LP.Character)
            if root and savedWaypoint then root.CFrame = savedWaypoint; say("Returned to waypoint", C.accent) else say("No saved waypoint", C.muted) end
        end)
    elseif name == "Movement" then
        section("Movement helpers", "Values may reset or be rejected by the server. Restore them before closing.")
        toggle("WalkSpeed boost (24)", speedOn, function(value)
            speedOn = value
            local hum = humanoidOf(LP.Character)
            if hum then
                if value then oldSpeed = oldSpeed or hum.WalkSpeed; hum.WalkSpeed = 24
                elseif oldSpeed then hum.WalkSpeed = oldSpeed; oldSpeed = nil end
            end
            say(value and "WalkSpeed boosted" or "WalkSpeed restored", C.accent)
        end)
        toggle("JumpPower boost (60)", jumpOn, function(value)
            jumpOn = value
            local hum = humanoidOf(LP.Character)
            if hum then
                if value then oldJump = oldJump or hum.JumpPower; hum.UseJumpPower = true; hum.JumpPower = 60
                elseif oldJump then hum.JumpPower = oldJump; oldJump = nil end
            end
            say(value and "JumpPower boosted" or "JumpPower restored", C.accent)
        end)
        toggle("Noclip", noclipOn, function(value)
            noclipOn = value
            if not value then restoreNoclip() end
            say("Noclip " .. (value and "ON" or "OFF"), C.accent)
        end)
        button("Restore movement", function()
            speedOn, jumpOn, noclipOn = false, false, false
            local hum = humanoidOf(LP.Character)
            if hum then
                if oldSpeed then hum.WalkSpeed = oldSpeed end
                if oldJump then hum.JumpPower = oldJump end
            end
            oldSpeed, oldJump = nil, nil
            restoreNoclip()
            say("Movement restored", C.accent)
            page("Movement")
        end, C.red)
    end
end

local tabs = {"Home", "Farm", "Quests", "ESP", "Teleport", "Movement"}
for index, tabName in ipairs(tabs) do
    local tabButton = new("TextButton", {
        Name = "Tab_" .. tabName,
        Size = UDim2.new(1, 0, 0, buttonH),
        BackgroundColor3 = index == 1 and C.green or C.panel2,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        Text = tabName,
        TextColor3 = C.text,
        TextSize = math.floor(10 * fontScale),
        TextWrapped = true,
        LayoutOrder = index,
        AutoButtonColor = true,
    }, sidebar)
    corner(tabButton, 7)
    tabButton.Activated:Connect(function()
        for _, child in ipairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then child.BackgroundColor3 = C.panel2 end
        end
        tabButton.BackgroundColor3 = C.green
        page(tabName)
    end)
end

local closed = false
local function cleanup()
    if closed then return end
    closed = true
    autoFarmOn = false
    autoQuestOn = false
    pEspOn = false
    nEspOn = false
    noclipOn = false
    clearEsp()
    restoreNoclip()
    local hum = humanoidOf(LP.Character)
    if hum then
        if oldSpeed then hum.WalkSpeed = oldSpeed end
        if oldJump then hum.JumpPower = oldJump end
    end
    gui:Destroy()
end
close.Activated:Connect(cleanup)

page("Home")
say("Loaded v0.4 • mobile layout • Auto Farm/Quest ready for testing", C.accent)
print("[Beyond Nen Ultimate Hub] v0.4 loaded; no external code downloaded")

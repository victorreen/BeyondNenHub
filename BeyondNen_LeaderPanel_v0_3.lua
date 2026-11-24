--[[
BEYOND NEN - LEADER PANEL v0.3
Painel de testes para líderes/desenvolvedores do jogo.

O que faz:
  - SCAN completo (igual ao v0.2): ferramentas, stats, GUI, NPCs,
    prompts, click detectors, remotes, recursos, quests, baús, forjas.
  - Abas clicáveis com listas; clicar em um item TELEPORTA o personagem
    até ele (só local, no seu cliente — não altera nada no servidor).
  - MONITOR DE REMOTES: registra eventos disparados pelo cliente/servidor
    enquanto estiver ligado (somente leitura, não dispara nada).
  - Copia o relatório JSON completo para a área de transferência.

Como usar: carregue completamente no Beyond Nen e execute pelo executor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

if not player then
    warn("[BeyondNen LeaderPanel] Entre no jogo antes de executar.")
    return
end

local GUI_NAME = "BeyondNenLeaderPanel"
local function safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

local parentGui = safe(function()
    if type(gethui) == "function" then return gethui() end
    return CoreGui
end, nil)
if not parentGui then
    parentGui = safe(function() return player:WaitForChild("PlayerGui") end, nil)
end
if not parentGui then
    warn("[BeyondNen LeaderPanel] Não consegui criar a interface.")
    return
end

safe(function()
    local old = parentGui:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------
local function getPosition(obj)
    return safe(function()
        local p
        if obj:IsA("BasePart") then p = obj.Position
        elseif obj:IsA("Model") then p = obj:GetPivot().Position
        elseif obj.Parent and obj.Parent:IsA("BasePart") then p = obj.Parent.Position
        elseif obj.Parent and obj.Parent:IsA("Model") then p = obj.Parent:GetPivot().Position
        end
        if p then
            return {x=math.floor(p.X*10)/10, y=math.floor(p.Y*10)/10, z=math.floor(p.Z*10)/10}
        end
        return nil
    end, nil)
end

local function teleportTo(pos)
    if not pos then return false end
    return safe(function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(pos.x, pos.y + 4, pos.z)
            return true
        end
        return false
    end, false)
end

local function getPath(obj)
    return safe(function() return obj:GetFullName() end, obj.Name)
end

local function cleanValue(v, depth)
    depth = depth or 0
    if depth > 3 then return tostring(v) end
    local kind = typeof(v)
    if kind == "nil" or kind == "string" or kind == "boolean" or kind == "number" then
        return v
    elseif kind == "Instance" then
        return getPath(v)
    elseif kind == "table" then
        local t = {}
        for k, value in pairs(v) do t[tostring(k)] = cleanValue(value, depth + 1) end
        return t
    end
    return tostring(v)
end

local function getAttributes(obj)
    return cleanValue(safe(function() return obj:GetAttributes() end, {}))
end

local function getValue(obj)
    return safe(function()
        if obj:IsA("ValueBase") then return cleanValue(obj.Value) end
        return nil
    end, nil)
end

------------------------------------------------------------------
-- Interface
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0.88, 0, 0.78, 0)
frame.Position = UDim2.new(0.06, 0, 0.11, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 38)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "BEYOND NEN  |  LEADER PANEL v0.3"
title.TextColor3 = Color3.fromRGB(235, 238, 245)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 22)
status.Position = UDim2.new(0, 10, 0, 40)
status.BackgroundTransparency = 1
status.Text = "Clique em ESCANEAR para começar."
status.TextColor3 = Color3.fromRGB(130, 205, 255)
status.TextSize = 13
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

-- Barra de abas
local TABS = {"NPCs", "Recursos", "Quests", "Craft", "Baús", "Prompts", "Stats", "Remotes", "Monitor"}
local tabsData = {}
local activeTab = nil

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 28)
tabBar.Position = UDim2.new(0, 10, 0, 64)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local tabButtons = {}
local function setActiveTab(name)
    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 = (n == name) and Color3.fromRGB(48, 83, 125) or Color3.fromRGB(34, 38, 48)
    end
    activeTab = name
    -- repinta a lista
    local list = tabsData[name] or {}
    local text = {}
    for i, e in ipairs(list) do
        local line = string.format("%d. %s", i, e.label)
        if e.pos then
            line = string.format("%s  [x=%s y=%s z=%s]", line, tostring(e.pos.x), tostring(e.pos.y), tostring(e.pos.z))
        end
        table.insert(text, line)
    end
    output.Text = (#list > 0) and table.concat(text, "\n") or "(vazio ou ainda não escaneado)"
end

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

for _, name in ipairs(TABS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 82, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.Parent = tabBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

local output = Instance.new("TextBox")
output.Name = "Report"
output.Size = UDim2.new(1, -20, 1, -172)
output.Position = UDim2.new(0, 10, 0, 98)
output.BackgroundColor3 = Color3.fromRGB(11, 13, 18)
output.BorderSizePixel = 0
output.ClearTextOnFocus = false
output.MultiLine = true
output.TextWrapped = true
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.Font = Enum.Font.Code
output.TextSize = 12
output.TextColor3 = Color3.fromRGB(220, 225, 235)
output.Text = "Pronto. ESCANEAR mapeia o jogo; clique numa aba para ver a lista.\nClicar em uma linha NÃO teleporta — use os botões TELETRANSPORTE abaixo com o último item selecionado, ou digite o número da linha no campo e toque em IR."
output.Parent = frame

local outCorner = Instance.new("UICorner")
outCorner.CornerRadius = UDim.new(0, 7)
outCorner.Parent = output

local function makeButton(text, x, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(width, -6, 0, 30)
    b.Position = UDim2.new(x, 3, 1, -38)
    b.BackgroundColor3 = Color3.fromRGB(48, 83, 125)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    return b
end

local scanButton = makeButton("ESCANEAR", 0.00, 0.25)
local gotoButton  = makeButton("IR (#linha)", 0.25, 0.19)
local copyButton  = makeButton("COPIAR JSON", 0.44, 0.19)
local monButton   = makeButton("MONITOR: OFF", 0.63, 0.20)
local closeButton = makeButton("FECHAR", 0.83, 0.17)

closeButton.MouseButton1Click:Connect(function() gui:Destroy() end)

local lineBox = Instance.new("TextBox")
lineBox.Size = UDim2.new(0.17, 0, 0, 30)
lineBox.Position = UDim2.new(0.25, 3, 1, -38)
lineBox.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
lineBox.BorderSizePixel = 0
lineBox.PlaceholderText = "nº linha"
lineBox.Text = ""
lineBox.TextColor3 = Color3.new(1, 1, 1)
lineBox.TextSize = 12
lineBox.Font = Enum.Font.Code
lineBox.ClearTextOnFocus = true
lineBox.Parent = frame
local lbCorner = Instance.new("UICorner")
lbCorner.CornerRadius = UDim.new(0, 6)
lbCorner.Parent = lineBox

------------------------------------------------------------------
-- Scan
------------------------------------------------------------------
local report = nil
local MAX_PER_SECTION = 220

local function addTab(name, label, pos, extra)
    tabsData[name] = tabsData[name] or {}
    local list = tabsData[name]
    if #list < MAX_PER_SECTION then
        table.insert(list, {label=label, pos=pos, extra=extra})
    end
end

local KEYWORDS = {
    "ore","iron","gold","ruby","aluminium","limestone","refined stone",
    "chest","treasure","craft","forge","anvil","quest","board","spawn",
    "farm","mine","cave","boss","portal","teleport","zombie","goblin",
    "soldier","rat","farmer","phantom","stone eye"
}

local function matchName(name)
    local s = string.lower(name)
    for _, w in ipairs(KEYWORDS) do
        if string.find(s, w, 1, true) then return w end
    end
    return nil
end

scanButton.MouseButton1Click:Connect(function()
    report = {
        game={placeId=game.PlaceId, gameName=game.Name, jobId=game.JobId},
        player={name=player.Name, displayName=player.DisplayName, userId=player.UserId,
            position=player.Character and getPosition(player.Character) or nil, stats={}},
        counts={}, tools={}, guiObjects={}, npcs={}, prompts={},
        clickDetectors={}, remotes={}, resources={}, quests={},
        crafting={}, chests={}, otherLocations={}
    }
    -- limpa abas anteriores
    for _, name in ipairs(TABS) do tabsData[name] = {} end

    local okScan, scanError = pcall(function()
        status.Text = "Lendo inventário e status..."
        local backpack = safe(function() return player:FindFirstChildOfClass("Backpack") end)
        local function scanTools(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local vals = {}
                    for _, d in ipairs(tool:GetDescendants()) do
                        local v = getValue(d)
                        if v ~= nil and #vals < 50 then
                            table.insert(vals, {name=d.Name, class=d.ClassName, value=v})
                        end
                    end
                    table.insert(report.tools, {name=tool.Name, path=getPath(tool),
                        attributes=getAttributes(tool), values=vals})
                    addTab("Stats", "[Tool] " .. tool.Name)
                end
            end
        end
        scanTools(backpack)
        scanTools(player.Character)

        local roots = {
            player,
            safe(function() return player:FindFirstChild("leaderstats") end),
            safe(function() return player:FindFirstChild("Data") end),
            safe(function() return player:FindFirstChild("Stats") end)
        }
        local seenStats = {}
        for _, root in ipairs(roots) do
            if root then
                for _, obj in ipairs(root:GetDescendants()) do
                    if obj:IsA("ValueBase") then
                        local nm = string.lower(obj.Name)
                        if string.find(nm,"level") or string.find(nm,"strength")
                            or string.find(nm,"durability") or string.find(nm,"nen")
                            or string.find(nm,"weapon") or string.find(nm,"stamina")
                            or string.find(nm,"point") or string.find(nm,"exp")
                            or string.find(nm,"money") or string.find(nm,"jenni") then
                            local p = getPath(obj)
                            if not seenStats[p] then
                                seenStats[p] = true
                                local v = getValue(obj)
                                table.insert(report.player.stats, {path=p, value=v, class=obj.ClassName})
                                addTab("Stats", string.format("%s = %s", obj.Name, tostring(v)))
                            end
                        end
                    end
                end
            end
        end

        status.Text = "Mapeando mapa (NPCs, recursos, prompts)..."
        local descendants = Workspace:GetDescendants()
        local total = #descendants
        for index, obj in ipairs(descendants) do
            if index % 400 == 0 then
                status.Text = "Analisando mapa: " .. index .. " / " .. total
                task.wait()
            end

            if obj:IsA("Humanoid") and obj.Parent and obj.Parent:IsA("Model") then
                local model = obj.Parent
                if model ~= player.Character then
                    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                    local pos = root and getPosition(root) or getPosition(model)
                    local label = string.format("%s (HP %s/%s)", model.Name,
                        tostring(math.floor(obj.Health*10)/10), tostring(obj.MaxHealth))
                    table.insert(report.npcs, {name=model.Name, path=getPath(model),
                        health=math.floor(obj.Health*10)/10, maxHealth=obj.MaxHealth,
                        position=pos, attributes=getAttributes(model)})
                    addTab("NPCs", label, pos)
                end
            elseif obj:IsA("ProximityPrompt") then
                local pos = getPosition(obj.Parent)
                table.insert(report.prompts, {name=obj.Name, path=getPath(obj),
                    actionText=obj.ActionText, objectText=obj.ObjectText,
                    maxDistance=obj.MaxActivationDistance, enabled=obj.Enabled, position=pos})
                local label = string.format("%s | %s %s", obj.Name, obj.ActionText, obj.ObjectText)
                addTab("Prompts", label, pos)
            elseif obj:IsA("ClickDetector") then
                table.insert(report.clickDetectors, {name=obj.Name, path=getPath(obj),
                    maxDistance=obj.MaxActivationDistance, position=getPosition(obj.Parent)})
            end

            local matched = matchName(obj.Name)
            if matched then
                local pos = getPosition(obj)
                local entry = {name=obj.Name, class=obj.ClassName, path=getPath(obj),
                    matched=matched, position=pos}
                local label = string.format("%s (%s)", obj.Name, obj.ClassName)
                if matched == "chest" or matched == "treasure" then
                    table.insert(report.chests, entry); addTab("Baús", label, pos)
                elseif matched == "craft" or matched == "forge" or matched == "anvil" then
                    table.insert(report.crafting, entry); addTab("Craft", label, pos)
                elseif matched == "quest" or matched == "board" then
                    table.insert(report.quests, entry); addTab("Quests", label, pos)
                elseif matched == "ore" or matched == "iron" or matched == "gold"
                    or matched == "ruby" or matched == "aluminium"
                    or matched == "limestone" or matched == "refined stone" then
                    table.insert(report.resources, entry); addTab("Recursos", label, pos)
                else
                    table.insert(report.otherLocations, entry)
                end
            end
        end

        status.Text = "Listando remotes replicados..."
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                or obj.ClassName == "UnreliableRemoteEvent" then
                table.insert(report.remotes, {name=obj.Name, class=obj.ClassName, path=getPath(obj)})
                addTab("Remotes", string.format("%s (%s)", obj.Name, obj.ClassName))
            end
        end
    end)

    if not okScan then
        status.Text = "Erro no scan."
        output.Text = "ERRO NO SCAN:\n" .. tostring(scanError)
        return
    end

    report.counts = {
        tools=#report.tools, stats=#report.player.stats, npcs=#report.npcs,
        prompts=#report.prompts, clickDetectors=#report.clickDetectors,
        remotes=#report.remotes, resources=#report.resources, quests=#report.quests,
        crafting=#report.crafting, chests=#report.chests,
        otherLocations=#report.otherLocations
    }
    status.Text = "Scan concluído! Veja as abas."
    setActiveTab(activeTab or "NPCs")
end)

------------------------------------------------------------------
-- Teleporte por número de linha
------------------------------------------------------------------
gotoButton.MouseButton1Click:Connect(function()
    local n = tonumber(lineBox.Text)
    local list = activeTab and tabsData[activeTab]
    if not n or not list or not list[n] then
        status.Text = "Linha inválida para a aba ativa."
        return
    end
    local entry = list[n]
    if entry.pos and teleportTo(entry.pos) then
        status.Text = "Teleportado (local) para: " .. entry.label
    else
        status.Text = "Esse item não tem posição válida."
    end
end)

------------------------------------------------------------------
-- Copiar JSON
------------------------------------------------------------------
copyButton.MouseButton1Click:Connect(function()
    if not report then
        status.Text = "Rode o ESCANEAR primeiro."
        return
    end
    local encoded = safe(function() return HttpService:JSONEncode(report) end, nil)
    if not encoded then
        status.Text = "Falha ao gerar JSON."
        return
    end
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, encoded)
        status.Text = ok and "JSON copiado!" or "Falha ao copiar."
    else
        output.Text = encoded
        status.Text = "setclipboard indisponível; JSON na caixa."
        output:CaptureFocus()
    end
end)

------------------------------------------------------------------
-- Monitor de remotes (somente leitura: registra disparos)
------------------------------------------------------------------
local monitorOn = false
local monitorLog = {}
local monitorConn = nil
local monitorHook = nil

local function logRemote(kind, remote, ...)
    local args = {}
    for i = 1, math.min(select("#", ...), 6) do
        table.insert(args, cleanValue((select(i, ...)), 0))
    end
    table.insert(monitorLog, string.format("[%s] %s (%s) args: %s",
        os.date("%H:%M:%S"), remote.Name, kind,
        safe(function() return HttpService:JSONEncode(args) end, "...")))
    if #monitorLog > 300 then table.remove(monitorLog, 1) end
    if activeTab == "Monitor" then
        output.Text = table.concat(monitorLog, "\n")
    end
end

monButton.MouseButton1Click:Connect(function()
    monitorOn = not monitorOn
    monButton.Text = "MONITOR: " .. (monitorOn and "ON" or "OFF")
    monButton.BackgroundColor3 = monitorOn and Color3.fromRGB(46, 140, 80) or Color3.fromRGB(48, 83, 125)
    if monitorOn then
        monitorLog = {}
        status.Text = "Monitor ligado. Abra a aba MONITOR."
        -- Registra eventos recebidos do servidor (não dispara nada):
        monitorConn = safe(function()
            local c = {}
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local ok, conn = pcall(function()
                        return obj.OnClientEvent:Connect(function(...)
                            logRemote("recebido", obj, ...)
                        end)
                    end)
                    if ok then table.insert(c, conn) end
                end
            end
            return c
        end, {})
        -- Hook de disparos feitos pelo cliente, se o executor suportar:
        monitorHook = safe(function()
            if type(hookmetamethod) == "function" then
                local old
                old = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = safe(function() return getnamecallmethod() end, "")
                    if method == "FireServer" or method == "InvokeServer" then
                        if self and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                            logRemote("enviado", self, ...)
                        end
                    end
                    return old(self, ...)
                end)
                return old
            end
            return nil
        end, nil)
        setActiveTab("Monitor")
    else
        if monitorConn then
            for _, c in ipairs(monitorConn) do safe(function() c:Disconnect() end) end
            monitorConn = nil
        end
        status.Text = "Monitor desligado."
    end
end)

print("[BeyondNen LeaderPanel] Carregado. ESCANEAR para mapear o jogo.")

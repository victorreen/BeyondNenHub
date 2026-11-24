--[[
BEYOND NEN - IN-GAME CLIENT SCANNER v2.0
Abre uma janela na tela do jogador.
Somente leitura: não chama RemoteEvents/RemoteFunctions e não altera o jogo.
Execute pelo executor depois de carregar completamente no Beyond Nen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

if not player then
    warn("[Beyond Nen Scanner] Entre no jogo antes de executar.")
    return
end

-- Remove painel de uma execução anterior.
local GUI_NAME = "BeyondNenScannerPanel"
local function safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

local parentGui = safe(function()
    if type(gethui) == "function" then
        return gethui()
    end
    return CoreGui
end, nil)

if not parentGui then
    parentGui = safe(function() return player:WaitForChild("PlayerGui") end, nil)
end
if not parentGui then
    warn("[Beyond Nen Scanner] Não consegui criar a interface.")
    return
end

safe(function()
    local old = parentGui:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

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
title.Text = "BEYOND NEN  |  CLIENT SCANNER"
title.TextColor3 = Color3.fromRGB(235, 238, 245)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 26)
status.Position = UDim2.new(0, 10, 0, 42)
status.BackgroundTransparency = 1
status.Text = "Preparando scan..."
status.TextColor3 = Color3.fromRGB(130, 205, 255)
status.TextSize = 13
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local output = Instance.new("TextBox")
output.Name = "Report"
output.Size = UDim2.new(1, -20, 1, -126)
output.Position = UDim2.new(0, 10, 0, 72)
output.BackgroundColor3 = Color3.fromRGB(11, 13, 18)
output.BorderSizePixel = 0
output.ClearTextOnFocus = false
output.MultiLine = true
output.TextWrapped = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.Font = Enum.Font.Code
output.TextSize = 12
output.TextColor3 = Color3.fromRGB(220, 225, 235)
output.Text = "Iniciando..."
output.Parent = frame

local outCorner = Instance.new("UICorner")
outCorner.CornerRadius = UDim.new(0, 7)
outCorner.Parent = output

local function makeButton(text, x, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(width, -6, 0, 34)
    b.Position = UDim2.new(x, 3, 1, -43)
    b.BackgroundColor3 = Color3.fromRGB(48, 83, 125)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b
    return b
end

local copyButton = makeButton("COPIAR RELATÓRIO", 0, 0.50)
local closeButton = makeButton("FECHAR", 0.50, 0.50)

closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local lastJson = nil
copyButton.MouseButton1Click:Connect(function()
    if not lastJson then
        status.Text = "O scan ainda não terminou."
        return
    end
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, lastJson)
        status.Text = ok and "JSON copiado! Cole aqui na conversa." or "Falha ao copiar. Selecione o texto da caixa."
    else
        status.Text = "Selecione o texto da caixa e copie manualmente."
        output:CaptureFocus()
    end
end)

local function setStatus(s)
    status.Text = s
end

local function getPath(obj)
    return safe(function() return obj:GetFullName() end, obj.Name)
end

local function getPosition(obj)
    return safe(function()
        local p
        if obj:IsA("BasePart") then
            p = obj.Position
        elseif obj:IsA("Model") then
            p = obj:GetPivot().Position
        elseif obj.Parent and obj.Parent:IsA("BasePart") then
            p = obj.Parent.Position
        end
        if p then
            return {
                x=math.floor(p.X*10)/10,
                y=math.floor(p.Y*10)/10,
                z=math.floor(p.Z*10)/10
            }
        end
        return nil
    end, nil)
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
        for k, value in pairs(v) do
            t[tostring(k)] = cleanValue(value, depth + 1)
        end
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

local report = {
    game={placeId=game.PlaceId, gameName=game.Name, jobId=game.JobId},
    player={
        name=player.Name, displayName=player.DisplayName, userId=player.UserId,
        position=player.Character and getPosition(player.Character) or nil,
        stats={}
    },
    counts={}, tools={}, guiObjects={}, npcs={}, prompts={},
    clickDetectors={}, remotes={}, resources={}, quests={},
    crafting={}, chests={}, otherLocations={}
}

local MAX_PER_SECTION = 220
local function add(list, entry)
    if #list < MAX_PER_SECTION then
        table.insert(list, entry)
    end
end

local okScan, scanError = pcall(function()
    setStatus("Lendo inventário e status...")
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
                add(report.tools, {
                    name=tool.Name, path=getPath(tool),
                    attributes=getAttributes(tool), values=vals
                })
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
                            add(report.player.stats, {path=p, value=getValue(obj), class=obj.ClassName})
                        end
                    end
                end
            end
        end
    end

    setStatus("Lendo interface do jogador...")
    local pg = safe(function() return player:FindFirstChildOfClass("PlayerGui") end)
    if pg then
        for _, obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local txt = safe(function() return obj.Text end, "")
                if txt and txt ~= "" then
                    add(report.guiObjects, {
                        path=getPath(obj), class=obj.ClassName,
                        text=string.sub(tostring(txt), 1, 140),
                        visible=safe(function() return obj.Visible end, nil)
                    })
                end
            elseif obj:IsA("ImageButton") then
                add(report.guiObjects, {path=getPath(obj), class=obj.ClassName})
            end
        end
    end

    setStatus("Mapeando NPCs, minérios, prompts e objetos...")
    local keywords = {
        "ore","iron","gold","ruby","aluminium","limestone","refined stone",
        "chest","treasure","craft","forge","anvil","quest","board","spawn",
        "farm","mine","cave","boss","portal","teleport","zombie","goblin",
        "soldier","rat","farmer","phantom","stone eye"
    }
    local function matchName(name)
        local s = string.lower(name)
        for _, w in ipairs(keywords) do
            if string.find(s, w, 1, true) then return w end
        end
        return nil
    end

    local descendants = Workspace:GetDescendants()
    local total = #descendants
    for index, obj in ipairs(descendants) do
        if index % 250 == 0 then
            setStatus("Analisando mapa: " .. index .. " / " .. total)
            task.wait()
        end

        if obj:IsA("Humanoid") then
            local model = obj.Parent
            if model and model:IsA("Model") then
                local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                add(report.npcs, {
                    name=model.Name, path=getPath(model),
                    health=math.floor(obj.Health*10)/10, maxHealth=obj.MaxHealth,
                    position=root and getPosition(root) or getPosition(model),
                    attributes=getAttributes(model)
                })
            end
        elseif obj:IsA("ProximityPrompt") then
            add(report.prompts, {
                name=obj.Name, path=getPath(obj), actionText=obj.ActionText,
                objectText=obj.ObjectText, maxDistance=obj.MaxActivationDistance,
                enabled=obj.Enabled, position=getPosition(obj.Parent)
            })
        elseif obj:IsA("ClickDetector") then
            add(report.clickDetectors, {
                name=obj.Name, path=getPath(obj),
                maxDistance=obj.MaxActivationDistance, position=getPosition(obj.Parent)
            })
        end

        local matched = matchName(obj.Name)
        if matched then
            local entry = {
                name=obj.Name, class=obj.ClassName, path=getPath(obj),
                matched=matched, position=getPosition(obj)
            }
            if matched == "chest" or matched == "treasure" then
                add(report.chests, entry)
            elseif matched == "craft" or matched == "forge" or matched == "anvil" then
                add(report.crafting, entry)
            elseif matched == "quest" or matched == "board" then
                add(report.quests, entry)
            elseif matched == "ore" or matched == "iron" or matched == "gold"
                or matched == "ruby" or matched == "aluminium"
                or matched == "limestone" or matched == "refined stone" then
                add(report.resources, entry)
            else
                add(report.otherLocations, entry)
            end
        end
    end

    setStatus("Listando remotes replicados (sem executar)...")
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
            or obj.ClassName == "UnreliableRemoteEvent" then
            add(report.remotes, {
                name=obj.Name, class=obj.ClassName, path=getPath(obj)
            })
        end
    end
end)

if not okScan then
    setStatus("O scan encontrou um erro. Veja a mensagem abaixo.")
    output.Text = "ERRO NO SCAN:\n" .. tostring(scanError)
    warn("[Beyond Nen Scanner] " .. tostring(scanError))
    return
end

report.counts = {
    tools=#report.tools, stats=#report.player.stats, gui=#report.guiObjects,
    npcs=#report.npcs, prompts=#report.prompts,
    clickDetectors=#report.clickDetectors, remotes=#report.remotes,
    resources=#report.resources, quests=#report.quests,
    crafting=#report.crafting, chests=#report.chests,
    otherLocations=#report.otherLocations
}

setStatus("Montando relatório...")
local encoded, jsonError = safe(function()
    return HttpService:JSONEncode(report)
end, nil)

if not encoded then
    setStatus("Falha ao montar JSON.")
    output.Text = "ERRO AO GERAR JSON: " .. tostring(jsonError)
    return
end

lastJson = encoded
local summary = safe(function() return HttpService:JSONEncode(report.counts) end, "{}")
output.Text = "SCAN CONCLUÍDO\n\nRESUMO:\n" .. summary
    .. "\n\nJSON COMPLETO (" .. #encoded .. " caracteres):\n\n" .. encoded
setStatus("Scan concluído! Toque em COPIAR RELATÓRIO.")
print("[Beyond Nen Scanner] Concluído. Resumo: " .. summary)

if type(setclipboard) == "function" then
    safe(function() setclipboard(encoded) end)
end

--[[
BEYOND NEN - CLIENT SCANNER v1.1
Para diagnóstico somente leitura no cliente.
Não dispara remotes, não ataca, não coleta credenciais e não altera o jogo.
Só consegue ver objetos replicados ao cliente.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

if not player then
    warn("[Beyond Nen Scanner] LocalPlayer não encontrado. Execute depois de entrar no jogo.")
    return
end

local function safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

local function pathOf(obj)
    return safe(function() return obj:GetFullName() end, obj.Name)
end

local function posOf(obj)
    return safe(function()
        local p
        if obj:IsA("BasePart") then
            p = obj.Position
        elseif obj:IsA("Model") then
            p = obj:GetPivot().Position
        elseif obj.Parent and obj.Parent:IsA("BasePart") then
            p = obj.Parent.Position
        end
        if p then return {x=math.floor(p.X*10)/10, y=math.floor(p.Y*10)/10, z=math.floor(p.Z*10)/10} end
        return nil
    end, nil)
end

-- Converte atributos e outros tipos Roblox para valores que JSONEncode aceita.
local function jsonSafe(value, depth)
    depth = depth or 0
    if depth > 4 then return tostring(value) end

    local kind = typeof(value)
    if kind == "nil" or kind == "string" or kind == "boolean" or kind == "number" then
        return value
    elseif kind == "Vector3" or kind == "Vector2" or kind == "Color3"
        or kind == "CFrame" or kind == "UDim" or kind == "UDim2"
        or kind == "BrickColor" or kind == "EnumItem"
        or kind == "NumberRange" or kind == "Rect" then
        return tostring(value)
    elseif kind == "Instance" then
        return pathOf(value)
    elseif kind == "table" then
        local out = {}
        for k, v in pairs(value) do
            out[tostring(k)] = jsonSafe(v, depth + 1)
        end
        return out
    end
    return tostring(value)
end

local function attrsOf(obj)
    return jsonSafe(safe(function() return obj:GetAttributes() end, {}))
end

local function valOf(obj)
    return safe(function()
        if obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("BoolValue") then
            return jsonSafe(obj.Value)
        end
        return nil
    end, nil)
end

local data = {
    game = {placeId=game.PlaceId, name=game.Name, jobId=game.JobId},
    player = {
        name=player.Name, displayName=player.DisplayName, userId=player.UserId,
        characterPosition=player.Character and posOf(player.Character) or nil,
        stats={}
    },
    counts = {},
    tools = {}, gui = {}, npcs = {}, prompts = {}, clickDetectors = {},
    remotes = {}, resources = {}, questBoards = {}, crafting = {},
    chests = {}, mapObjects = {}
}

local LIMIT = 400
local function add(list, item)
    if #list < LIMIT then
        table.insert(list, item)
    end
end

-- Backpack e ferramentas equipadas.
local function scanTools(container)
    if not container then return end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Tool") then
            local values = {}
            for _, d in ipairs(obj:GetDescendants()) do
                local v = valOf(d)
                if v ~= nil then add(values, {name=d.Name, class=d.ClassName, value=v}) end
            end
            add(data.tools, {
                name=obj.Name, path=pathOf(obj),
                attributes=attrsOf(obj), values=values
            })
        end
    end
end

scanTools(safe(function() return player:FindFirstChildOfClass("Backpack") end))
scanTools(player.Character)

-- Interface do jogador: textos e botões.
local pg = safe(function() return player:FindFirstChildOfClass("PlayerGui") end)
if pg then
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local txt = safe(function() return obj.Text end, "")
            if txt and txt ~= "" then
                add(data.gui, {
                    path=pathOf(obj), class=obj.ClassName,
                    text=string.sub(tostring(txt), 1, 160),
                    visible=safe(function() return obj.Visible end, nil)
                })
            end
        elseif obj:IsA("ImageButton") then
            add(data.gui, {path=pathOf(obj), class=obj.ClassName})
        end
    end
end

-- Dados do jogador: leaderstats, Data, Stats e valores sob o Player.
local statRoots = {
    player,
    safe(function() return player:FindFirstChild("leaderstats") end),
    safe(function() return player:FindFirstChild("Data") end),
    safe(function() return player:FindFirstChild("Stats") end)
}
local statSeen = {}
for _, root in pairs(statRoots) do
    if root then
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ValueBase") then
                local name = string.lower(obj.Name)
                if string.find(name,"level") or string.find(name,"strength")
                    or string.find(name,"durability") or string.find(name,"nen")
                    or string.find(name,"weapon") or string.find(name,"stamina")
                    or string.find(name,"point") or string.find(name,"exp")
                    or string.find(name,"money") or string.find(name,"jenni") then
                    local p = pathOf(obj)
                    if not statSeen[p] then
                        statSeen[p] = true
                        add(data.player.stats, {path=p, value=valOf(obj), class=obj.ClassName})
                    end
                end
            end
        end
    end
end

-- Objetos do Workspace, NPCs, interações e alvos de interesse.
local words = {
    "ore","iron","gold","ruby","aluminium","limestone","refined stone",
    "chest","treasure","craft","forge","anvil","quest","board","spawn",
    "farm","mine","cave","boss","portal","teleport","zombie","goblin",
    "soldier","rat","farmer","phantom","stone eye"
}
local function matchedWord(name)
    local s = string.lower(name)
    for _, word in ipairs(words) do
        if string.find(s, word, 1, true) then return word end
    end
end

local allDesc = safe(function() return Workspace:GetDescendants() end, {})
for _, obj in ipairs(allDesc) do
    if obj:IsA("Humanoid") then
        local model = obj.Parent
        if model and model:IsA("Model") then
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            add(data.npcs, {
                name=model.Name, path=pathOf(model),
                health=math.floor(obj.Health*10)/10,
                maxHealth=obj.MaxHealth,
                position=root and posOf(root) or posOf(model),
                attributes=attrsOf(model)
            })
        end
    elseif obj:IsA("ProximityPrompt") then
        add(data.prompts, {
            name=obj.Name, path=pathOf(obj),
            action=obj.ActionText, object=obj.ObjectText,
            distance=obj.MaxActivationDistance, enabled=obj.Enabled,
            position=posOf(obj.Parent)
        })
    elseif obj:IsA("ClickDetector") then
        add(data.clickDetectors, {
            name=obj.Name, path=pathOf(obj),
            distance=obj.MaxActivationDistance, position=posOf(obj.Parent)
        })
    end

    local match = matchedWord(obj.Name)
    if match then
        local entry = {
            name=obj.Name, class=obj.ClassName, path=pathOf(obj),
            matched=match, position=posOf(obj)
        }
        if match == "chest" or match == "treasure" then
            add(data.chests, entry)
        elseif match == "craft" or match == "forge" or match == "anvil" then
            add(data.crafting, entry)
        elseif match == "quest" or match == "board" then
            add(data.questBoards, entry)
        else
            add(data.resources, entry)
        end
    end
end

-- Remotes replicados: identificar apenas. Nenhum é executado.
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj.ClassName == "UnreliableRemoteEvent" then
        add(data.remotes, {name=obj.Name, class=obj.ClassName, path=pathOf(obj)})
    end
end

data.counts = {
    tools=#data.tools, guiEntries=#data.gui, stats=#data.player.stats,
    npcs=#data.npcs, prompts=#data.prompts, clickDetectors=#data.clickDetectors,
    remotes=#data.remotes, resources=#data.resources,
    questBoards=#data.questBoards, crafting=#data.crafting, chests=#data.chests
}

local encoded, encodeError = safe(function() return HttpService:JSONEncode(data) end, nil)

print("========== BEYOND NEN CLIENT SCAN v1.1 ==========")
print("PlaceId:", game.PlaceId, "| Jogador:", player.Name)
print("RESUMO:", safe(function() return HttpService:JSONEncode(data.counts) end, "{}"))

if not encoded then
    warn("[Beyond Nen Scanner] Falha ao montar JSON. Erro: " .. tostring(encodeError))
    warn("Envie o erro que apareceu no console.")
    return
end

-- Alguns consoles cortam mensagens grandes; divide em blocos pequenos.
local chunkSize = 5000
local total = math.ceil(#encoded / chunkSize)
print("RELATORIO:", #encoded, "caracteres |", total, "partes")
for i = 1, total do
    print("=== BN_SCAN_" .. i .. "_DE_" .. total .. " ===")
    print(string.sub(encoded, (i-1)*chunkSize + 1, i*chunkSize))
end

if type(setclipboard) == "function" then
    local ok = pcall(setclipboard, encoded)
    if ok then print("JSON copiado para a area de transferencia.") end
end

print("========== SCAN FINALIZADO ==========")

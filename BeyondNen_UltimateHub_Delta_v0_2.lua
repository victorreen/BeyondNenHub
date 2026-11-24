-- Beyond Nen - Client World Scanner (jogo normal)
-- Uso: execute uma vez no cliente do jogo pelo executor que você já utiliza.
-- Este scanner é somente leitura: NÃO dispara RemoteEvents/RemoteFunctions,
-- não coleta dados privados e não altera objetos do jogo.
-- Limite: só enxerga o que foi replicado para o cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

local function fullPath(inst)
    return safe(function() return inst:GetFullName() end, inst.Name)
end

local function positionOf(inst)
    return safe(function()
        if inst:IsA("BasePart") then return {x=inst.Position.X,y=inst.Position.Y,z=inst.Position.Z} end
        if inst:IsA("Model") then
            local cf = inst:GetPivot()
            return {x=cf.Position.X,y=cf.Position.Y,z=cf.Position.Z}
        end
    end, nil)
end

local function valueOf(inst)
    if inst:IsA("StringValue") or inst:IsA("IntValue") or inst:IsA("NumberValue") or inst:IsA("BoolValue") then
        return safe(function() return inst.Value end, nil)
    end
    return nil
end

local report = {
    game = {placeId = game.PlaceId, jobId = game.JobId, name = game.Name},
    player = {},
    counts = {},
    playerGui = {},
    tools = {},
    npcs = {},
    prompts = {},
    clickDetectors = {},
    remotes = {},
    resources = {},
    questBoards = {},
    crafting = {},
    chests = {},
    mapLocations = {},
    interestingObjects = {},
}

report.player = {
    name = player.Name,
    displayName = player.DisplayName,
    userId = player.UserId,
    levelAndStats = {},
    character = player.Character and fullPath(player.Character) or nil,
    position = player.Character and positionOf(player.Character) or nil
}

local function addCount(key, n)
    report.counts[key] = n
end

-- GUI: nomes, caminhos e textos visíveis úteis para localizar botões/objetivos.
local pg = safe(function() return player:FindFirstChildOfClass("PlayerGui") end)
if pg then
    local n = 0
    for _, obj in ipairs(pg:GetDescendants()) do
        n += 1
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local txt = safe(function() return obj.Text end, "")
            if txt ~= "" then
                table.insert(report.playerGui, {
                    path = fullPath(obj),
                    class = obj.ClassName,
                    text = string.sub(txt, 1, 180),
                    visible = safe(function() return obj.Visible end, nil)
                })
            end
        elseif obj:IsA("ImageButton") then
            table.insert(report.playerGui, {path=fullPath(obj), class=obj.ClassName})
        end
    end
    addCount("guiDescendants", n)
end

-- Ferramentas do jogador e atributos/valores descendentes.
local function scanTools(container)
    if not container then return end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Tool") then
            local item = {name=obj.Name, path=fullPath(obj), attributes=safe(function() return obj:GetAttributes() end, {})}
            item.values = {}
            for _, d in ipairs(obj:GetDescendants()) do
                local v = valueOf(d)
                if v ~= nil then table.insert(item.values, {name=d.Name, class=d.ClassName, value=v}) end
            end
            table.insert(report.tools, item)
        end
    end
end
scanTools(safe(function() return player:FindFirstChildOfClass("Backpack") end))
scanTools(player.Character)

-- NPCs e modelos com Humanoid. Não tenta atacar nem interagir.
local npcCount = 0
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Humanoid") then
        local model = obj.Parent
        if model and model:IsA("Model") then
            npcCount += 1
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            local item = {
                name=model.Name, path=fullPath(model),
                health=obj.Health, maxHealth=obj.MaxHealth,
                displayName=safe(function() return obj.DisplayName end, nil),
                position=root and positionOf(root) or positionOf(model),
                attributes=safe(function() return model:GetAttributes() end, {})
            }
            table.insert(report.npcs, item)
        end
    end
end
addCount("humanoids", npcCount)

-- ProximityPrompts e ClickDetectors.
for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        table.insert(report.prompts, {
            path=fullPath(obj), name=obj.Name,
            actionText=obj.ActionText, objectText=obj.ObjectText,
            holdDuration=obj.HoldDuration, maxActivationDistance=obj.MaxActivationDistance,
            enabled=obj.Enabled, position=positionOf(obj.Parent)
        })
    elseif obj:IsA("ClickDetector") then
        table.insert(report.clickDetectors, {
            path=fullPath(obj), name=obj.Name,
            maxActivationDistance=obj.MaxActivationDistance,
            position=positionOf(obj.Parent)
        })
    end
end

-- Remotes: somente nomes/caminhos/tipo. Nenhum remote é chamado.
for _, root in ipairs({ReplicatedStorage, Workspace}) do
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            table.insert(report.remotes, {name=obj.Name, class=obj.ClassName, path=fullPath(obj)})
        end
    end
end

-- Objetos relevantes por nome (minas, minério, baús, crafting, quests, locais).
local keywords = {
    "ore","iron","gold","ruby","aluminium","limestone","stone","mine",
    "chest","treasure","craft","forge","anvil","quest","board","spawn",
    "farm","village","forest","desert","cave","boss","portal","teleport"
}
local function hasKeyword(s)
    s = string.lower(s)
    for _, word in ipairs(keywords) do
        if string.find(s, word, 1, true) then return word end
    end
    return nil
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    local matched = hasKeyword(obj.Name)
    if matched then
        local entry = {
            name=obj.Name, class=obj.ClassName, path=fullPath(obj),
            matched=matched, position=positionOf(obj)
        }
        if string.find(matched, "ore", 1, true) or matched == "iron" or matched == "gold" or matched == "ruby" or matched == "aluminium" or matched == "limestone" then
            table.insert(report.resources, entry)
        elseif matched == "chest" or matched == "treasure" then
            table.insert(report.chests, entry)
        elseif matched == "craft" or matched == "forge" or matched == "anvil" then
            table.insert(report.crafting, entry)
        elseif matched == "quest" or matched == "board" then
            table.insert(report.questBoards, entry)
        else
            table.insert(report.mapLocations, entry)
        end
    end
end

-- Valores/atributos que podem indicar level, stats ou progressão em pastas replicadas.
local roots = {
    player,
    player.Character,
    safe(function() return player:FindFirstChild("leaderstats") end),
    safe(function() return player:FindFirstChild("Data") end),
    safe(function() return player:FindFirstChild("Stats") end),
    ReplicatedStorage
}
local seen = {}
for _, root in ipairs(roots) do
    if root then
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ValueBase") then
                local val = valueOf(obj)
                if val ~= nil then
                    local nm = string.lower(obj.Name)
                    if string.find(nm,"level") or string.find(nm,"strength") or string.find(nm,"durability")
                    or string.find(nm,"nen") or string.find(nm,"weapon") or string.find(nm,"stamina")
                    or string.find(nm,"point") or string.find(nm,"exp") or string.find(nm,"money")
                    or string.find(nm,"jenni") then
                        local p = fullPath(obj)
                        if not seen[p] then
                            seen[p] = true
                            table.insert(report.player.levelAndStats, {path=p, value=val, class=obj.ClassName})
                        end
                    end
                end
            end
        end
    end
end

-- Resumo dos totais.
for key, list in pairs({
    tools=report.tools, guiTexts=report.playerGui, prompts=report.prompts,
    clickDetectors=report.clickDetectors, remotes=report.remotes,
    resources=report.resources, questBoards=report.questBoards,
    crafting=report.crafting, chests=report.chests, mapLocations=report.mapLocations
}) do
    addCount(key, #list)
end

local json = safe(function() return HttpService:JSONEncode(report) end, nil)
print("========== BEYOND NEN CLIENT SCAN ==========")
print("PlaceId:", game.PlaceId, "| Jogador:", player.Name)
print("Resumo:", safe(function() return HttpService:JSONEncode(report.counts) end, "{}"))

if json then
    local chunkSize = 8000
    local total = math.ceil(#json / chunkSize)
    print("JSON completo abaixo em", total, "partes. Copie todas na ordem.")
    for i = 1, total do
        print("=== BEYOND_NEN_SCAN_PART_" .. i .. "_OF_" .. total .. " ===")
        print(string.sub(json, (i-1)*chunkSize + 1, i*chunkSize))
    end
    if type(setclipboard) == "function" then
        safe(function() setclipboard(json) end)
        print("JSON também enviado para a área de transferência.")
    end
else
    warn("Não foi possível serializar o relatório.")
end

print("========== SCAN FINALIZADO ==========")

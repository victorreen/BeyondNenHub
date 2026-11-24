--[[
BEYOND NEN - WORLD SCANNER FOR ROBLOX STUDIO
Version: 1.1
Purpose: Read-only map/environment inventory for the developer's own Studio place.
Run: Roblox Studio > View > Command Bar, while NOT in Play mode; paste the whole file.
Output: ServerStorage.BeyondNenWorldScan (Summary + JSON chunks + category folders).

This script does NOT use executors, HTTP, remotes, attacks, teleports, or modify game objects.
It reads Workspace and writes a scan report under ServerStorage.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

if not RunService:IsStudio() then
    error("Run this scanner from Roblox Studio's Command Bar.")
end

local CONFIG = {
    CELL_SIZE = 512,             -- X/Z grid size used to index the map
    JSON_CHUNK_SIZE = 45000,     -- kept small for easy copying from StringValues
    MAX_LABELS_PER_BOARD = 40,
    MAX_TAG_EXAMPLES = 20,
    YIELD_EVERY = 2500,
    INCLUDE_ALL_MAP_PARTS = true,
}

local function round(n)
    return math.floor((n or 0) * 10 + 0.5) / 10
end

local function vec3(v)
    if not v then return nil end
    return {x = round(v.X), y = round(v.Y), z = round(v.Z)}
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function hasAny(text, words)
    text = lower(text)
    for _, word in ipairs(words) do
        if string.find(text, lower(word), 1, true) then
            return true
        end
    end
    return false
end

local function getPath(inst)
    local ok, result = pcall(function() return inst:GetFullName() end)
    return ok and result or tostring(inst)
end

local function safeAttribute(value)
    local kind = typeof(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return value
    elseif kind == "Vector3" then
        return vec3(value)
    elseif kind == "Vector2" then
        return {x = round(value.X), y = round(value.Y)}
    elseif kind == "Color3" then
        return {r = round(value.R), g = round(value.G), b = round(value.B)}
    elseif kind == "Instance" then
        return getPath(value)
    else
        return tostring(value)
    end
end

local function getRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getPosition(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Attachment") then
        return inst.WorldPosition
    elseif inst:IsA("Model") then
        local root = getRootPart(inst)
        if root then return root.Position end
        local ok, cf = pcall(function()
            local boxCF = inst:GetBoundingBox()
            return boxCF
        end)
        if ok and cf then return cf.Position end
    end
    local parent = inst.Parent
    while parent and parent ~= Workspace do
        if parent:IsA("BasePart") then return parent.Position end
        if parent:IsA("Model") then
            local root = getRootPart(parent)
            if root then return root.Position end
        end
        parent = parent.Parent
    end
    return nil
end

local function getPartsBounds(parts)
    if #parts == 0 then return nil end
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, part in ipairs(parts) do
        local p, half = part.Position, part.Size * 0.5
        minX = math.min(minX, p.X - half.X); maxX = math.max(maxX, p.X + half.X)
        minY = math.min(minY, p.Y - half.Y); maxY = math.max(maxY, p.Y + half.Y)
        minZ = math.min(minZ, p.Z - half.Z); maxZ = math.max(maxZ, p.Z + half.Z)
    end
    return {
        min = {x = round(minX), y = round(minY), z = round(minZ)},
        max = {x = round(maxX), y = round(maxY), z = round(maxZ)},
        center = {x = round((minX + maxX) / 2), y = round((minY + maxY) / 2), z = round((minZ + maxZ) / 2)},
        size = {x = round(maxX - minX), y = round(maxY - minY), z = round(maxZ - minZ)},
    }
end

local function descendantsOf(root)
    if not root then return {} end
    return root:GetDescendants()
end

local function findAncestorNamed(inst, root, predicate)
    local current = inst
    while current and current ~= root do
        if predicate(current) then return current end
        current = current.Parent
    end
    return nil
end

local function directChildUnder(inst, ancestor)
    local current = inst
    while current and current.Parent ~= ancestor do
        current = current.Parent
    end
    if current and current.Parent == ancestor then return current end
    return nil
end

local function collectTextLabels(root, maxCount)
    local labels = {}
    if not root then return labels end
    for _, item in ipairs(root:GetDescendants()) do
        if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
            local text = tostring(item.Text or "")
            if text ~= "" then
                table.insert(labels, {
                    class = item.ClassName,
                    name = item.Name,
                    text = string.sub(text, 1, 240),
                    path = getPath(item),
                    visible = item.Visible,
                })
                if #labels >= (maxCount or 30) then break end
            end
        end
    end
    return labels
end

local report = {
    meta = {
        scanner = "Beyond Nen World Scanner",
        version = "1.1",
        placeId = game.PlaceId,
        placeVersion = game.PlaceVersion,
        scannedAtUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        mode = "Roblox Studio Command Bar / read-only Workspace scan",
        cellSize = CONFIG.CELL_SIZE,
        terrainNote = "Terrain voxel occupancy is not expanded into individual cells; map geometry records include BaseParts under World.Map.",
    },
    summary = {},
    map = {bounds = nil, zones = {}, grid = {}, parts = {}},
    actors = {humanoids = {}, prompts = {}, clickDetectors = {}},
    quests = {boards = {}, questRelatedObjects = {}},
    resources = {ores = {}, miningStructures = {}},
    pointsOfInterest = {mapLocations = {}, crafting = {}, chests = {}, spawnLocations = {}, namedLandmarks = {}},
    tags = {},
    architecture = {services = {}, remoteEndpoints = {}, scripts = {}, systemCandidates = {}},
}

local allWorkspace = Workspace:GetDescendants()
local world = Workspace:FindFirstChild("World")
local mapRoot = world and world:FindFirstChild("Map")
local mapDescendants = mapRoot and mapRoot:GetDescendants() or {}

-- Index map geometry and split it into spatial grid cells.
local mapParts = {}
local grid = {}
local zoneStats = {}
local mapPartCount = 0

if mapRoot then
    for index, inst in ipairs(mapDescendants) do
        if inst:IsA("BasePart") then
            mapPartCount += 1
            local p, s = inst.Position, inst.Size
            local gx = math.floor(p.X / CONFIG.CELL_SIZE)
            local gz = math.floor(p.Z / CONFIG.CELL_SIZE)
            local cellKey = tostring(gx) .. "," .. tostring(gz)
            local cell = grid[cellKey]
            if not cell then
                cell = {gx = gx, gz = gz, count = 0, minY = math.huge, maxY = -math.huge, samples = {}}
                grid[cellKey] = cell
            end
            cell.count += 1
            cell.minY = math.min(cell.minY, p.Y - s.Y / 2)
            cell.maxY = math.max(cell.maxY, p.Y + s.Y / 2)
            if #cell.samples < 8 then table.insert(cell.samples, inst.Name) end

            local zone = directChildUnder(inst, mapRoot)
            if zone then
                local z = zoneStats[zone]
                if not z then z = {instance = zone, parts = {}, count = 0}; zoneStats[zone] = z end
                z.count += 1
                table.insert(z.parts, inst)
            end

            if CONFIG.INCLUDE_ALL_MAP_PARTS then
                table.insert(mapParts, {
                    n = inst.Name,
                    parent = inst.Parent and inst.Parent.Name or "",
                    p = vec3(p),
                    s = {x = round(s.X), y = round(s.Y), z = round(s.Z)},
                    material = tostring(inst.Material),
                    anchored = inst.Anchored,
                    collide = inst.CanCollide,
                    transparency = round(inst.Transparency),
                    zone = zone and zone.Name or "",
                })
            end
        end
        if index % CONFIG.YIELD_EVERY == 0 then task.wait() end
    end
end

local allMapPartsForBounds = {}
for _, inst in ipairs(mapDescendants) do
    if inst:IsA("BasePart") then table.insert(allMapPartsForBounds, inst) end
end
report.map.bounds = getPartsBounds(allMapPartsForBounds)
report.map.parts = mapParts

for zone, stat in pairs(zoneStats) do
    table.insert(report.map.zones, {
        name = zone.Name,
        class = zone.ClassName,
        path = getPath(zone),
        partCount = stat.count,
        bounds = getPartsBounds(stat.parts),
    })
end
table.sort(report.map.zones, function(a,b) return a.name < b.name end)

for key, cell in pairs(grid) do
    table.insert(report.map.grid, {
        id = key,
        gx = cell.gx,
        gz = cell.gz,
        count = cell.count,
        minY = round(cell.minY),
        maxY = round(cell.maxY),
        samples = cell.samples,
    })
end
table.sort(report.map.grid, function(a,b)
    if a.gx == b.gx then return a.gz < b.gz end
    return a.gx < b.gx
end)

-- Scan all ProximityPrompts, ClickDetectors, actors, quest boards and POIs.
local promptCount, clickCount, humanoidCount = 0, 0, 0
local oreKeys = {"Iron", "Gold", "Ruby", "Aluminium", "Lime Stone", "Refined Stone", "Frost Stone", "Ruby Crystal"}
local oreSeen = {}
local boardSeen = {}
local mapLocationFolder = mapRoot and mapRoot:FindFirstChild("Map Locations", true)

for index, inst in ipairs(allWorkspace) do
    if inst:IsA("ProximityPrompt") then
        promptCount += 1
        table.insert(report.actors.prompts, {
            name = inst.Name,
            actionText = inst.ActionText,
            objectText = inst.ObjectText,
            enabled = inst.Enabled,
            maxActivationDistance = round(inst.MaxActivationDistance),
            holdDuration = round(inst.HoldDuration),
            requiresLineOfSight = inst.RequiresLineOfSight,
            path = getPath(inst),
            position = vec3(getPosition(inst)),
        })
    elseif inst:IsA("ClickDetector") then
        clickCount += 1
        table.insert(report.actors.clickDetectors, {
            name = inst.Name,
            maxActivationDistance = round(inst.MaxActivationDistance),
            path = getPath(inst),
            position = vec3(getPosition(inst)),
        })
    end

    if inst:IsA("Model") then
        local hum = inst:FindFirstChildOfClass("Humanoid")
        if hum and not Players:GetPlayerFromCharacter(inst) then
            local root = getRootPart(inst)
            if root then
                humanoidCount += 1
                local fullPath = getPath(inst)
                local pathLower = lower(fullPath)
                local category = "HumanoidModel / review"
                if hasAny(pathLower, {"betterdialog", "questreceivers", "craftingnpcs", "world.quests", "nen.sellers", "merchantstore", "bountyappraisernpcs"}) then
                    category = "ServiceOrQuestNPC"
                elseif hasAny(inst.Name, {"boss", "stone eye", "mole rat", "crimson flame", "master of the swamp", "sandy storm", "beach king", "black blick"}) then
                    category = "BossCandidate"
                else
                    category = "MobOrNPCCandidate"
                end
                local displayText = nil
                local head = inst:FindFirstChild("Head")
                if head then
                    for _, guiObject in ipairs(head:GetDescendants()) do
                        if guiObject:IsA("TextLabel") and guiObject.Text ~= "" then
                            displayText = string.sub(guiObject.Text, 1, 120)
                            break
                        end
                    end
                end
                table.insert(report.actors.humanoids, {
                    name = inst.Name,
                    displayText = displayText,
                    category = category,
                    path = fullPath,
                    position = vec3(root.Position),
                    health = round(hum.Health),
                    maxHealth = round(hum.MaxHealth),
                    attributes = {
                        Level = safeAttribute(inst:GetAttribute("Level")),
                        Type = safeAttribute(inst:GetAttribute("Type")),
                        NPCType = safeAttribute(inst:GetAttribute("NPCType")),
                        Faction = safeAttribute(inst:GetAttribute("Faction")),
                        Boss = safeAttribute(inst:GetAttribute("Boss")),
                    },
                })
            end
        end

        if hasAny(inst.Name, {"quest board"}) and not boardSeen[inst] then
            boardSeen[inst] = true
            local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
            table.insert(report.quests.boards, {
                name = inst.Name,
                path = getPath(inst),
                position = vec3(getPosition(inst)),
                promptPath = prompt and getPath(prompt) or nil,
                missions = collectTextLabels(inst:FindFirstChild("Board") or inst, CONFIG.MAX_LABELS_PER_BOARD),
            })
        end

        if hasAny(inst.Name, {"chest", "treasure chest", "loot chest"}) then
            table.insert(report.pointsOfInterest.chests, {
                name = inst.Name, class = inst.ClassName, path = getPath(inst), position = vec3(getPosition(inst)),
            })
        end
    end

    if inst:IsA("SpawnLocation") then
        table.insert(report.pointsOfInterest.spawnLocations, {
            name = inst.Name, path = getPath(inst), position = vec3(inst.Position), teamColor = tostring(inst.TeamColor),
        })
    end

    if inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Folder") then
        local nameLower = lower(inst.Name)
        if hasAny(nameLower, {"craft", "blacksmith", "forge", "anvil"}) then
            table.insert(report.pointsOfInterest.crafting, {
                name = inst.Name, class = inst.ClassName, path = getPath(inst), position = vec3(getPosition(inst)),
            })
        end
    end

    -- Detect resource parts through the resource-named ancestor (e.g. Workspace.Iron/...small_ore...).
    if inst:IsA("BasePart") then
        local resourceAncestor = findAncestorNamed(inst, Workspace, function(candidate)
            for _, oreName in ipairs(oreKeys) do
                if lower(candidate.Name) == lower(oreName) then return true end
            end
            return false
        end)
        if resourceAncestor then
            local key = getPath(inst)
            if not oreSeen[key] then
                oreSeen[key] = true
                table.insert(report.resources.ores, {
                    resource = resourceAncestor.Name,
                    part = inst.Name,
                    path = key,
                    position = vec3(inst.Position),
                    size = {x = round(inst.Size.X), y = round(inst.Size.Y), z = round(inst.Size.Z)},
                    material = tostring(inst.Material),
                    canCollide = inst.CanCollide,
                })
            end
        end
    end

    if mapLocationFolder and inst.Parent == mapLocationFolder then
        table.insert(report.pointsOfInterest.mapLocations, {
            name = inst.Name, class = inst.ClassName, path = getPath(inst), position = vec3(getPosition(inst)),
        })
    end

    if index % CONFIG.YIELD_EVERY == 0 then task.wait() end
end

-- Record map-related named structures with useful bounds, even if they have no Humanoid.
local landmarkWords = {"mine", "cave", "camp", "town", "village", "castle", "island", "forest", "beach", "volcano", "swamp", "port", "arena", "dungeon", "bridge", "zipline", "quest board"}
for _, inst in ipairs(mapDescendants) do
    if (inst:IsA("Model") or inst:IsA("Folder")) and hasAny(inst.Name, landmarkWords) then
        local parts = {}
        for _, child in ipairs(inst:GetDescendants()) do
            if child:IsA("BasePart") then table.insert(parts, child) end
        end
        table.insert(report.pointsOfInterest.namedLandmarks, {
            name = inst.Name,
            class = inst.ClassName,
            path = getPath(inst),
            partCount = #parts,
            bounds = getPartsBounds(parts),
        })
    end
end

-- Record CollectionService tags and representative instance paths.
for _, tag in ipairs(CollectionService:GetAllTags()) do
    local tagged = CollectionService:GetTagged(tag)
    local examples = {}
    for i = 1, math.min(#tagged, CONFIG.MAX_TAG_EXAMPLES) do
        table.insert(examples, getPath(tagged[i]))
    end
    table.insert(report.tags, {name = tag, count = #tagged, examples = examples})
end
table.sort(report.tags, function(a,b) return a.name < b.name end)

-- Scan game architecture metadata (names/paths only; never reads source or fires remotes).
local serviceNames = {
    "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui",
    "StarterPack", "StarterPlayer", "Teams", "Lighting", "SoundService",
    "TextChatService", "Workspace",
}
local systemWords = {
    "quest", "mission", "mining", "mine", "ore", "craft", "blacksmith",
    "stat", "skill", "inventory", "chest", "combat", "weapon", "drop",
    "loot", "equip", "enemy", "npc", "boss", "ability", "hatsu",
}
local remoteCount, scriptCount, moduleCount, systemCandidateCount = 0, 0, 0, 0
local scannedServices = {}
for _, serviceName in ipairs(serviceNames) do
    local ok, service = pcall(function() return game:GetService(serviceName) end)
    if ok and service then
        local descendants = service:GetDescendants()
        local classCounts = {}
        for _, inst in ipairs(descendants) do
            classCounts[inst.ClassName] = (classCounts[inst.ClassName] or 0) + 1
            local path = getPath(inst)
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
                remoteCount += 1
                table.insert(report.architecture.remoteEndpoints, {
                    name = inst.Name, class = inst.ClassName, path = path,
                    note = "Metadata only. The scanner does not invoke this endpoint.",
                })
            elseif inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
                table.insert(report.architecture.remoteEndpoints, {
                    name = inst.Name, class = inst.ClassName, path = path,
                    note = "Bindable endpoint metadata only; not invoked.",
                })
            end
            if inst:IsA("Script") or inst:IsA("LocalScript") then
                scriptCount += 1
                local disabled = nil
                pcall(function() disabled = inst.Disabled end)
                table.insert(report.architecture.scripts, {
                    name = inst.Name, class = inst.ClassName, path = path, disabled = disabled,
                })
            elseif inst:IsA("ModuleScript") then
                moduleCount += 1
                table.insert(report.architecture.scripts, {
                    name = inst.Name, class = inst.ClassName, path = path,
                })
            end
            if hasAny(inst.Name, systemWords) and (serviceName ~= "Workspace" or inst:IsDescendantOf(world or Workspace)) then
                systemCandidateCount += 1
                if #report.architecture.systemCandidates < 3000 then
                    table.insert(report.architecture.systemCandidates, {
                        name = inst.Name, class = inst.ClassName, path = path,
                    })
                end
            end
        end
        table.insert(report.architecture.services, {
            name = serviceName,
            class = service.ClassName,
            descendantCount = #descendants,
            classCounts = classCounts,
        })
        scannedServices[serviceName] = true
    end
end

table.sort(report.architecture.remoteEndpoints, function(a,b) return a.path < b.path end)
table.sort(report.architecture.scripts, function(a,b) return a.path < b.path end)
table.sort(report.architecture.systemCandidates, function(a,b) return a.path < b.path end)

-- Build summary after all scans.
report.summary = {
    workspaceDescendants = #allWorkspace,
    mapRootFound = mapRoot ~= nil,
    mapPartCount = mapPartCount,
    mapZoneCount = #report.map.zones,
    spatialGridCellCount = #report.map.grid,
    humanoidModelCount = humanoidCount,
    proximityPromptCount = promptCount,
    clickDetectorCount = clickCount,
    questBoardCount = #report.quests.boards,
    orePartCount = #report.resources.ores,
    mapLocationCount = #report.pointsOfInterest.mapLocations,
    craftingCandidateCount = #report.pointsOfInterest.crafting,
    chestCandidateCount = #report.pointsOfInterest.chests,
    spawnLocationCount = #report.pointsOfInterest.spawnLocations,
    namedLandmarkCount = #report.pointsOfInterest.namedLandmarks,
    collectionServiceTagCount = #report.tags,
    serviceCount = #report.architecture.services,
    remoteEndpointCount = #report.architecture.remoteEndpoints,
    scriptAndModuleCount = #report.architecture.scripts,
    systemCandidateCount = systemCandidateCount,
}

table.sort(report.actors.humanoids, function(a,b) return a.name < b.name end)
table.sort(report.actors.prompts, function(a,b) return a.path < b.path end)
table.sort(report.actors.clickDetectors, function(a,b) return a.path < b.path end)
table.sort(report.quests.boards, function(a,b) return a.name < b.name end)
table.sort(report.resources.ores, function(a,b) return a.path < b.path end)
table.sort(report.pointsOfInterest.mapLocations, function(a,b) return a.name < b.name end)
table.sort(report.pointsOfInterest.crafting, function(a,b) return a.path < b.path end)
table.sort(report.pointsOfInterest.chests, function(a,b) return a.path < b.path end)
table.sort(report.pointsOfInterest.namedLandmarks, function(a,b) return a.path < b.path end)

-- Create persistent report under ServerStorage.
local outputName = "BeyondNenWorldScan"
local output = ServerStorage:FindFirstChild(outputName)
if output then output:Destroy() end
output = Instance.new("Folder")
output.Name = outputName
output.Parent = ServerStorage

local summaryLines = {
    "BEYOND NEN WORLD SCAN v1.0",
    "PlaceId: " .. tostring(game.PlaceId),
    "Scanned UTC: " .. report.meta.scannedAtUTC,
    "Workspace descendants: " .. tostring(report.summary.workspaceDescendants),
    "Map root found: " .. tostring(report.summary.mapRootFound),
    "Map BaseParts: " .. tostring(report.summary.mapPartCount),
    "Map zones: " .. tostring(report.summary.mapZoneCount),
    "Grid cells (" .. tostring(CONFIG.CELL_SIZE) .. " studs): " .. tostring(report.summary.spatialGridCellCount),
    "Humanoid models: " .. tostring(report.summary.humanoidModelCount),
    "ProximityPrompts: " .. tostring(report.summary.proximityPromptCount),
    "ClickDetectors: " .. tostring(report.summary.clickDetectorCount),
    "Quest boards: " .. tostring(report.summary.questBoardCount),
    "Ore parts: " .. tostring(report.summary.orePartCount),
    "Map locations: " .. tostring(report.summary.mapLocationCount),
    "Crafting candidates: " .. tostring(report.summary.craftingCandidateCount),
    "Chest candidates: " .. tostring(report.summary.chestCandidateCount),
    "SpawnLocations: " .. tostring(report.summary.spawnLocationCount),
    "Named landmarks: " .. tostring(report.summary.namedLandmarkCount),
    "CollectionService tags: " .. tostring(report.summary.collectionServiceTagCount),
    "Services inspected: " .. tostring(report.summary.serviceCount),
    "Remote/Bindable endpoints indexed (not invoked): " .. tostring(report.summary.remoteEndpointCount),
    "Scripts/ModuleScripts indexed (source not read): " .. tostring(report.summary.scriptAndModuleCount),
    "System-name candidates: " .. tostring(report.summary.systemCandidateCount),
    "",
    "Open JSONChunks to copy the complete machine-readable scan.",
    "Map parts represent BaseParts under Workspace.World.Map; Terrain voxels are not expanded.",
}
local summaryValue = Instance.new("StringValue")
summaryValue.Name = "Summary"
summaryValue.Value = table.concat(summaryLines, "\n")
summaryValue.Parent = output

local function makeCategoryFolder(name, rows)
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = output
    for i, row in ipairs(rows) do
        local value = Instance.new("StringValue")
        value.Name = string.format("%04d_%s", i, string.gsub(tostring(row.name or row.resource or row.part or "Record"), "[^%w_%-]", "_"))
        value.Value = HttpService:JSONEncode(row)
        value.Parent = folder
    end
end

makeCategoryFolder("QuestBoards", report.quests.boards)
makeCategoryFolder("HumanoidModels", report.actors.humanoids)
makeCategoryFolder("ProximityPrompts", report.actors.prompts)
makeCategoryFolder("ClickDetectors", report.actors.clickDetectors)
makeCategoryFolder("OreParts", report.resources.ores)
makeCategoryFolder("MapLocations", report.pointsOfInterest.mapLocations)
makeCategoryFolder("CraftingCandidates", report.pointsOfInterest.crafting)
makeCategoryFolder("ChestCandidates", report.pointsOfInterest.chests)
makeCategoryFolder("NamedLandmarks", report.pointsOfInterest.namedLandmarks)
makeCategoryFolder("RemoteEndpoints", report.architecture.remoteEndpoints)
makeCategoryFolder("ScriptsAndModules", report.architecture.scripts)
makeCategoryFolder("GameSystemCandidates", report.architecture.systemCandidates)
makeCategoryFolder("ServiceInventory", report.architecture.services)
makeCategoryFolder("MapZones", report.map.zones)
makeCategoryFolder("SpatialGrid", report.map.grid)

local json = HttpService:JSONEncode(report)
local chunksFolder = Instance.new("Folder")
chunksFolder.Name = "JSONChunks"
chunksFolder.Parent = output
local chunkCount = math.ceil(#json / CONFIG.JSON_CHUNK_SIZE)
for i = 1, chunkCount do
    local first = (i - 1) * CONFIG.JSON_CHUNK_SIZE + 1
    local last = math.min(i * CONFIG.JSON_CHUNK_SIZE, #json)
    local chunk = Instance.new("StringValue")
    chunk.Name = string.format("Chunk_%03d", i)
    chunk.Value = string.sub(json, first, last)
    chunk.Parent = chunksFolder
end

local manifest = Instance.new("StringValue")
manifest.Name = "Manifest"
manifest.Value = HttpService:JSONEncode({
    schema = "BeyondNenWorldScan/1.1",
    jsonLength = #json,
    chunkCount = chunkCount,
    chunkSize = CONFIG.JSON_CHUNK_SIZE,
    path = "ServerStorage.BeyondNenWorldScan.JSONChunks",
})
manifest.Parent = output

print(summaryValue.Value)
print("[Beyond Nen Scanner] Full JSON length: " .. tostring(#json) .. " characters")
print("[Beyond Nen Scanner] JSON chunks created: " .. tostring(chunkCount))
print("[Beyond Nen Scanner] Report stored at ServerStorage.BeyondNenWorldScan")
print("[Beyond Nen Scanner] Read-only: no game actions or RemoteEvents were triggered; script Source was not read.")

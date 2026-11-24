-- Beyond Nen Diagnostic v0.6 - progression systems scanner (mobile/touch)
-- READ-ONLY: inspects visible UI, prompts, tools and world objects.
-- Does not attack, move, mine, craft, equip, allocate stats, open chests, or fire remotes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local old = PlayerGui:FindFirstChild("BeyondNenDiagnosticV06")
if old then old:Destroy() end

local function fullName(obj)
    local ok, value = pcall(function() return obj:GetFullName() end)
    return ok and value or (obj and obj.Name or "?")
end
local function low(s) return string.lower(tostring(s or "")) end
local function clean(s, limit)
    s = tostring(s or ""):gsub("\r", " "):gsub("\n", " / "):gsub("%s+", " ")
    limit = limit or 100
    if #s > limit then s = s:sub(1, limit) .. "…" end
    return s
end
local function rootOf(model)
    return model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart)
end
local function visible(obj)
    local p = obj
    while p do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end
local function add(lines, s) table.insert(lines, clean(s, 180)) end
local function isKeyword(name, words)
    local n = low(name)
    for _, w in ipairs(words) do if string.find(n, w, 1, true) then return true end end
    return false
end

local gui = Instance.new("ScreenGui")
gui.Name = "BeyondNenDiagnosticV06"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10002
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(430, 900)
local touch = UserInputService.TouchEnabled
local width = math.floor(math.clamp(viewport.X * (touch and 0.94 or 0.66), 310, 680))
local height = math.floor(math.clamp(viewport.Y * (touch and 0.72 or 0.72), 430, 700))
height = math.min(height, viewport.Y - 18)
local colors = {
    bg = Color3.fromRGB(17,19,25), panel = Color3.fromRGB(27,31,40), button = Color3.fromRGB(43,53,67),
    green = Color3.fromRGB(57,145,111), text = Color3.fromRGB(240,242,246), muted = Color3.fromRGB(165,174,187), red = Color3.fromRGB(158,61,67)
}
local function make(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, radius) make("UICorner", {CornerRadius=UDim.new(0,radius or 8)}, o) end

local main = make("Frame", {Name="Main", Size=UDim2.fromOffset(width,height), Position=UDim2.new(.5,-width/2,.5,-height/2), BackgroundColor3=colors.bg, BorderSizePixel=0}, gui)
round(main, 10)
make("UIStroke", {Color=colors.green,Transparency=.2,Thickness=1.2}, main)
local top = make("Frame", {Size=UDim2.new(1,0,0,42),BackgroundColor3=colors.panel,BorderSizePixel=0}, main)
round(top,10)
make("TextLabel", {BackgroundTransparency=1,Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-90,1,0),Font=Enum.Font.GothamBold,Text="BEYOND NEN / DIAGNOSTIC v0.6",TextColor3=colors.text,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd}, top)
local minimized=false
local fullSize=main.Size
local minBtn=make("TextButton", {Position=UDim2.new(1,-76,0,6),Size=UDim2.fromOffset(30,30),BackgroundColor3=colors.button,BorderSizePixel=0,Text="−",TextColor3=colors.text,Font=Enum.Font.GothamBold,TextSize=20}, top); round(minBtn,7)
local closeBtn=make("TextButton", {Position=UDim2.new(1,-40,0,6),Size=UDim2.fromOffset(30,30),BackgroundColor3=colors.red,BorderSizePixel=0,Text="×",TextColor3=colors.text,Font=Enum.Font.GothamBold,TextSize=19}, top); round(closeBtn,7)

local buttonsFrame = make("ScrollingFrame", {Position=UDim2.fromOffset(8,49),Size=UDim2.new(1,-16,0,88),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new()}, main)
local grid = make("UIGridLayout", {CellSize=UDim2.new(0, math.floor((width-42)/3),0,34),CellPadding=UDim2.fromOffset(5,5),SortOrder=Enum.SortOrder.LayoutOrder}, buttonsFrame)
local output = make("TextBox", {Name="Report",Position=UDim2.fromOffset(8,143),Size=UDim2.new(1,-16,1,-178),BackgroundColor3=colors.panel,BorderSizePixel=0,ClearTextOnFocus=false,MultiLine=true,TextEditable=true,TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Code,TextSize=10,TextColor3=colors.text,Text="Open M > Inventory, Stats and Skill Tree, then press the matching scan button.\nFor mining/crafting/chests, stand near the object or open the interface first.\nRead-only scan: no game actions are sent."}, main)
round(output,7)
make("UIPadding", {PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)}, output)
local status = make("TextLabel", {Position=UDim2.new(0,8,1,-29),Size=UDim2.new(1,-16,0,22),BackgroundTransparency=1,Font=Enum.Font.Gotham,Text="Ready • read-only",TextColor3=colors.muted,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd}, main)

local function report(title, lines)
    local out = {"BEYOND NEN DIAGNOSTIC v0.6",title,"PlaceId: "..tostring(game.PlaceId),"Time: "..os.date("!%Y-%m-%d %H:%M:%S UTC"),"READ-ONLY / no remotes fired", ""}
    for _, line in ipairs(lines) do table.insert(out, line) end
    if #lines == 0 then table.insert(out,"No matching objects found. Open the relevant menu or move closer, then scan again.") end
    output.Text=table.concat(out,"\n")
    output.CursorPosition=1
    status.Text=title.." • "..#lines.." lines"
    print(output.Text)
end

local function allRoots()
    return {PlayerGui, Workspace}
end
local function scanGui(category, terms)
    local lines={"Scan category: "..category,"Open the relevant M menu or dialog before scanning.","", "RELEVANT GUI ROOTS / TEXT / BUTTONS:"}
    local roots, textCount, buttonCount = 0,0,0
    for _, root in ipairs(allRoots()) do
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ScreenGui") or obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
                if isKeyword(obj.Name, terms) and visible(obj) then
                    roots+=1
                    if roots<=25 then add(lines,"GUI ROOT "..obj.ClassName.." | "..fullName(obj)) end
                end
            end
            if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and visible(obj) then
                local match = isKeyword(obj.Name, terms) or isKeyword(obj.Text, terms)
                if match then
                    textCount+=1
                    if obj:IsA("TextButton") then buttonCount+=1 end
                    if textCount<=65 then
                        add(lines,string.format("%s [%s] = %s",obj:IsA("TextButton") and "BUTTON" or "TEXT",obj.ClassName, obj.Text))
                        add(lines,"  Path: "..fullName(obj))
                        if obj:IsA("GuiObject") then add(lines,"  Visible="..tostring(obj.Visible).." Active="..tostring(obj.Active).."") end
                    end
                end
            end
        end
    end
    table.insert(lines,"")
    add(lines,"Summary: matching gui roots="..roots..", text="..textCount..", buttons="..buttonCount)
    report(string.upper(category).." UI SCAN",lines)
end

local function scanMining()
    local terms={"ore","crystal","rock","mineral","vein","node","mine","mining","frost","iron","aluminum","aluminium","limestone","pickaxe"}
    local lines={"World mining candidates; nearest first.","Look for BaseParts/Models plus ProximityPrompt or ClickDetector.",""}
    local myRoot=rootOf(LocalPlayer.Character)
    local candidates={}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            if isKeyword(obj.Name,terms) then
                local part=obj:IsA("BasePart") and obj or rootOf(obj) or obj:FindFirstChildWhichIsA("BasePart",true)
                local d=(myRoot and part) and (part.Position-myRoot.Position).Magnitude or math.huge
                local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true)
                local click=obj:FindFirstChildWhichIsA("ClickDetector",true)
                table.insert(candidates,{obj=obj,part=part,d=d,prompt=prompt,click=click})
            end
        end
    end
    table.sort(candidates,function(a,b) return a.d<b.d end)
    add(lines,"Candidate count="..#candidates)
    for i=1,math.min(45,#candidates) do
        local e=candidates[i]
        local d=e.d==math.huge and "unknown" or (math.floor(e.d).." studs")
        add(lines,string.format("%02d) %s | %s | %s",i,e.obj.Name,d,e.obj.ClassName))
        add(lines,"  Path: "..fullName(e.obj))
        if e.part then add(lines,"  Pos: "..tostring(e.part.Position)) end
        if e.prompt then add(lines,"  Prompt: "..e.prompt.ActionText.." / "..e.prompt.ObjectText.." | Enabled="..tostring(e.prompt.Enabled).." | Max="..tostring(e.prompt.MaxActivationDistance).." | "..fullName(e.prompt)) end
        if e.click then add(lines,"  ClickDetector MaxActivationDistance="..tostring(e.click.MaxActivationDistance).." | "..fullName(e.click)) end
    end
    report("MINING / ORE SCAN",lines)
end

local function scanPromptsAndChests()
    local lines={"Nearby chest / ore / craft prompts; nearest first."}
    local me=rootOf(LocalPlayer.Character)
    local terms={"chest","crate","open","mine","ore","craft","blacksmith","smith","equip","interact","claim"}
    local found={}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent=obj.Parent
            local part=parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart",true))
            local dist=(me and part) and (part.Position-me.Position).Magnitude or math.huge
            local related=isKeyword(obj.Name,terms) or isKeyword(obj.ActionText,terms) or isKeyword(obj.ObjectText,terms) or isKeyword(fullName(obj),terms)
            if related then table.insert(found,{p=obj,d=dist}) end
        end
    end
    table.sort(found,function(a,b) return a.d<b.d end)
    for i=1,math.min(60,#found) do
        local e=found[i]; local p=e.p
        add(lines,string.format("%02d) %s | %s | Enabled=%s | Max=%.1f",i,p.ActionText,p.ObjectText,tostring(p.Enabled),p.MaxActivationDistance))
        add(lines,"  Path: "..fullName(p))
    end
    if #found==0 then add(lines,"No chest/mining/crafting-related ProximityPrompts found. Try opening the chest or standing beside it.") end
    report("CHEST / CRAFT / INTERACTION PROMPT SCAN",lines)
end

local function scanTools()
    local lines={"Equipped tools and backpack tools. Names, attributes, and visible Value objects only."}
    local locations={LocalPlayer.Character,LocalPlayer:FindFirstChildOfClass("Backpack")}
    local count=0
    for _, container in ipairs(locations) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    count+=1; add(lines,"TOOL "..tool.Name.." | Equipped="..tostring(tool.Parent==LocalPlayer.Character).." | Path="..fullName(tool))
                    local attrs=tool:GetAttributes()
                    for k,v in pairs(attrs) do add(lines,"  Attribute "..tostring(k).."="..tostring(v)) end
                    for _, child in ipairs(tool:GetDescendants()) do
                        if child:IsA("ValueBase") then add(lines,"  Value "..child.Name.."="..tostring(child.Value)) end
                    end
                end
            end
        end
    end
    if count==0 then add(lines,"No Tools found in Character or Backpack.") end
    report("TOOLS / EQUIPMENT SCAN",lines)
end

local function scanWorldObjects()
    local lines={"World objects likely tied to mining, chests, crafting or loot.",""}
    local words={"chest","crate","ore","crystal","mineral","rock","mine","mining","blacksmith","craft","anvil","recipe","schematic","pickaxe","talent","skilltree","skill tree"}
    local found={}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Folder")) and isKeyword(obj.Name,words) then
            table.insert(found,obj)
        end
    end
    add(lines,"Matching objects="..#found)
    local me=rootOf(LocalPlayer.Character)
    table.sort(found,function(a,b)
        local function dist(x)
            local p=x:IsA("BasePart") and x or rootOf(x) or x:FindFirstChildWhichIsA("BasePart",true)
            return (me and p) and (p.Position-me.Position).Magnitude or math.huge
        end
        return dist(a)<dist(b)
    end)
    for i=1,math.min(80,#found) do add(lines,string.format("%02d) %s [%s]",i,found[i].Name,found[i].ClassName)); add(lines,"  Path: "..fullName(found[i])) end
    report("WORLD OBJECT SCAN",lines)
end

local function scanStatsTree()
    scanGui("Stats / Skill Tree",{"stats","stat","strength","durability","nen","weapon","stamina","skill","talent","ability","mastery","tree","upgrade","point","affinity","technique"})
end
local function scanInventoryCraft()
    scanGui("Inventory / Crafting",{"inventory","item","equip","equipment","weapon","armor","accessory","level","requirement","craft","blacksmith","recipe","schematic","material","jenny","quantity","owned"})
end
local function scanChestsUI()
    scanGui("Chest UI",{"chest","crate","open","claim","reward","key","legendary","extraordinary","mythical","rare"})
end

local function addButton(label, callback, order)
    local b=make("TextButton",{LayoutOrder=order,BackgroundColor3=colors.button,BorderSizePixel=0,Font=Enum.Font.GothamSemibold,Text=label,TextColor3=colors.text,TextSize=10,AutoButtonColor=true},buttonsFrame)
    round(b,6)
    b.Activated:Connect(function()
        local ok,err=pcall(callback)
        if not ok then status.Text="Scan error: "..tostring(err); status.TextColor3=colors.red end
    end)
end
addButton("MINING",scanMining,1)
addButton("CHESTS",scanChestsUI,2)
addButton("PROMPTS",scanPromptsAndChests,3)
addButton("INVENTORY",scanInventoryCraft,4)
addButton("TOOLS",scanTools,5)
addButton("STATS / TREE",scanStatsTree,6)
addButton("WORLD OBJECTS",scanWorldObjects,7)
addButton("COPY",function()
    local copied=false
    if typeof(setclipboard)=="function" then
        local ok=pcall(setclipboard,output.Text)
        copied=ok
    end
    status.Text=copied and "Report copied to clipboard" or "Select the report text and copy manually"
end,8)

grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    buttonsFrame.CanvasSize=UDim2.fromOffset(0,grid.AbsoluteContentSize.Y+4)
end)
minBtn.Activated:Connect(function()
    minimized=not minimized
    buttonsFrame.Visible=not minimized
    output.Visible=not minimized
    status.Visible=not minimized
    main.Size=minimized and UDim2.fromOffset(width,42) or fullSize
    minBtn.Text=minimized and "+" or "−"
end)
closeBtn.Activated:Connect(function() gui:Destroy() end)

print("[Beyond Nen Diagnostic v0.6] Loaded. Open M menus or stand near world objects, then scan.")

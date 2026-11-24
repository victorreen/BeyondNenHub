-- Beyond Nen Ultimate Hub v0.2 - Delta-oriented Luau build
-- No hidden downloads, webhooks, file access, credential collection, or remote code execution.
-- Current features: Player/NPC/Boss ESP, target scan, local waypoint/teleports, movement toggles.
-- Auto Farm/Quest/Boss/Parry are intentionally not implemented until game APIs are verified.
-- Client-side movement may be rejected by the server and may violate game rules.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
if not LP then return end

-- Use the standard PlayerGui so the UI does not depend on executor-only APIs.
local parent = LP:WaitForChild("PlayerGui")
local connections = {}
local function bind(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local old = parent:FindFirstChild("BeyondNenUltimateHub")
if old then old:Destroy() end

local C = {
    bg = Color3.fromRGB(17,19,25), panel = Color3.fromRGB(25,29,37), panel2 = Color3.fromRGB(34,39,49),
    accent = Color3.fromRGB(116,221,169), green = Color3.fromRGB(64,166,126),
    text = Color3.fromRGB(238,241,245), muted = Color3.fromRGB(157,165,178), red = Color3.fromRGB(170,65,72),
}
local function new(class, props, par)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do o[k] = v end
    o.Parent = par
    return o
end
local function corner(o, radius) new("UICorner", {CornerRadius=UDim.new(0,radius or 8)}, o) end

local camera = Workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(1280,720)
local windowW = math.max(320, math.min(620, viewport.X - 24))
local windowH = math.max(300, math.min(430, viewport.Y - 70))
local compact = windowW < 500
local sidebarW = compact and 105 or 138

local gui = new("ScreenGui", {Name="BeyondNenUltimateHub", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, parent)
local main = new("Frame", {Size=UDim2.fromOffset(windowW,windowH), AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), BackgroundColor3=C.bg, BorderSizePixel=0}, gui)
corner(main,12)
new("UIStroke", {Color=C.green, Transparency=.25, Thickness=1.2}, main)
local top = new("Frame", {Size=UDim2.new(1,0,0,42), BackgroundColor3=C.panel, BorderSizePixel=0}, main)
corner(top,12)
new("TextLabel", {BackgroundTransparency=1, Position=UDim2.fromOffset(14,0), Size=UDim2.new(1,-70,1,0), Font=Enum.Font.GothamBold, Text="BEYOND NEN  /  ULTIMATE HUB  v0.2", TextColor3=C.text, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}, top)
local close = new("TextButton", {Position=UDim2.new(1,-40,0,7), Size=UDim2.fromOffset(30,28), BackgroundColor3=C.red, Text="×", TextColor3=C.text, Font=Enum.Font.GothamBold, TextSize=20, BorderSizePixel=0}, top)
corner(close,7)

-- Drag window
local drag, dragStart, startPos, dragInput
 bind(top.InputBegan,function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        drag, dragStart, startPos = true, input.Position, main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then drag=false end end)
    end
end)
bind(top.InputChanged,function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput=input end
end)
bind(UIS.InputChanged,function(input)
    if drag and input == dragInput then
        local d=input.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

local sidebar = new("Frame", {Position=UDim2.fromOffset(10,52), Size=UDim2.new(0,sidebarW,1,-62), BackgroundColor3=C.panel, BorderSizePixel=0}, main)
corner(sidebar,8)
new("UIPadding", {PaddingTop=UDim.new(0,9), PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8)}, sidebar)
new("UIListLayout", {Padding=UDim.new(0,7), SortOrder=Enum.SortOrder.LayoutOrder}, sidebar)
local content = new("ScrollingFrame", {Position=UDim2.fromOffset(sidebarW+20,52), Size=UDim2.new(1,-(sidebarW+30),1,-91), BackgroundColor3=C.panel, BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=C.green, AutomaticCanvasSize=Enum.AutomaticSize.Y, CanvasSize=UDim2.new()}, main)
corner(content,8)
new("UIPadding", {PaddingTop=UDim.new(0,11),PaddingBottom=UDim.new(0,11),PaddingLeft=UDim.new(0,11),PaddingRight=UDim.new(0,11)}, content)
local list = new("UIListLayout", {Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder}, content)
local status = new("TextLabel", {Position=UDim2.new(0,sidebarW+21,1,-33), Size=UDim2.new(1,-(sidebarW+32),0,23), BackgroundTransparency=1, Font=Enum.Font.Gotham, Text="Ready", TextColor3=C.muted, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left}, main)
local function say(t, color) status.Text=t; status.TextColor3=color or C.muted end

local function clear()
    for _,v in ipairs(content:GetChildren()) do
        if v ~= list and not v:IsA("UIPadding") then v:Destroy() end
    end
end
local function section(title, desc)
    local h=new("Frame", {Size=UDim2.new(1,-3,0,desc and 58 or 34), BackgroundColor3=C.panel2, BorderSizePixel=0}, content); corner(h,7)
    new("UIPadding", {PaddingTop=UDim.new(0,7),PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)}, h)
    new("TextLabel", {Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Font=Enum.Font.GothamBold,Text=title,TextColor3=C.accent,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left},h)
    if desc then new("TextLabel", {Position=UDim2.fromOffset(0,21),Size=UDim2.new(1,0,0,31),BackgroundTransparency=1,Font=Enum.Font.Gotham,Text=desc,TextColor3=C.muted,TextSize=10,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},h) end
end
local function button(title, callback, color)
    local b=new("TextButton", {Size=UDim2.new(1,-3,0,33),BackgroundColor3=color or C.panel2,BorderSizePixel=0,Font=Enum.Font.GothamSemibold,Text=title,TextColor3=C.text,TextSize=11,AutoButtonColor=true},content); corner(b,7)
    b.Activated:Connect(function() local ok,e=pcall(callback); if not ok then warn(e); say("Error: "..tostring(e),C.red) end end)
    return b
end
local function toggle(title, initial, callback)
    local value = initial == true
    local b = new("TextButton", {
        Size = UDim2.new(1,-3,0,33), BackgroundColor3 = C.panel2,
        BorderSizePixel = 0, Font = Enum.Font.GothamSemibold,
        TextColor3 = C.text, TextSize = 11, AutoButtonColor = true,
    }, content)
    corner(b,7)
    local function refresh()
        b.Text = title .. (value and "     [ON]" or "     [OFF]")
        b.BackgroundColor3 = value and C.green or C.panel2
    end
    b.Activated:Connect(function()
        value = not value
        refresh()
        local ok, err = pcall(callback, value)
        if not ok then
            warn("[Beyond Nen Hub] Toggle error: " .. tostring(err))
            say("Toggle error", C.red)
        end
    end)
    refresh()
    return function() return value end
end

local function rootOf(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end
local function humOf(model) return model and model:FindFirstChildOfClass("Humanoid") end
local function playerChar(model)
    for _,p in ipairs(Players:GetPlayers()) do if p.Character==model then return true end end
    return false
end
local function isNpc(model)
    return model and model:IsA("Model") and not playerChar(model) and humOf(model) and humOf(model).Health>0 and rootOf(model)
end
local function bossName(name)
    name=string.lower(name or "")
    return string.find(name,"boss",1,true) or string.find(name,"chief",1,true) or string.find(name,"leader",1,true)
end
local function npcs()
    local out={}
    for _,obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("Model") and isNpc(obj) then table.insert(out,obj) end end
    return out
end
local function nearestNpc(bossOnly)
    local me=rootOf(LP.Character); if not me then return nil end
    local best,dist=nil,math.huge
    for _,m in ipairs(npcs()) do
        if not bossOnly or bossName(m.Name) then
            local r=rootOf(m); local d=r and (r.Position-me.Position).Magnitude
            if d and d<dist then best,dist=m,d end
        end
    end
    return best,dist
end
local function teleport(part, name)
    local me=rootOf(LP.Character)
    if not me or not part then say("Character/target not found",C.red); return end
    me.CFrame=part.CFrame*CFrame.new(0,0,5)
    say("Moved locally near "..(name or "target").."; server may correct it",C.accent)
end

-- ESP
local pEsp, nEsp=false,false
local esp={}
local function removeEsp(model)
    local data=esp[model]; if data then if data.h then data.h:Destroy() end; if data.b then data.b:Destroy() end; esp[model]=nil end
end
local function clearEsp(kind)
    for model,data in pairs(esp) do if not kind or data.kind==kind then removeEsp(model) end end
end
local function addEsp(model, kind, color)
    if esp[model] or not model.Parent then return end
    local adornee=model:FindFirstChild("Head") or rootOf(model) or model.PrimaryPart
    if not adornee then return end
    local h=new("Highlight", {Adornee=model,FillColor=color,OutlineColor=color,FillTransparency=.8,OutlineTransparency=.12,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},Workspace)
    local b=new("BillboardGui", {Adornee=adornee,Size=UDim2.fromOffset(185,25),StudsOffset=Vector3.new(0,2.8,0),AlwaysOnTop=true},parent)
    local t=new("TextLabel", {Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextColor3=color,TextStrokeTransparency=.3,TextSize=10,Text=kind.."  "..model.Name},b)
    esp[model]={h=h,b=b,t=t,kind=kind}
end
task.spawn(function()
    while gui.Parent do
        pcall(function()
            if pEsp then
                for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then addEsp(p.Character,"PLAYER",Color3.fromRGB(100,190,255)) end end
            else clearEsp("PLAYER") end
            if nEsp then
                local shown = 0
                for _,m in ipairs(npcs()) do
                    if shown >= 60 then break end -- cap overlays to reduce client load
                    local kind = bossName(m.Name) and "BOSS" or "NPC"
                    addEsp(m,kind,kind=="BOSS" and Color3.fromRGB(255,105,95) or Color3.fromRGB(255,205,100))
                    shown += 1
                end
            else clearEsp("NPC"); clearEsp("BOSS") end
            local me=rootOf(LP.Character)
            for model,data in pairs(esp) do
                if not model.Parent then removeEsp(model) else
                    local r=rootOf(model); if me and r and data.t then data.t.Text=data.kind.."  "..model.Name.."  •  "..math.floor((r.Position-me.Position).Magnitude).."m" end
                end
            end
        end)
        task.wait(1.5)
    end
end)

-- Movement toggles
local speedOn,jumpOn,noclipOn=false,false,false
local oldSpeed,oldJump=nil,nil
local oldCollision={}
bind(RunService.Stepped,function()
    if noclipOn and LP.Character then
        for _,part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") then if oldCollision[part]==nil then oldCollision[part]=part.CanCollide end; part.CanCollide=false end
        end
    end
end)
local function restoreNoclip()
    for part,value in pairs(oldCollision) do if part and part.Parent then part.CanCollide=value end end
    table.clear(oldCollision)
end

local savedPoint=nil
local function page(name)
    clear()
    if name=="Home" then
        section("Welcome, "..LP.Name,"Clean client-side hub. No external loader, HTTP request or hidden dependency.")
        section("Working now","Player ESP • NPC/Boss ESP • target scanning • local teleports • waypoint • movement toggles.")
        section("Integration pending","Auto Farm, Auto Quest, Auto Boss and Auto Parry need the game's real combat/quest interface. I won't invent remote names.")
        button("Scan nearest NPC",function() local m,d=nearestNpc(false); say(m and (m.Name.." • "..math.floor(d).."m") or "No NPC detected",m and C.accent or C.muted) end)
        button("Scan nearest possible Boss",function() local m,d=nearestNpc(true); say(m and (m.Name.." • "..math.floor(d).."m") or "No Boss/Chief/Leader name match",m and C.accent or C.muted) end)
    elseif name=="ESP" then
        section("Visuals","ESP is client-side. NPC detection looks for models containing a living Humanoid and root part.")
        toggle("Player ESP",pEsp,function(v) pEsp=v; if not v then clearEsp("PLAYER") end; say("Player ESP "..(v and "ON" or "OFF")) end)
        toggle("NPC / Boss ESP",nEsp,function(v) nEsp=v; if not v then clearEsp("NPC"); clearEsp("BOSS") end; say("NPC/Boss ESP "..(v and "ON" or "OFF")) end)
        button("Clear all ESP",function() pEsp=false;nEsp=false;clearEsp();say("ESP cleared") end,C.red)
    elseif name=="Teleport" then
        section("Local teleport","CFrame movement can be rolled back or detected by server-side checks.")
        button("Teleport near nearest NPC",function() local m=nearestNpc(false); teleport(m and rootOf(m),m and m.Name) end)
        button("Teleport near nearest possible Boss",function() local m=nearestNpc(true); teleport(m and rootOf(m),m and m.Name) end)
        button("Teleport near nearest player",function()
            local me=rootOf(LP.Character); if not me then return end
            local best,dist=nil,math.huge
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP then local r=rootOf(p.Character); if r then local d=(r.Position-me.Position).Magnitude; if d<dist then best,dist=r,d end end end end
            teleport(best,"player")
        end)
        button("Save current position",function() local r=rootOf(LP.Character); if r then savedPoint=r.CFrame;say("Waypoint saved",C.accent) end end)
        button("Return to saved position",function() local r=rootOf(LP.Character); if r and savedPoint then r.CFrame=savedPoint;say("Returned to local waypoint",C.accent) else say("No waypoint saved") end end)
    elseif name=="Farm" then
        section("Target finder","Target selection only for now; no automatic attacks are sent.")
        button("Find nearest mob",function() local m,d=nearestNpc(false); say(m and ("Target: "..m.Name.." • "..math.floor(d).."m") or "No mob detected") end)
        button("Find nearest boss",function() local m,d=nearestNpc(true); say(m and ("Target: "..m.Name.." • "..math.floor(d).."m") or "No boss-name match") end)
        section("Not connected yet","Auto Farm • Mob Farm • Boss Farm • Kill Aura • Auto Skills • Auto Parry")
    elseif name=="Quests" then
        section("Quest helper","The public game description mentions Hunter missions and the Hunter Exam. Live board interaction is not mapped yet.")
        button("Search Workspace for quest/mission objects",function()
            local found={}
            for _,o in ipairs(Workspace:GetDescendants()) do local n=string.lower(o.Name); if string.find(n,"quest",1,true) or string.find(n,"mission",1,true) then table.insert(found,o:GetFullName()); if #found>=6 then break end end end
            say(#found>0 and table.concat(found," | ") or "No obvious quest objects found")
        end)
        section("Not connected yet","Auto Quest • Auto Claim • Auto Exam • Auto Board Selection")
    elseif name=="Movement" then
        section("Movement helpers","Client-side values may reset. Restore them before closing the hub.")
        toggle("WalkSpeed boost (24)",speedOn,function(v)
            speedOn=v; local h=humOf(LP.Character); if h then if v then oldSpeed=oldSpeed or h.WalkSpeed; h.WalkSpeed=24 elseif oldSpeed then h.WalkSpeed=oldSpeed;oldSpeed=nil end end; say("WalkSpeed "..(v and "boosted" or "restored"))
        end)
        toggle("JumpPower boost (60)",jumpOn,function(v)
            jumpOn=v; local h=humOf(LP.Character); if h then if v then oldJump=oldJump or h.JumpPower; h.UseJumpPower=true;h.JumpPower=60 elseif oldJump then h.JumpPower=oldJump;oldJump=nil end end; say("JumpPower "..(v and "boosted" or "restored"))
        end)
        toggle("Noclip",noclipOn,function(v) noclipOn=v; if not v then restoreNoclip() end; say("Noclip "..(v and "ON" or "OFF")) end)
        button("Restore movement",function()
            speedOn=false;jumpOn=false;noclipOn=false
            local h=humOf(LP.Character);if h then if oldSpeed then h.WalkSpeed=oldSpeed end;if oldJump then h.JumpPower=oldJump end end
            oldSpeed=nil;oldJump=nil;restoreNoclip();say("Movement restored");page("Movement")
        end,C.red)
    end
end

local tabs={"Home","ESP","Teleport","Farm","Quests","Movement"}
for i,name in ipairs(tabs) do
    local b=new("TextButton", {Size=UDim2.new(1,0,0,33),BackgroundColor3=i==1 and C.green or C.panel2,BorderSizePixel=0,Font=Enum.Font.GothamSemibold,Text=name,TextColor3=C.text,TextSize=11,LayoutOrder=i},sidebar); corner(b,7)
    b.Activated:Connect(function()
        for _,x in ipairs(sidebar:GetChildren()) do if x:IsA("TextButton") then x.BackgroundColor3=C.panel2 end end
        b.BackgroundColor3=C.green;page(name)
    end)
end
local closed = false
local function cleanup()
    if closed then return end
    closed = true
    pEsp=false; nEsp=false; noclipOn=false
    clearEsp()
    restoreNoclip()
    local h=humOf(LP.Character)
    if h then
        if oldSpeed then h.WalkSpeed=oldSpeed end
        if oldJump then h.JumpPower=oldJump end
    end
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    gui:Destroy()
end
bind(close.Activated, cleanup)

page("Home")
say("Loaded • clean client script",C.accent)
print("[Beyond Nen Ultimate Hub] v0.2 loaded; no external code was downloaded")

-- ========================================================================
-- [[ LOUIS HUB - TIME BOMB DUELS FUNCTIONAL PREMIUM EDITION (INTEGRATED) ]]
-- ========================================================================

-- Definisi makro untuk kompatibilitas lokal sebelum diobfuscate
local LPH_NO_VIRTUALIZE = LPH_NO_VIRTUALIZE or function(f) return f end

-- 1. LOAD UI LIBRARY FROM YOUR SOURCE
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/nazumirui5-oss/Ui-Library/refs/heads/main/Ui%20Library.lua"))()

-- 2. SETUP MAIN ROBLOX SERVICES
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ========================================================
-- [[ INTERNAL STATE & TBD GLOBALS CONFIGURATION ]]
-- ========================================================
_G.FollowEnabled = false
_G.FollowActive = false -- Variabel baru untuk status pelacakan aktif
_G.PredictEnabled = false 
_G.HJEnabled = false 
_G.FaceClassic = false 
_G.FacePro = false 
_G.FlickEnabled = false 
_G.FlickActive = false
_G.FlickStrength = 45
_G.AutoJumpEnabled = false
_G.WallHopDist = 2.5 
_G.WHNormal = true 
_G.WHInstant = false
_G.PotatoEnabled = false

-- FITUR BARU NON-PREMIUM GLOBALS
_G.FOVEnabled = false
_G.FOVValue = 70
_G.FreezeEnabled = false

-- INFINITE JUMP STATE
_G.InfJumpEnabled = false
_G.MaxJumpCount = 5
_G.CurrentJumpCount = 0

-- AUTO HOLD BOMB STATE
_G.AutoHoldEnabled = false
_G.AutoHoldActive = false

-- ROTATING CROSSHAIR STATE
_G.CrosshairEnabled = false
_G.CurrentCrosshairStyle = 1
_G.CrosshairRotationSpeed = 110 -- Derajat per detik

-- SCREEN RESOLUTION (STRETCH RES) STATE
_G.ResolutionEnabled = false
_G.ResolutionValue = 1.00

-- GLOBAL NILAI UKURAN
_G.UIScaleValue = 100
_G.ExtScaleValue = 100

-- FITUR BARU AUTO WALK
_G.AutoWalkEnabled = false
_G.AutoWalkActive = false
_G.AutoWalkRetreatSpeed = 22

-- FITUR BARU AUTO & MANUAL PASS BOMB
_G.AutoPassEnabled = false
_G.PassTargetMode = "Without Bomb" -- Pilihan: "Without Bomb" atau "With Bomb"
_G.PassMaxDistance = 100 -- Default maksimum jarak dalam stud (1-200)
_G.PassExternalVisible = false -- Visibility eksternal tombol oper bom

-- ========================================================
-- [[ INTEGRATED NEW FEATURES STATE GLOBALS ]]
-- ========================================================
_G.RangeChaseEnabled = false
_G.RangeChaseValue = 30
_G.TripEnabled = false
_G.WallAvoidEnabled = false
_G.WallAvoidMethod = "Jump" -- "Jump" atau "Avoid"

local isHeadlessActive = false
local isKorbloxActive = false
local RangeVisualPart = nil

-- State Internal TBD
local faceSpeed = 0.18
local lockedTarget = nil 
local lastHadBomb = false
local retreatTimer = 0
local autoWalkRetreatTimer = 0
local targetMemory = 0 
local bombTimer = 0 
local isLocked = false
local canWallJump = true
local jumpDebounce = false
local isTweening = false
local lastWallHopTime = 0
local lastShouldFollow = false

-- Performance Throttling
local lastRaycastCheck = 0
local lastTargetSearch = 0
local raycastInterval = 0.1
local searchInterval = 0.25
local isVisibleCached = false

-- Camera Rotation Cache
local isSticking = false
local previewContainers = {} -- Menyimpan preview crosshair di menu untuk diputar

-- ========================================================================
-- [[ EXTERNAL UTILITY BUTTONS & SCALE ENGINE ]]
-- ========================================================================
local ExternalButtonsList = {}

local function RegisterExternalButton(btnWrapper)
    table.insert(ExternalButtonsList, btnWrapper)
end

-- Safe function to dynamically change external button sizes
local function SetButtonSize(btnWrapper, scaleValue)
    pcall(function()
        if type(btnWrapper) == "table" then
            if btnWrapper.SetSize then
                btnWrapper:SetSize(44 * scaleValue)
            elseif typeof(btnWrapper.Instance) == "Instance" then
                btnWrapper.Instance.Size = UDim2.new(0, 44 * scaleValue, 0, 44 * scaleValue)
            end
        elseif typeof(btnWrapper) == "Instance" and btnWrapper:IsA("GuiObject") then
            btnWrapper.Size = UDim2.new(0, 44 * scaleValue, 0, 44 * scaleValue)
        end
    end)
end

-- Safe function to lock/unlock dragging of external buttons
local function SetButtonDragLock(btnWrapper, locked)
    pcall(function()
        if type(btnWrapper) == "table" and btnWrapper.SetDragLock then
            btnWrapper:SetDragLock(locked)
        end
    end)
end

local function UpdateAllButtonsDragLock(locked)
    for _, btn in ipairs(ExternalButtonsList) do
        SetButtonDragLock(btn, locked)
    end
end

local function UpdateAllButtonsSize(scaleValue)
    for _, btn in ipairs(ExternalButtonsList) do
        SetButtonSize(btn, scaleValue)
    end
end

-- SAFETY WRAPPERS TO PREVENT NIL POINTER ERRORS ON LOAD
local function SafeSetVisible(btn, visible)
    if btn and type(btn) == "table" and btn.SetVisible then
        pcall(function() btn:SetVisible(visible) end)
    end
end

local function SafeSetText(btn, text)
    if btn and type(btn) == "table" and btn.SetText then
        pcall(function() btn:SetText(text) end)
    end
end

-- ========================================================
-- [[ RE-EXECUTION CLEANUP SYSTEM ]]
-- ========================================================
if _G.LouisConnections then
    for _, conn in pairs(_G.LouisConnections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
end
_G.LouisConnections = {}

local function SafeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(_G.LouisConnections, conn)
    return conn
end

if _G.LouisDrawings then
    for _, drawing in pairs(_G.LouisDrawings) do
        pcall(function() drawing:Remove() end)
    end
end
_G.LouisDrawings = {}

-- Clean up any legacy crosshair rendering
pcall(function()
    local oldCross = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("LouisHub_FREE_Crosshair")
    if oldCross then oldCross:Destroy() end
    local oldCrossPrem = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("LouisHub_Premium_Crosshair")
    if oldCrossPrem then oldCrossPrem:Destroy() end
end)

-- Clean up legacy Visual Area
pcall(function()
    local oldVisual = workspace:FindFirstChild("LouisHub_RangeVisual")
    if oldVisual then oldVisual:Destroy() end
end)

-- ========================================================
-- [[ TBD GRAPHICS & CORE HELPER FUNCTIONS ]]
-- ========================================================
local function ApplyPotato()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 250
        Lighting.Brightness = 2
        local s = settings()
        s.Rendering.QualityLevel = 1
        s.Physics.AllowSleep = true
    end)
    task.defer(function()
        local function Clean(v)
            if not v:IsA("BasePart") and not v:IsA("MeshPart") then 
                if v:IsA("Decal") or v:IsA("Texture") or v:IsA("Light") then v:Destroy()
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
                return 
            end
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
            v.Reflectance = 0
            if v:IsA("MeshPart") then v.TextureID = "" end
        end
        for _, v in ipairs(workspace:GetDescendants()) do pcall(Clean, v) end
    end)
end

local function hasBomb(p) 
    if not p.Character then return false end
    return p.Character:FindFirstChild("Bomb") or (p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Bomb")) 
end

local function getBombTime()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local cleanTxt = obj.Text:match("[%d%.]+")
            if cleanTxt then
                local num = tonumber(cleanTxt)
                if num and num > 0 and num <= 30 then
                    return num
                end
            end
        end
    end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local cleanTxt = obj.Text:match("^%d+%.?%d*$")
                if cleanTxt then
                    local num = tonumber(cleanTxt)
                    if num and num > 0 and num <= 30 then
                        return num
                    end
                end
            end
        end
    end
    return nil
end

local function isAlive(p) 
    return p and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 and p.Character:FindFirstChild("HumanoidRootPart") 
end

local function isTeammate(p)
    if not p or not p.Character then return false end
    if p.Team ~= nil and p.Team == LocalPlayer.Team then return true end
    for _, v in pairs(p.Character:GetDescendants()) do 
        if v:IsA("Highlight") and (v.FillColor.G > 0.5 or v.OutlineColor.G > 0.5) then return true end 
    end
    return false
end

local function canSeePlayerSticky(p)
    if not p.Character or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return false end
    local char = p.Character; local origin = LocalPlayer.Character.HumanoidRootPart.Position
    local params = RaycastParams.new(); params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local partsToCheck = {"Head", "HumanoidRootPart"}
    for _, partName in ipairs(partsToCheck) do
        local part = char:FindFirstChild(partName)
        if part then
            local direction = part.Position - origin
            local success, r = pcall(function() return Workspace:Raycast(origin, direction, params) end)
            if success and (not r or r.Instance:IsDescendantOf(char)) then return true end
        end
    end
    return false
end

-- ========================================================
-- [[ NEW HELPER FUNCTIONS FOR UTILITY & VISUALS ]]
-- ========================================================
local function CreateRangeVisual()
    if RangeVisualPart then pcall(function() RangeVisualPart:Destroy() end) end
    RangeVisualPart = Instance.new("Part")
    RangeVisualPart.Name = "LouisHub_RangeVisual"
    RangeVisualPart.Anchored = true
    RangeVisualPart.CanCollide = false
    RangeVisualPart.CastShadow = false
    RangeVisualPart.Material = Enum.Material.ForceField
    RangeVisualPart.Color = Color3.fromRGB(0, 255, 255)
    RangeVisualPart.Shape = Enum.PartType.Cylinder
    RangeVisualPart.Orientation = Vector3.new(0, 0, 90)
    RangeVisualPart.Transparency = 0.6
    RangeVisualPart.Parent = workspace
end

-- Sistem Trip / Fall Over (Gaya Infinite Yield dengan proteksi sentuhan)
local function ApplyTrip(state)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanTouch = not state 
        end
    end
    
    if state then
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:ChangeState(Enum.HumanoidStateType.FallingDown)
        pcall(function()
            hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(30), 0, 0)
        end)
    else
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function ApplyHeadless()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        local face = head:FindFirstChildOfClass("Decal")
        if face then face.Transparency = 1 end
        
        for _, access in ipairs(char:GetChildren()) do
            if access:IsA("Accessory") then
                local handle = access:FindFirstChild("Handle")
                if handle then
                    if handle:FindFirstChildOfClass("SpecialMesh") then
                        local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                        if mesh.MeshType == Enum.MeshType.Head or handle.Name:lower():find("head") or access.Name:lower():find("headless") then
                            handle.Transparency = 1
                        end
                    end
                end
            end
        end
    end
end

local function ApplyKorblox()
    local char = LocalPlayer.Character
    if not char then return end
    
    local rUpper = char:FindFirstChild("RightUpperLeg")
    local rLower = char:FindFirstChild("RightLowerLeg")
    local rFoot = char:FindFirstChild("RightFoot")
    
    if rUpper and rLower and rFoot then
        rUpper.Transparency = 1
        rLower.Transparency = 1
        rFoot.Transparency = 1
        
        if char:FindFirstChild("LocalKorbloxLeg") then
            char.LocalKorbloxLeg:Destroy()
        end
        
        local visualModel = Instance.new("Model", char)
        visualModel.Name = "LocalKorbloxLeg"
        
        local stick = Instance.new("Part", visualModel)
        stick.Name = "StickLeg"
        stick.Size = Vector3.new(0.3, 2.4, 0.3)
        stick.Color = Color3.fromRGB(25, 25, 25)
        stick.Material = Enum.Material.Metal
        stick.CanCollide = false
        stick.Massless = true
        
        local weld = Instance.new("WeldConstraint", stick)
        weld.Part0 = stick
        weld.Part1 = rUpper
        stick.CFrame = rUpper.CFrame * CFrame.new(0, -0.6, 0)
        
        local ring = Instance.new("Part", visualModel)
        ring.Name = "GlowRing"
        ring.Size = Vector3.new(0.5, 0.1, 0.5)
        ring.Color = Color3.fromRGB(0, 150, 255)
        ring.Material = Enum.Material.Neon
        ring.CanCollide = false
        ring.Massless = true
        
        local weld2 = Instance.new("WeldConstraint", ring)
        weld2.Part0 = ring
        weld2.Part1 = rLower
        ring.CFrame = rLower.CFrame * CFrame.new(0, -0.5, 0)
    else
        local rLeg = char:FindFirstChild("Right Leg")
        if rLeg then
            rLeg.Transparency = 1
            if char:FindFirstChild("LocalKorbloxLeg") then
                char.LocalKorbloxLeg:Destroy()
            end
            
            local visualModel = Instance.new("Model", char)
            visualModel.Name = "LocalKorbloxLeg"
            
            local stick = Instance.new("Part", visualModel)
            stick.Size = Vector3.new(0.4, 2, 0.4)
            stick.Color = Color3.fromRGB(25, 25, 25)
            stick.Material = Enum.Material.Metal
            stick.CanCollide = false
            stick.Massless = true
            
            local weld = Instance.new("WeldConstraint", stick)
            weld.Part0 = stick
            weld.Part1 = rLeg
            stick.CFrame = rLeg.CFrame
        end
    end
end

local function ApplyRandomAvatar()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local presetIds = {1, 150, 261, 187514, 10000, 1610487}
    local selectedId = presetIds[math.random(1, #presetIds)]
    task.spawn(function()
        local success, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(selectedId)
        end)
        
        if success and desc then
            local applySuccess, err = pcall(function()
                hum:ApplyDescription(desc)
            end)
            if applySuccess then
                Library:Notify("Avatar Changer", "Avatar lokal acak berhasil dimuat!", 2)
                return
            end
        end
        
        pcall(function()
            local shirts = {"rbxassetid://121925345", "rbxassetid://607785314", "rbxassetid://144076387"}
            local pants = {"rbxassetid://122304648", "rbxassetid://607785731", "rbxassetid://144076760"}
            
            local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
            shirt.ShirtTemplate = shirts[math.random(1, #shirts)]
            
            local pant = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)
            pant.PantsTemplate = pants[math.random(1, #pants)]
            
            local head = char:FindFirstChild("Head")
            local face = head and head:FindFirstChildOfClass("Decal")
            if face then
                face.Texture = "rbxassetid://143890332"
            end
        end)
        Library:Notify("Avatar Changer", "Avatar lokal acak berhasil diterapkan (Fallback Mode).", 2)
    end)
end

local function CheckWallInFront(moveDirection)
    local char = LocalPlayer.Character
    if not char then return false, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, nil end
    
    local dir = moveDirection or hrp.CFrame.LookVector
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char, Camera}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local origin = hrp.Position + Vector3.new(0, -0.5, 0)
    local result = workspace:Raycast(origin, dir * 8, params)
    
    if result and result.Instance and result.Instance.CanCollide then
        return true, result
    end
    return false, nil
end

-- ========================================================
-- [[ DYNAMIC CUSTOM CROSSHAIR GENERATION ENGINE ]]
-- ========================================================
local CrosshairGui = Instance.new("ScreenGui", (gethui and gethui()) or game:GetService("CoreGui"))
CrosshairGui.Name = "LouisHub_Premium_Crosshair"
CrosshairGui.ResetOnSpawn = false
CrosshairGui.IgnoreGuiInset = true
CrosshairGui.DisplayOrder = 10000000

local CrosshairContainer = Instance.new("Frame", CrosshairGui)
CrosshairContainer.Size = UDim2.new(0, 60, 0, 60)
CrosshairContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
CrosshairContainer.AnchorPoint = Vector2.new(0.5, 0.5)
CrosshairContainer.BackgroundTransparency = 1
CrosshairContainer.Visible = false

local function buildCrosshair(container, styleId, m)
    container:ClearAllChildren()
    
    if styleId == 1 then
        local color = Color3.fromRGB(0, 255, 255)
        local function makeLine(p, s, a)
            local f = Instance.new("Frame", container)
            f.Size = s; f.Position = p; f.AnchorPoint = a
            f.BackgroundColor3 = color; f.BorderSizePixel = 0
        end
        makeLine(UDim2.new(0.5, 0, 0.5, -12 * m), UDim2.new(0, 2 * m, 0, 8 * m), Vector2.new(0.5, 1))
        makeLine(UDim2.new(0.5, 0, 0.5, 12 * m), UDim2.new(0, 2 * m, 0, 8 * m), Vector2.new(0.5, 0))
        makeLine(UDim2.new(0.5, -12 * m, 0.5, 0), UDim2.new(0, 8 * m, 0, 2 * m), Vector2.new(1, 0.5))
        makeLine(UDim2.new(0.5, 12 * m, 0.5, 0), UDim2.new(0, 8 * m, 0, 2 * m), Vector2.new(0, 0.5))

    elseif styleId == 2 then
        local color = Color3.fromRGB(255, 0, 127)
        for i = 1, 3 do
            local line = Instance.new("Frame", container)
            line.Size = UDim2.new(0, 2 * m, 0, 8 * m)
            line.Position = UDim2.new(0.5, 0, 0.5, 0)
            line.AnchorPoint = Vector2.new(0.5, 1.8)
            line.Rotation = (i - 1) * 120
            line.BackgroundColor3 = color; line.BorderSizePixel = 0
        end

    elseif styleId == 3 then
        local circle = Instance.new("Frame", container)
        circle.Name = "Circle"
        circle.Size = UDim2.new(0, 24 * m, 0, 24 * m)
        circle.Position = UDim2.new(0.5, 0, 0.5, 0)
        circle.AnchorPoint = Vector2.new(0.5, 0.5)
        circle.BackgroundTransparency = 1
        Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", circle)
        s.Thickness = math.max(1.5, 2 * m); s.Color = Color3.fromRGB(255, 255, 0)

    elseif styleId == 4 then
        local color = Color3.fromRGB(0, 255, 0)
        local offsets = {{-10 * m, -10 * m}, {6 * m, -10 * m}, {-10 * m, 6 * m}, {6 * m, 6 * m}}
        for _, o in ipairs(offsets) do
            local f = Instance.new("Frame", container)
            f.Name = "Bracket"
            f.Size = UDim2.new(0, 4 * m, 0, 4 * m)
            f.Position = UDim2.new(0.5, o[1], 0.5, o[2])
            f.BackgroundColor3 = color; f.BorderSizePixel = 0
            f:SetAttribute("OrigOffset", Vector2.new(o[1]/m, o[2]/m))
        end

    elseif styleId == 5 then
        local color = Color3.fromRGB(255, 128, 0)
        local left = Instance.new("Frame", container)
        left.Size = UDim2.new(0, 2 * m, 0, 16 * m); left.Position = UDim2.new(0.5, -12 * m, 0.5, 0)
        left.AnchorPoint = Vector2.new(0.5, 0.5); left.BackgroundColor3 = color; left.BorderSizePixel = 0
        Instance.new("UICorner", left).CornerRadius = UDim.new(1, 0)

        local right = Instance.new("Frame", container)
        right.Size = UDim2.new(0, 2 * m, 0, 16 * m); right.Position = UDim2.new(0.5, 12 * m, 0.5, 0)
        right.AnchorPoint = Vector2.new(0.5, 0.5); right.BackgroundColor3 = color; right.BorderSizePixel = 0
        Instance.new("UICorner", right).CornerRadius = UDim.new(1, 0)

    elseif styleId == 6 then
        local color = Color3.fromRGB(170, 0, 255)
        local offsets = {{0, -12 * m}, {0, 12 * m}, {-12 * m, 0}, {12 * m, 0}}
        for _, o in ipairs(offsets) do
            local s = Instance.new("Frame", container)
            s.Size = UDim2.new(0, 5 * m, 0, 5 * m)
            s.Position = UDim2.new(0.5, o[1], 0.5, o[2])
            s.AnchorPoint = Vector2.new(0.5, 0.5); s.Rotation = 45
            s.BackgroundColor3 = color; s.BorderSizePixel = 0
        end

    elseif styleId == 7 then
        local color = Color3.fromRGB(150, 220, 255)
        for i = 1, 8 do
            local angle = (i - 1) * 45
            local rad = math.rad(angle)
            local dist = 12 * m
            local d = Instance.new("Frame", container)
            d.Name = "Dot"
            d.Size = UDim2.new(0, 3 * m, 0, 3 * m)
            d.Position = UDim2.new(0.5, dist * math.cos(rad), 0.5, dist * math.sin(rad))
            d.AnchorPoint = Vector2.new(0.5, 0.5); d.BackgroundColor3 = color; d.BorderSizePixel = 0
            Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
            d:SetAttribute("Index", i)
        end

    elseif styleId == 8 then
        local color = Color3.fromRGB(255, 100, 0)
        for i = 1, 3 do
            local w = Instance.new("Frame", container)
            w.Size = UDim2.new(0, 4 * m, 0, 10 * m)
            w.Position = UDim2.new(0.5, 0, 0.5, 0)
            w.AnchorPoint = Vector2.new(0.5, 1.6); w.Rotation = (i - 1) * 120
            w.BackgroundColor3 = color; w.BorderSizePixel = 0
        end

    elseif styleId == 9 then
        local color = Color3.fromRGB(255, 0, 0)
        local circle = Instance.new("Frame", container)
        circle.Name = "Circle"
        circle.Size = UDim2.new(0, 14 * m, 0, 14 * m); circle.Position = UDim2.new(0.5, 0, 0.5, 0)
        circle.AnchorPoint = Vector2.new(0.5, 0.5); circle.BackgroundTransparency = 1
        local st = Instance.new("UIStroke", circle); st.Thickness = 1; st.Color = color
        Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

        local offsets = {{-12 * m, -12 * m}, {10 * m, -12 * m}, {-12 * m, 10 * m}, {10 * m, 10 * m}}
        for _, o in ipairs(offsets) do
            local f = Instance.new("Frame", container)
            f.Name = "Corner"
            f.Size = UDim2.new(0, 2 * m, 0, 2 * m); f.Position = UDim2.new(0.5, o[1], 0.5, o[2])
            f.BackgroundColor3 = color; f.BorderSizePixel = 0
            f:SetAttribute("OrigOffset", Vector2.new(o[1]/m, o[2]/m))
        end

    elseif styleId == 10 then
        local color = Color3.fromRGB(255, 0, 255)
        for i = 1, 6 do
            local angle = (i - 1) * 60
            local rad = math.rad(angle)
            local dist = 13 * m
            local line = Instance.new("Frame", container)
            line.Name = "HexLine"
            line.Size = UDim2.new(0, 2 * m, 0, 5 * m)
            line.Position = UDim2.new(0.5, dist * math.cos(rad), 0.5, dist * math.sin(rad))
            line.AnchorPoint = Vector2.new(0.5, 0.5); line.Rotation = angle
            line.BackgroundColor3 = color; line.BorderSizePixel = 0
            
            line:SetAttribute("BaseAngle", angle)
            line:SetAttribute("SpeedMult", (i % 2 == 0) and -1 or 1.2)
        end

    elseif styleId == 11 then
        local color = Color3.fromRGB(255, 50, 50)
        for i = 1, 4 do
            local angle = (i - 1) * 90
            local rad = math.rad(angle)
            local line = Instance.new("Frame", container)
            line.Name = "Line"
            line.Size = UDim2.new(0, 2 * m, 0, 6 * m)
            line.Position = UDim2.new(0.5, 14 * m * math.cos(rad), 0.5, 14 * m * math.sin(rad))
            line.AnchorPoint = Vector2.new(0.5, 0.5)
            line.Rotation = angle
            line.BackgroundColor3 = color; line.BorderSizePixel = 0
            line:SetAttribute("OrigOffset", Vector2.new(14 * math.cos(rad), 14 * math.sin(rad)))
        end

    elseif styleId == 12 then
        local color = Color3.fromRGB(255, 215, 0)
        local inner = Instance.new("Frame", container)
        inner.Name = "Inner"
        inner.Size = UDim2.new(0, 12 * m, 0, 12 * m)
        inner.Position = UDim2.new(0.5, 0, 0.5, 0)
        inner.AnchorPoint = Vector2.new(0.5, 0.5)
        inner.BackgroundTransparency = 1
        Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)
        local s1 = Instance.new("UIStroke", inner)
        s1.Thickness = 1.5; s1.Color = color

        local outer = Instance.new("Frame", container)
        outer.Name = "Outer"
        outer.Size = UDim2.new(0, 24 * m, 0, 24 * m)
        outer.Position = UDim2.new(0.5, 0, 0.5, 0)
        outer.AnchorPoint = Vector2.new(0.5, 0.5)
        outer.BackgroundTransparency = 1
        Instance.new("UICorner", outer).CornerRadius = UDim.new(1, 0)
        local s2 = Instance.new("UIStroke", outer)
        s2.Thickness = 1; s2.Color = color

    elseif styleId == 13 then
        local color = Color3.fromRGB(0, 255, 128)
        local ring = Instance.new("Frame", container)
        ring.Size = UDim2.new(0, 22 * m, 0, 22 * m)
        ring.Position = UDim2.new(0.5, 0, 0.5, 0)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
        local s = Instance.new("UIStroke", ring)
        s.Thickness = 1; s.Color = color; s.Transparency = 0.5

        local line = Instance.new("Frame", container)
        line.Name = "SweepLine"
        line.Size = UDim2.new(0, 1.5 * m, 0, 10 * m)
        line.Position = UDim2.new(0.5, 0, 0.5, 0)
        line.AnchorPoint = Vector2.new(0.5, 1)
        line.BackgroundColor3 = color; line.BorderSizePixel = 0

    elseif styleId == 14 then
        local color = Color3.fromRGB(255, 140, 0)
        for i = 1, 3 do
            local angle = (i - 1) * 120
            local rad = math.rad(angle)
            local arc = Instance.new("Frame", container)
            arc.Name = "ArcPart"
            arc.Size = UDim2.new(0, 8 * m, 0, 2.5 * m)
            arc.Position = UDim2.new(0.5, 10 * m * math.cos(rad), 0.5, 10 * m * math.sin(rad))
            arc.AnchorPoint = Vector2.new(0.5, 0.5)
            arc.Rotation = angle + 45
            arc.BackgroundColor3 = color; arc.BorderSizePixel = 0
            Instance.new("UICorner", arc)
            arc:SetAttribute("BaseAngle", angle)
        end

    elseif styleId == 15 then
        local color = Color3.fromRGB(0, 180, 255)
        local dot = Instance.new("Frame", container)
        dot.Size = UDim2.new(0, 3 * m, 0, 3 * m)
        dot.Position = UDim2.new(0.5, 0, 0.5, 0)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.BackgroundColor3 = color; dot.BorderSizePixel = 0
        Instance.new("UICorner", dot)

        local bracketPositions = {
            {-8 * m, -8 * m}, {8 * m, -8 * m},
            {-8 * m, 8 * m}, {8 * m, 8 * m}
        }
        for _, p in ipairs(bracketPositions) do
            local b = Instance.new("Frame", container)
            b.Name = "HUDBracket"
            b.Size = UDim2.new(0, 4 * m, 0, 4 * m)
            b.Position = UDim2.new(0.5, p[1], 0.5, p[2])
            b.AnchorPoint = Vector2.new(0.5, 0.5)
            b.BackgroundColor3 = color; b.BorderSizePixel = 0
            b:SetAttribute("OrigOffset", Vector2.new(p[1]/m, p[2]/m))
        end
    end
end

local function updateCrosshairAnimation(container, styleId, m, t)
    local rotAngle = (t * _G.CrosshairRotationSpeed) % 360
    container.Size = UDim2.new(0, 60 * m, 0, 60 * m)
    container.Rotation = rotAngle

    if styleId == 1 then
        container.Rotation = rotAngle
    elseif styleId == 2 then
        container.Rotation = -rotAngle
    elseif styleId == 3 then
        local pulsate = 1 + math.sin(t * 6) * 0.15
        container.Size = UDim2.new(0, 60 * m * pulsate, 0, 60 * m * pulsate)
        container.Rotation = rotAngle
        local circ = container:FindFirstChild("Circle")
        if circ then
            local s = circ:FindFirstChildOfClass("UIStroke")
            if s then
                local colorFactor = (math.sin(t * 4) + 1) / 2
                s.Color = Color3.fromRGB(255, math.floor(255 * (1 - colorFactor)), 0)
            end
        end
    elseif styleId == 4 then
        container.Rotation = -rotAngle * 0.5
        local expand = 1 + math.sin(t * 8) * 0.25
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "Bracket" then
                local orig = child:GetAttribute("OrigOffset")
                if orig then
                    child.Position = UDim2.new(0.5, orig.X * expand * m, 0.5, orig.Y * expand * m)
                end
            end
        end
    elseif styleId == 5 then
        container.Rotation = rotAngle
        local pulsate = 1 + math.sin(t * 10) * 0.12
        container.Size = UDim2.new(0, 60 * m * pulsate, 0, 60 * m * pulsate)
    elseif styleId == 6 then
        local oscillate = math.sin(t * 4) * 85
        container.Rotation = oscillate
    elseif styleId == 7 then
        container.Rotation = -rotAngle
        local cycle = (math.sin(t * 3.5) + 1) / 2
        local col1 = Color3.fromRGB(150, 220, 255):Lerp(Color3.fromRGB(255, 100, 100), cycle)
        local col2 = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(100, 255, 100), cycle)
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "Dot" then
                local index = child:GetAttribute("Index") or 1
                child.BackgroundColor3 = (index % 2 == 0) and col1 or col2
            end
        end
    elseif styleId == 8 then
        container.Rotation = -rotAngle * 1.3
        local pulsate = 1 + math.sin(t * 5) * 0.14
        container.Size = UDim2.new(0, 60 * m * pulsate, 0, 60 * m * pulsate)
    elseif styleId == 9 then
        container.Rotation = rotAngle * 0.3
        local expand = 1 + math.sin(t * 7) * 0.32
        local r = math.floor(math.sin(t * 2) * 127 + 128)
        local g = math.floor(math.sin(t * 2 + 2) * 127 + 128)
        local b = math.floor(math.sin(t * 2 + 4) * 127 + 128)
        local rainbow = Color3.fromRGB(r, g, b)
        
        local circ = container:FindFirstChild("Circle")
        if circ then
            local s = circ:FindFirstChildOfClass("UIStroke")
            if s then s.Color = rainbow end
        end
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "Corner" then
                child.BackgroundColor3 = rainbow
                local orig = child:GetAttribute("OrigOffset")
                if orig then
                    child.Position = UDim2.new(0.5, orig.X * expand * m, 0.5, orig.Y * expand * m)
                end
            end
        end
    elseif styleId == 10 then
        container.Rotation = 0
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "HexLine" then
                local base = child:GetAttribute("BaseAngle") or 0
                local speed = child:GetAttribute("SpeedMult") or 1
                local childRot = base + (rotAngle * speed)
                local rad = math.rad(childRot)
                local dist = 13 * m
                child.Position = UDim2.new(0.5, dist * math.cos(rad), 0.5, dist * math.sin(rad))
                child.Rotation = childRot
                local cycle = (math.sin(t * 5 + childRot) + 1) / 2
                child.BackgroundColor3 = Color3.fromRGB(255, 0, 255):Lerp(Color3.fromRGB(0, 255, 255), cycle)
            end
        end
    elseif styleId == 11 then
        container.Rotation = rotAngle * 0.8
        local pulse = 1 + math.sin(t * 8) * 0.2
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "Line" then
                local orig = child:GetAttribute("OrigOffset")
                if orig then
                    child.Position = UDim2.new(0.5, orig.X * pulse * m, 0.5, orig.Y * pulse * m)
                end
            end
        end
    elseif styleId == 12 then
        container.Rotation = 0
        local inner = container:FindFirstChild("Inner")
        local outer = container:FindFirstChild("Outer")
        if inner then inner.Rotation = rotAngle end
        if outer then outer.Rotation = -rotAngle * 0.5 end
    elseif styleId == 13 then
        container.Rotation = 0
        local sweep = container:FindFirstChild("SweepLine")
        if sweep then sweep.Rotation = rotAngle * 1.5 end
    elseif styleId == 14 then
        container.Rotation = -rotAngle * 1.2
        local breathe = 1 + math.sin(t * 4) * 0.15
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "ArcPart" then
                local base = child:GetAttribute("BaseAngle") or 0
                local rad = math.rad(base)
                child.Position = UDim2.new(0.5, 10 * m * breathe * math.cos(rad), 0.5, 10 * m * breathe * math.sin(rad))
            end
        end
    elseif styleId == 15 then
        container.Rotation = rotAngle * 0.2
        local scale = 1 + math.sin(t * 6) * 0.3
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "HUDBracket" then
                local orig = child:GetAttribute("OrigOffset")
                if orig then
                    child.Position = UDim2.new(0.5, orig.X * scale * m, 0.5, orig.Y * scale * m)
                end
            end
        end
    end
end

-- Bypassing Mouse Cursor Icon (Shiftlock)
local TRANSPARENT_ICON = "rbxassetid://0"
local successHook, _ = pcall(function()
    local old_newindex
    old_newindex = hookmetamethod(game, "__newindex", function(self, key, value)
        if self == Mouse and key == "Icon" and _G.CrosshairEnabled then
            return old_newindex(self, key, TRANSPARENT_ICON)
        end
        return old_newindex(self, key, value)
    end)
end)

if not successHook then
    SafeConnect(RunService.PostSimulation, function()
        if _G.CrosshairEnabled then
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
                if Mouse.Icon ~= TRANSPARENT_ICON then
                    Mouse.Icon = TRANSPARENT_ICON
                end
            end
        else
            if Mouse.Icon == TRANSPARENT_ICON then
                Mouse.Icon = ""
            end
        end
    end)
end

-- ========================================================
-- [[ MOVEMENT & TBD AUTOMATIONS PHYSICS ENGINE ]]
-- ========================================================
local function teleportTween(targetPart)
    if isTweening or not targetPart then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    isTweening = true
    
    local startCFrame = hrp.CFrame
    local startPos = hrp.Position
    local endPos = targetPart.Position
    local dist = (startPos - endPos).Magnitude
    
    local speed = 230 
    local duration = math.clamp(dist / speed, 0.05, 0.75)
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetPart.CFrame * CFrame.new(0, 0, 1.2)})
    tween:Play()
    tween.Completed:Connect(function()
        task.wait(0.05)
        hrp.CFrame = startCFrame
        isTweening = false
    end)
end

local function triggerManualPass()
    if isTweening then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPos = char.HumanoidRootPart.Position
    
    local bestTarget = nil
    local minDist = math.huge
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) then
            local isMatch = false
            if _G.PassTargetMode == "Without Bomb" then
                isMatch = not hasBomb(p)
            else
                isMatch = hasBomb(p)
            end
            
            if isMatch then
                local d = (rootPos - p.Character.HumanoidRootPart.Position).Magnitude
                if d <= _G.PassMaxDistance and d < minDist then
                    minDist = d
                    bestTarget = p
                end
            end
        end
    end
    
    if bestTarget then
        teleportTween(bestTarget.Character.HumanoidRootPart)
        Library:Notify("Pass Bomb", "Teleporting to pass bomb directly to " .. bestTarget.Name, 1.5)
    else
        Library:Notify("Pass Bomb", "No valid target player found in range.", 2)
    end
end

-- PRIMARY GAMEPLAY CORE LOOP
SafeConnect(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function(dt)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = LocalPlayer.Character.HumanoidRootPart
    local hum = LocalPlayer.Character.Humanoid
    local amIHolder = hasBomb(LocalPlayer)
    
    -- Reset Jump count if grounded
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        _G.CurrentJumpCount = 0
    end

    -- FOV Camera Sync Loop
    if _G.FOVEnabled then
        Camera.FieldOfView = _G.FOVValue
    end

    -- Crosshair render update
    local elapsed = tick()
    if _G.CrosshairEnabled and CrosshairContainer.Visible then
        updateCrosshairAnimation(CrosshairContainer, _G.CurrentCrosshairStyle, 1.0, elapsed)
    end

    -- VISUAL RANGE RING UPDATER (INTEGRASI NEW)
    if _G.RangeChaseEnabled then
        if not RangeVisualPart or RangeVisualPart.Parent == nil then
            CreateRangeVisual()
        end
        if RangeVisualPart then
            RangeVisualPart.Size = Vector3.new(0.2, _G.RangeChaseValue * 2, _G.RangeChaseValue * 2)
            local groundPosition = root.Position - Vector3.new(0, 2.8, 0)
            RangeVisualPart.CFrame = CFrame.new(groundPosition) * CFrame.Angles(0, 0, math.rad(90))
        end
    else
        if RangeVisualPart then
            pcall(function() RangeVisualPart:Destroy() end)
            RangeVisualPart = nil
        end
    end

    if hum.FloorMaterial == Enum.Material.Air and root.Velocity.Magnitude > 100 then 
        root.Velocity = root.Velocity.Unit * 100 
    end
    if amIHolder then bombTimer += dt else bombTimer = 0 end

    isSticking = false

    if tick() - lastRaycastCheck >= raycastInterval then
        if lockedTarget then isVisibleCached = canSeePlayerSticky(lockedTarget) end
        lastRaycastCheck = tick()
    end

    if not lastHadBomb and amIHolder then
        retreatTimer = 0; local minDist = 15; local tagger = nil
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) then
                local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                if d < minDist then minDist = d; tagger = p end
            end
        end
        if tagger then lockedTarget = tagger; targetMemory = 2 end 
    end

    if lockedTarget and (not isAlive(lockedTarget) or isTeammate(lockedTarget) or (amIHolder and hasBomb(lockedTarget))) then 
        lockedTarget = nil 
    end
    if isVisibleCached then targetMemory = 1.2 elseif targetMemory > 0 then targetMemory -= dt end

    if tick() - lastTargetSearch >= searchInterval then
        local minDist = math.huge; local best = nil; local closestDist = math.huge; local closestPlayer = nil
        
        -- SISTEM RANGE CHASE (INTEGRASI NEW)
        if _G.RangeChaseEnabled then
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d <= _G.RangeChaseValue and d < minDist then
                        minDist = d
                        best = p
                    end
                end
            end
            lockedTarget = best
        else
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) then
                    local d = (root.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < closestDist then closestDist = d; closestPlayer = p end
                    if (amIHolder and not hasBomb(p)) or (not amIHolder) then
                        if canSeePlayerSticky(p) then if d < minDist then minDist = d; best = p end end
                    end
                end
            end
            if closestPlayer and closestDist <= 7 then
                lockedTarget = closestPlayer; targetMemory = 1.2
            elseif not lockedTarget or (targetMemory <= 0 and not isVisibleCached) or (amIHolder and bombTimer > 7) then
                if best then lockedTarget = best; targetMemory = 1.2 end
            end
        end
        lastTargetSearch = tick()
    end

    if lastHadBomb and not amIHolder then 
        hum.WalkSpeed = 16
        retreatTimer = _G.HJEnabled and 3.8 or 2.5
        if _G.HJEnabled then task.spawn(function() hum:ChangeState(3); task.wait(0.4); hum:ChangeState(3) end) end
        if _G.AutoWalkActive then
            autoWalkRetreatTimer = 2.5
        end
    end

    -- AUTOMATIC BOMB PASSING
    if _G.AutoPassEnabled and amIHolder and not isTweening then
        local rootPos = root.Position
        local bestTarget = nil
        local minDist = math.huge
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) and not isTeammate(p) and not hasBomb(p) then
                local d = (rootPos - p.Character.HumanoidRootPart.Position).Magnitude
                if d <= _G.PassMaxDistance and d < minDist then
                    minDist = d
                    bestTarget = p
                end
            end
        end
        if bestTarget then
            teleportTween(bestTarget.Character.HumanoidRootPart)
        end
    end

    -- WALK & CHASE AUTOMATIONS (INTEGRATED WALL AVOIDANCE & RANGE CHASE)
    if _G.RangeChaseEnabled then
        if lockedTarget and isAlive(lockedTarget) then
            local tRoot = lockedTarget.Character.HumanoidRootPart
            local targetPos = tRoot.Position
            local moveDirection = (targetPos - root.Position).Unit
            
            if _G.WallAvoidEnabled then
                local hasObstacle, hitInfo = CheckWallInFront(moveDirection)
                if hasObstacle then
                    if _G.WallAvoidMethod == "Jump" then
                        if hum.FloorMaterial ~= Enum.Material.Air then
                            hum.Jump = true
                        end
                    elseif _G.WallAvoidMethod == "Avoid" then
                        local rightVec = root.CFrame.RightVector
                        targetPos = targetPos + (rightVec * 8)
                    end
                end
            end
            
            hum:MoveTo(targetPos)
        end
    elseif _G.AutoWalkActive then
        if amIHolder then
            if lockedTarget and isAlive(lockedTarget) then
                local tRoot = lockedTarget.Character.HumanoidRootPart; local dist = (root.Position - tRoot.Position).Magnitude
                if dist <= 12 then hum.WalkSpeed = 25 else hum.WalkSpeed = 16 end
                
                local targetPos = tRoot.Position
                local speed = 25
                local moveDir = (targetPos - root.Position).Unit
                
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                params.FilterType = Enum.RaycastFilterType.Exclude
                
                local rayOrigin = root.Position + Vector3.new(0, -1.2, 0)
                local raycastResult = Workspace:Raycast(rayOrigin, moveDir * 6, params)
                if raycastResult and raycastResult.Instance.CanCollide then
                    local angles = {30, -30, 60, -60, 90, -90, 120, -120}
                    for _, angle in ipairs(angles) do
                        local worldAltDir = (CFrame.lookAt(root.Position, targetPos) * CFrame.Angles(0, math.rad(angle), 0)).LookVector
                        local altRay = Workspace:Raycast(rayOrigin, worldAltDir * 6, params)
                        if not altRay or not altRay.Instance.CanCollide then
                            moveDir = worldAltDir
                            break
                        end
                    end
                end
                
                if _G.WallAvoidEnabled then
                    local hasObstacle, hitInfo = CheckWallInFront(moveDir)
                    if hasObstacle then
                        if _G.WallAvoidMethod == "Jump" then
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                hum.Jump = true
                            end
                        elseif _G.WallAvoidMethod == "Avoid" then
                            moveDir = (moveDir + root.CFrame.RightVector * 1.5).Unit
                        end
                    end
                end
                
                local nextPos = root.Position + (moveDir * speed * dt)
                local groundRay = Workspace:Raycast(nextPos + Vector3.new(0, 5, 0), Vector3.new(0, -12, 0), params)
                local targetY = root.Position.Y
                if groundRay then
                    targetY = groundRay.Position.Y + 3.0
                end
                
                root.CFrame = CFrame.new(Vector3.new(nextPos.X, targetY, nextPos.Z), Vector3.new(targetPos.X, targetY, targetPos.Z))
                hum:Move(Vector3.new(0, 0, 0))
            else
                hum.WalkSpeed = 16
            end
        else
            local bombHolder = nil
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isAlive(p) and hasBomb(p) then
                    bombHolder = p
                    break
                end
            end
            
            if bombHolder then
                local targetPos = bombHolder.Character.HumanoidRootPart.Position
                local speed = _G.AutoWalkRetreatSpeed or 22
                local moveDir = (root.Position - targetPos).Unit
                
                local params = RaycastParams.new()
                params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                params.FilterType = Enum.RaycastFilterType.Exclude
                
                local rayOrigin = root.Position + Vector3.new(0, -1.2, 0)
                local raycastResult = Workspace:Raycast(rayOrigin, moveDir * 6, params)
                if raycastResult and raycastResult.Instance.CanCollide then
                    local angles = {30, -30, 60, -60, 90, -90, 120, -120}
                    for _, angle in ipairs(angles) do
                        local worldAltDir = (CFrame.lookAt(root.Position, root.Position + moveDir) * CFrame.Angles(0, math.rad(angle), 0)).LookVector
                        local altRay = Workspace:Raycast(rayOrigin, worldAltDir * 6, params)
                        if not altRay or not altRay.Instance.CanCollide then
                            moveDir = worldAltDir
                            break
                        end
                    end
                end
                
                if _G.WallAvoidEnabled then
                    local hasObstacle, hitInfo = CheckWallInFront(moveDir)
                    if hasObstacle then
                        if _G.WallAvoidMethod == "Jump" then
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                hum.Jump = true
                            end
                        elseif _G.WallAvoidMethod == "Avoid" then
                            moveDir = (moveDir + root.CFrame.RightVector * 1.5).Unit
                        end
                    end
                end
                
                local nextPos = root.Position + (moveDir * speed * dt)
                local groundRay = Workspace:Raycast(nextPos + Vector3.new(0, 5, 0), Vector3.new(0, -12, 0), params)
                local targetY = root.Position.Y
                if groundRay then
                    targetY = groundRay.Position.Y + 3.0
                end
                
                root.CFrame = CFrame.new(Vector3.new(nextPos.X, targetY, nextPos.Z), Vector3.new(targetPos.X, targetY, targetPos.Z))
                hum:Move(Vector3.new(0, 0, 0))
            else
                if lockedTarget and isAlive(lockedTarget) then
                    local tRoot = lockedTarget.Character.HumanoidRootPart
                    hum:MoveTo(root.Position + (root.Position - tRoot.Position).Unit * 22)
                end
            end
        end
    else
        if lockedTarget and isAlive(lockedTarget) then
            local tRoot = lockedTarget.Character.HumanoidRootPart; local dist = (root.Position - tRoot.Position).Magnitude
            if amIHolder and dist <= 12 then hum.WalkSpeed = 25 else hum.WalkSpeed = 16 end
            
            local shouldFollow = (_G.FollowEnabled and _G.FollowActive) or _G.AutoHoldActive
            local targetPos = _G.PredictEnabled and (tRoot.Position + (tRoot.Velocity * 0.13)) or tRoot.Position
            local moveDirection = (targetPos - root.Position).Unit
            
            if _G.WallAvoidEnabled then
                local hasObstacle, hitInfo = CheckWallInFront(moveDirection)
                if hasObstacle then
                    if _G.WallAvoidMethod == "Jump" then
                        if hum.FloorMaterial ~= Enum.Material.Air then
                            hum.Jump = true
                        end
                    elseif _G.WallAvoidMethod == "Avoid" then
                        local rightVec = root.CFrame.RightVector
                        targetPos = targetPos + (rightVec * 8)
                    end
                end
            end
            
            if shouldFollow and retreatTimer <= 0 then 
                hum:MoveTo(targetPos) 
            elseif shouldFollow then
                retreatTimer -= dt; hum:MoveTo(root.Position + (root.Position - tRoot.Position).Unit * 22)
            elseif lastShouldFollow then
                hum:Move(Vector3.new(0, 0, 0))
            end
            lastShouldFollow = shouldFollow
        else 
            hum.WalkSpeed = 16 
            if lastShouldFollow then
                hum:Move(Vector3.new(0, 0, 0))
                lastShouldFollow = false
            end
        end
    end

    -- REAL-TIME FLICK CAMERA ROTATION
    if _G.FlickActive and amIHolder and isAlive(lockedTarget) and (root.Position - lockedTarget.Character.HumanoidRootPart.Position).Magnitude <= 4 then
        local str = _G.FlickStrength or 45
        Camera.CFrame *= CFrame.Angles(math.rad(math.random(-str/2, str/2)), math.rad(math.random(-str, str)), 0)
    end

    -- AUTOMATIC HOLD BOMB FACING ENGINE
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter and isAlive(lockedTarget) then
        if _G.AutoHoldActive and amIHolder then
            hum.AutoRotate = false
            local remaining = getBombTime()
            local lookDir
            if remaining and remaining <= 1.05 then
                lookDir = Vector3.new(lockedTarget.Character.HumanoidRootPart.Position.X, root.Position.Y, lockedTarget.Character.HumanoidRootPart.Position.Z)
            else
                lookDir = root.Position + (root.Position - lockedTarget.Character.HumanoidRootPart.Position).Unit
            end
            root.CFrame = root.CFrame:Lerp(CFrame.new(root.Position, lookDir), 0.3)
        elseif _G.FaceClassic or _G.FacePro then
            hum.AutoRotate = false
            local lookDir = amIHolder and Vector3.new(lockedTarget.Character.HumanoidRootPart.Position.X, root.Position.Y, lockedTarget.Character.HumanoidRootPart.Position.Z) or (root.Position + (root.Position - lockedTarget.Character.HumanoidRootPart.Position).Unit)
            root.CFrame = root.CFrame:Lerp(CFrame.new(root.Position, lookDir), _G.FacePro and 0.3 or faceSpeed)
        else
            hum.AutoRotate = true
        end
    else
        if _G.AutoHoldActive and amIHolder and isAlive(lockedTarget) then
            hum.AutoRotate = false
            local remaining = getBombTime()
            local lookDir
            if remaining and remaining <= 1.05 then
                lookDir = Vector3.new(lockedTarget.Character.HumanoidRootPart.Position.X, root.Position.Y, lockedTarget.Character.HumanoidRootPart.Position.Z)
            else
                lookDir = root.Position + (root.Position - lockedTarget.Character.HumanoidRootPart.Position).Unit
            end
            root.CFrame = root.CFrame:Lerp(CFrame.new(root.Position, lookDir), 0.3)
        else
            hum.AutoRotate = true
        end
    end

    lastHadBomb = amIHolder
end))

-- STRETCH RESOLUTION RENDER LOOP
SafeConnect(RunService.RenderStepped, function()
    if _G.ResolutionEnabled and _G.ResolutionValue ~= 1.00 then
        Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, _G.ResolutionValue, 0, 0, 0, 1)
    end
end)

-- AUTO JUMP PROPERTY CHANGE CONNECTION
local function handleAutoJump()
    if _G.AutoJumpEnabled and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        if LocalPlayer.Character and LocalPlayer.Character.Humanoid and LocalPlayer.Character.Humanoid.FloorMaterial ~= Enum.Material.Air then 
            LocalPlayer.Character.Humanoid.Jump = true 
        end
    end
end
SafeConnect(UserInputService:GetPropertyChangedSignal("MouseBehavior"), handleAutoJump)

-- WALLHOP & MULTI-JUMP CONNECTOR (PREMIUM IMPLEMENTATION)
local JumpRequestConnection = UserInputService.JumpRequest:Connect(function()
    isSticking = false 

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if _G.InfJumpEnabled and not jumpDebounce then
        jumpDebounce = true
        if hum.FloorMaterial == Enum.Material.Air then
            if _G.CurrentJumpCount < _G.MaxJumpCount - 1 then
                _G.CurrentJumpCount = _G.CurrentJumpCount + 1
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        else
            _G.CurrentJumpCount = 0
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        task.spawn(function()
            task.wait(0.2)
            jumpDebounce = false
        end)
    end

    if not canWallJump or (tick() - lastWallHopTime < 0.18) then return end
    if not (_G.WHNormal or _G.WHInstant) then return end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local isNearWall = false
    local detectedPart = nil

    for i = 0, 7 do
        local angle = math.rad(i * 45)
        local dir = (hrp.CFrame * CFrame.Angles(0, angle, 0)).LookVector
        local r = Workspace:Raycast(hrp.Position, dir * _G.WallHopDist, params)
        if r and r.Instance.CanCollide then
            isNearWall = true
            detectedPart = r.Instance
            break
        end
    end

    if isNearWall and hum.FloorMaterial == Enum.Material.Air then
        lastWallHopTime = tick()
        canWallJump = false

        local jumpPowerBoost = hum.JumpPower > 0 and hum.JumpPower or 50
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpPowerBoost * 0.95, hrp.AssemblyLinearVelocity.Z)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)

        if _G.WHInstant then
            task.spawn(function()
                pcall(function()
                    local angle = math.rad(15)
                    Camera.CFrame *= CFrame.Angles(0, -angle, 0)
                    task.wait(0.01)
                    Camera.CFrame *= CFrame.Angles(0, angle * 2, 0)
                    task.wait(0.01)
                    Camera.CFrame *= CFrame.Angles(0, -angle, 0)
                end)
            end)
        elseif _G.WHNormal then
            task.spawn(function()
                hrp.CFrame *= CFrame.Angles(0, math.rad(-30), 0)
                task.wait(0.06)
                hrp.CFrame *= CFrame.Angles(0, math.rad(30), 0)
            end)
        end

        task.wait(0.18)
        canWallJump = true
    end
end)
table.insert(_G.LouisConnections, JumpRequestConnection)

-- ========================================================================
-- [[ MAIN MENU STRUCTURE ]]
-- ========================================================================
local Window = Library:CreateWindow("LOUIS TBD PREMIUM EDITION", "discord.gg/P2FEVBz2PG")
Window:BindToggleKey(Enum.KeyCode.RightControl)

Library:Notify("LOUIS HUB PREMIUM EDITION INSTANTIATED", "Press RightControl to hide/show Main UI.", 4)

-- --- TAB 1: WELCOME ---
local TabMain = Window:CreateTab("Welcome", "rbxassetid://6023426915")
TabMain:CreateParagraph("Welcome!", "Hello " .. LocalPlayer.Name .. "!\nThank you for executing Louis TBD Premium Edition.")
TabMain:CreateParagraph("UI Instructions", "Keybind to open/hide menu: RightControl\nYou can toggle external buttons from the settings.")
TabMain:CreateParagraph("Official Community", "Join our Discord server to get the latest update information!")

TabMain:CreateButton("Copy Discord Server Link", function()
    if setclipboard then
        setclipboard("https://discord.gg/P2FEVBz2PG")
        Library:Notify("Discord Link", "Discord link copied successfully to your clipboard!", 2)
    else
        Library:Notify("Error", "Your exploit does not support clipboard copying.", 2.5)
    end
end)

TabMain:CreateButton("Activate Potato Graphics Optimization", function()
    ApplyPotato()
    Library:Notify("Potato Mode", "Graphics optimized successfully!", 3)
end)

-- --- TAB 2: AUTOMATIC CHASE & FOLLOW ---
local TabCombat = Window:CreateTab("Auto Chase & Walk", "rbxassetid://4483345998")

local FollowToggle
FollowToggle = TabCombat:CreateToggle("[Q] Enable Follow System", false, "FollowEnabled", function(state)
    _G.FollowEnabled = state
    SafeSetVisible(_G.ExtFollowBtn, state)
    if not state then
        _G.FollowActive = false
        SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
    end
end)

TabCombat:CreateToggle("Predict Coordinates", false, "PredictEnabled", function(state)
    _G.PredictEnabled = state
end)

TabCombat:CreateToggle("[T] Enable Auto Walk System", false, "AutoWalkEnabled", function(state)
    _G.AutoWalkEnabled = state
    SafeSetVisible(_G.ExtAutoWalkBtn, state)
    if not state then
        _G.AutoWalkActive = false
        SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
    end
end)

TabCombat:CreateSlider("Auto Walk Retreat Speed", 10, 50, _G.AutoWalkRetreatSpeed, "AutoWalkRetreatSpeed", function(val)
    _G.AutoWalkRetreatSpeed = val
end)

TabCombat:CreateParagraph("Automatic Bomb Passing", "Instantly tween-teleport to target player, pass the bomb, and return back.")

TabCombat:CreateToggle("[P] Enable Auto Pass Bomb", false, "AutoPassEnabled", function(state)
    _G.AutoPassEnabled = state
end)

TabCombat:CreateDropdown("Pass Target Mode", {"Without Bomb", "With Bomb"}, "Without Bomb", "PassTargetMode", function(val)
    _G.PassTargetMode = val
end)

TabCombat:CreateSlider("Pass Max Distance (Studs)", 1, 200, _G.PassMaxDistance, "PassMaxDistance", function(val)
    _G.PassMaxDistance = val
end)

TabCombat:CreateToggle("Show Manual Pass Button [PASS]", false, "PassExternalVisible", function(state)
    _G.PassExternalVisible = state
    SafeSetVisible(_G.ExtPassBtn, state)
end)

TabCombat:CreateButton("Manual Trigger Pass Bomb Now", function()
    triggerManualPass()
end)

-- INTEGRASI FITUR AREA CHASE (FROM FREE)
TabCombat:CreateParagraph("Range Area Chase System", "Otomatis kejar player lain yang memasuki area lingkaran visual Anda.")

TabCombat:CreateToggle("Enable Range Area Chase", false, "RangeChaseEnabled", function(state)
    _G.RangeChaseEnabled = state
    SafeSetVisible(_G.ExtRangeChaseBtn, state)
    if state then
        SafeSetText(_G.ExtRangeChaseBtn, "CHASING")
    else
        SafeSetText(_G.ExtRangeChaseBtn, "RANGE CHASE")
    end
end)

TabCombat:CreateSlider("Chase Range (Studs)", 10, 150, _G.RangeChaseValue, "RangeChaseValue", function(val)
    _G.RangeChaseValue = val
end)

-- --- TAB 3: FLICK & HOLD ---
local TabFlick = Window:CreateTab("Flick & Hold", "rbxassetid://4483345998")

TabFlick:CreateParagraph("Flick Backwards", "Camera spin system when player touches enemies with the bomb.")

TabFlick:CreateToggle("[Z] Enable Flick System", false, "FlickEnabled", function(state)
    _G.FlickEnabled = state
    SafeSetVisible(_G.ExtFlickBtn, state)
    if not state then
        _G.FlickActive = false
        SafeSetText(_G.ExtFlickBtn, "FLICK")
    end
end)

TabFlick:CreateSlider("Flick Strength Rotation (Degrees)", 5, 90, _G.FlickStrength, "FlickStrength", function(val)
    _G.FlickStrength = val
end)

TabFlick:CreateParagraph("Auto Hold Bomb", "Will turn backwards when you hold the bomb, and faces forward when the timer reaches 1 sec.")

TabFlick:CreateToggle("[J] Enable Auto Hold Bomb", false, "AutoHoldEnabled", function(state)
    _G.AutoHoldEnabled = state
    SafeSetVisible(_G.ExtHoldBtn, state)
    if not state then
        _G.AutoHoldActive = false
        SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
    end
end)

-- --- TAB 4: MOVEMENT & WALLHOP ---
local TabMovement = Window:CreateTab("Movement Hacks", "rbxassetid://4483362458")

-- INTEGRASI FITUR TRIP FALL (FROM FREE)
TabMovement:CreateParagraph("Trip Fall Physics", "Membuat karakter Anda jatuh tersungkur ke lantai seperti sistem trip di Infinite Yield.")

TabMovement:CreateToggle("Enable Trip Fall", false, "TripEnabled", function(state)
    _G.TripEnabled = state
    ApplyTrip(state)
    SafeSetVisible(_G.ExtTripBtn, state)
    if state then
        SafeSetText(_G.ExtTripBtn, "TRIPPED")
    else
        SafeSetText(_G.ExtTripBtn, "TRIP FALL")
    end
end)

-- INTEGRASI FITUR DETEKSI DINDING (FROM FREE)
TabMovement:CreateParagraph("Wall Detection System (BETA)", "Deteksi dinding secara otomatis di depan arah gerak karakter Anda.\n[Catatan: Fitur ini masih dalam tahap pengembangan / BETA]")

TabMovement:CreateToggle("Enable Wall Detection Avoidance", false, "WallAvoidEnabled", function(state)
    _G.WallAvoidEnabled = state
end)

TabMovement:CreateDropdown("Wall Avoid Method", {"Jump", "Avoid"}, "Jump", "WallAvoidMethod", function(val)
    _G.WallAvoidMethod = val
end)

TabMovement:CreateParagraph("Freeze Simulator", "Simulate network delay by anchoring parts in place.")

TabMovement:CreateToggle("[O] Enable Freeze System", false, "FreezeEnabled", function(state)
    _G.FreezeEnabled = state
    SafeSetVisible(_G.ExtFreezeBtn, state)
    if not state then
        pcall(function()
            for _, part in ipairs(activeAnchoredParts or {}) do
                part.Anchored = false
            end
            table.clear(activeAnchoredParts or {})
            SafeSetText(_G.ExtFreezeBtn, "FREEZE")
            isFreezing = false
        end)
    end
end)

TabMovement:CreateParagraph("Infinite Jump", "Jump freely in mid-air with limit constraint.")

TabMovement:CreateToggle("[K] Infinite Jump Toggle", false, "InfJumpEnabled", function(state)
    _G.InfJumpEnabled = state
end)

TabMovement:CreateSlider("Maximum Jump Air-Count", 2, 10, _G.MaxJumpCount, "MaxJumpCount", function(val)
    _G.MaxJumpCount = val
end)

TabMovement:CreateParagraph("Wallhop Properties", "Wallhop physics modifier configurations.")

local WHNormalToggle
WHNormalToggle = TabMovement:CreateToggle("Wallhop Normal", true, "WHNormal", function(state)
    _G.WHNormal = state
    if state and WHInstantToggle then
        WHInstantToggle:Set(false)
    end
end)

local WHInstantToggle
WHInstantToggle = TabMovement:CreateToggle("Wallhop Instant", false, "WHInstant", function(state)
    _G.WHInstant = state
    if state and WHNormalToggle then
        WHNormalToggle:Set(false)
    end
end)

TabMovement:CreateSlider("Wallhop Distance Range", 1, 15, 2.5, "WH_Distance", function(val)
    _G.WallHopDist = val
end)

local AutoJumpPremToggle
AutoJumpPremToggle = TabMovement:CreateToggle("[C] Auto Jump Shift-Lock", false, "AutoJump_Prem", function(state)
    _G.AutoJumpEnabled = state
end)

-- --- TAB 5: VISUALS & CAMERA ---
local TabVisuals = Window:CreateTab("Visuals & Camera", "rbxassetid://4483345998")

-- INTEGRASI AVATAR CHANGER & FE KORBLOX HEADLESS (FROM FREE)
TabVisuals:CreateParagraph("Record Protection & Cosmetics (Local)", "Ubah visual karakter Anda saat merekam layar.")

TabVisuals:CreateButton("Randomize Avatar (Client)", function()
    ApplyRandomAvatar()
end)

TabVisuals:CreateButton("Apply FE Korblox & Headless", function()
    isHeadlessActive = true
    isKorbloxActive = true
    ApplyHeadless()
    ApplyKorblox()
    Library:Notify("Visuals applied", "FE Headless & Korblox berhasil dimuat secara lokal!", 2)
end)

TabVisuals:CreateParagraph("Camera & Resolution Scaling", "Manipulate rendering field of view and resolution stretch scale.")

TabVisuals:CreateToggle("[I] FOV Override Toggle", false, "FOVEnabled", function(state)
    _G.FOVEnabled = state
    if not state then
        Camera.FieldOfView = 70
    end
end)

TabVisuals:CreateSlider("Field Of View Value", 1, 200, _G.FOVValue, "FOVValue", function(val)
    _G.FOVValue = val
end)

TabVisuals:CreateToggle("[Y] Stretch Resolution Toggle", false, "ResolutionEnabled", function(state)
    _G.ResolutionEnabled = state
end)

TabVisuals:CreateSlider("Stretch Resolution Scale", 1, 20, 10, "ResolutionValue", function(val)
    _G.ResolutionValue = val / 10
end)

TabVisuals:CreateParagraph("Faces Custom Mode", "Faces character orientation physics.")

local FaceClassicToggle
FaceClassicToggle = TabVisuals:CreateToggle("Classic Faces Mode", false, "FaceClassic", function(state)
    _G.FaceClassic = state
    if state and FaceProToggle then
        FaceProToggle:Set(false)
    end
end)

local FaceProToggle
FaceProToggle = TabVisuals:CreateToggle("Pro Faces Mode", false, "FacePro", function(state)
    _G.FacePro = state
    if state and FaceClassicToggle then
        FaceClassicToggle:Set(false)
    end
end)

-- --- TAB 6: CROSSHAIR ---
local TabCrosshair = Window:CreateTab("Custom Crosshairs", "rbxassetid://4483345998")

TabCrosshair:CreateParagraph("Custom Rotating Crosshair", "Select rotating center crosshair design style.")

TabCrosshair:CreateToggle("[U] Activate Custom Crosshair", false, "CrosshairEnabled", function(state)
    _G.CrosshairEnabled = state
    CrosshairContainer.Visible = state
    
    pcall(function()
        UserInputService.MouseIconEnabled = not state
    end)

    if state then
        buildCrosshair(CrosshairContainer, _G.CurrentCrosshairStyle, 1.0)
        pcall(function()
            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
                Mouse.Icon = TRANSPARENT_ICON
            end
        end)
    else
        pcall(function() Mouse.Icon = "" end)
    end
end)

local StyleDropdown
StyleDropdown = TabCrosshair:CreateDropdown("Select Crosshair Style", {
    "Style 1", "Style 2", "Style 3", "Style 4", "Style 5",
    "Style 6", "Style 7", "Style 8", "Style 9", "Style 10",
    "Style 11", "Style 12", "Style 13", "Style 14", "Style 15"
}, "Style 1", "CurrentCrosshairStyle", function(option)
    local rawId = tonumber(option:match("%d+"))
    if rawId then
        _G.CurrentCrosshairStyle = rawId
        if _G.CrosshairEnabled then
            buildCrosshair(CrosshairContainer, rawId, 1.0)
        end
    end
end)

TabCrosshair:CreateSlider("Crosshair Rotation Speed", 10, 300, _G.CrosshairRotationSpeed, "CrosshairRotationSpeed", function(val)
    _G.CrosshairRotationSpeed = val
end)

-- --- TAB 7: BUTTON CONTROLS ---
local TabControls = Window:CreateTab("Controls & Scales", "rbxassetid://4483362458")

TabControls:CreateParagraph("External Button Scales (%)", "Adjust the scale of each floating button dynamically.")

TabControls:CreateSlider("External Buttons Size", 10, 200, 100, "ExtScaleValue", function(val)
    _G.ExtScaleValue = val
    UpdateAllButtonsSize(val / 100)
end)

TabControls:CreateParagraph("Window Lock", "Lock window dragging positions.")
TabControls:CreateToggle("Lock Main UI Dragging", false, "DragLocked", function(state)
    Window:SetDragLock(state)
    UpdateAllButtonsDragLock(state)
end)

-- --- TAB 8: CONFIGURATIONS ---
local TabConfig = Window:CreateTab("Configurations", "rbxassetid://6023426915")

TabConfig:CreateParagraph("Configuration Manager", "Manually save or load your configuration settings at any time.")

TabConfig:CreateButton("Save Config Now", function()
    Library:SaveConfig()
end)

TabConfig:CreateButton("Load Config Now", function()
    Library:LoadConfig()
end)

-- ========================================================================
-- [[ EXTERNAL FLOATING UTILITIES INIT (MATCHED TO UI LIBRARY) ]]
-- ========================================================================

-- TOMBOL AUTO FOLLOW (EXTERNAL)
_G.ExtFollowBtn = Library:CreateExternalButton("Follow", "AUTO FOLLOW", UDim2.new(0.5, -235, 0.8, 0), function()
    if not _G.FollowEnabled then return end
    _G.FollowActive = not _G.FollowActive
    if _G.FollowActive then
        SafeSetText(_G.ExtFollowBtn, "FOLLOWING")
    else
        SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
    end
end)
RegisterExternalButton(_G.ExtFollowBtn)

-- TOMBOL FREEZE
local isFreezing = false
local activeAnchoredParts = {}

local function stopFreeze()
    if not isFreezing then return end
    for _, part in ipairs(activeAnchoredParts) do
        pcall(function() part.Anchored = false end)
    end
    table.clear(activeAnchoredParts)
    SafeSetText(_G.ExtFreezeBtn, "FREEZE")
    isFreezing = false
end

_G.ExtFreezeBtn = Library:CreateExternalButton("Freeze", "FREEZE", UDim2.new(0.5, -155, 0.8, 0), function()
    if isFreezing then
        stopFreeze()
    else
        isFreezing = true
        SafeSetText(_G.ExtFreezeBtn, "LAGGING")
        
        local char = LocalPlayer.Character
        table.clear(activeAnchoredParts)
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    part.Anchored = true
                    table.insert(activeAnchoredParts, part)
                end
            end
        end
        
        task.spawn(function()
            local elapsed = 0
            while elapsed < 3.5 and isFreezing do
                task.wait(0.1)
                elapsed = elapsed + 0.1
            end
            if isFreezing then stopFreeze() end
        end)
    end
end)
RegisterExternalButton(_G.ExtFreezeBtn)

-- TOMBOL FLICK
_G.ExtFlickBtn = Library:CreateExternalButton("Flick", "FLICK", UDim2.new(0.5, -75, 0.8, 0), function()
    _G.FlickActive = not _G.FlickActive
    if _G.FlickActive then
        SafeSetText(_G.ExtFlickBtn, "FLICKING")
    else
        SafeSetText(_G.ExtFlickBtn, "FLICK")
    end
end)
RegisterExternalButton(_G.ExtFlickBtn)

-- TOMBOL HOLD BOMB
_G.ExtHoldBtn = Library:CreateExternalButton("Hold", "HOLD BOMB", UDim2.new(0.5, 5, 0.8, 0), function()
    _G.AutoHoldActive = not _G.AutoHoldActive
    if _G.AutoHoldActive then
        SafeSetText(_G.ExtHoldBtn, "HOLDING")
    else
        SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
    end
end)
RegisterExternalButton(_G.ExtHoldBtn)

-- TOMBOL PASS BOMB
_G.ExtPassBtn = Library:CreateExternalButton("Pass", "PASS BOMB", UDim2.new(0.5, 85, 0.8, 0), function()
    triggerManualPass()
end)
RegisterExternalButton(_G.ExtPassBtn)

-- TOMBOL AUTO WALK
_G.ExtAutoWalkBtn = Library:CreateExternalButton("AutoWalk", "AUTO WALK", UDim2.new(0.5, 165, 0.8, 0), function()
    _G.AutoWalkActive = not _G.AutoWalkActive
    if _G.AutoWalkActive then
        SafeSetText(_G.ExtAutoWalkBtn, "WALKING")
    else
        SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
    end
end)
RegisterExternalButton(_G.ExtAutoWalkBtn)

-- TOMBOL AREA CHASE (INTEGRASI NEW)
_G.ExtRangeChaseBtn = Library:CreateExternalButton("RangeChase", "RANGE CHASE", UDim2.new(0.5, -235, 0.72, 0), function()
    _G.RangeChaseEnabled = not _G.RangeChaseEnabled
    if _G.RangeChaseEnabled then
        SafeSetText(_G.ExtRangeChaseBtn, "CHASING")
    else
        SafeSetText(_G.ExtRangeChaseBtn, "RANGE CHASE")
    end
end)
RegisterExternalButton(_G.ExtRangeChaseBtn)

-- TOMBOL TRIP FALL (INTEGRASI NEW)
_G.ExtTripBtn = Library:CreateExternalButton("TripFall", "TRIP FALL", UDim2.new(0.5, -155, 0.72, 0), function()
    _G.TripEnabled = not _G.TripEnabled
    ApplyTrip(_G.TripEnabled)
    if _G.TripEnabled then
        SafeSetText(_G.ExtTripBtn, "TRIPPED")
    else
        SafeSetText(_G.ExtTripBtn, "TRIP FALL")
    end
end)
RegisterExternalButton(_G.ExtTripBtn)


-- Sembunyikan default tombol eksternal saat load script
SafeSetVisible(_G.ExtFollowBtn, false)
SafeSetVisible(_G.ExtFreezeBtn, false)
SafeSetVisible(_G.ExtFlickBtn, false)
SafeSetVisible(_G.ExtHoldBtn, false)
SafeSetVisible(_G.ExtPassBtn, false)
SafeSetVisible(_G.ExtAutoWalkBtn, false)
SafeSetVisible(_G.ExtRangeChaseBtn, false)
SafeSetVisible(_G.ExtTripBtn, false)

-- ========================================================================
-- [[ KEYBOARD QUICK SHORTCUTS CONNECTION ]]
-- ========================================================================
SafeConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Q then 
        _G.FollowEnabled = not _G.FollowEnabled
        if FollowToggle and FollowToggle.Set then
            FollowToggle:Set(_G.FollowEnabled)
        else
            SafeSetVisible(_G.ExtFollowBtn, _G.FollowEnabled)
            if not _G.FollowEnabled then
                _G.FollowActive = false
                SafeSetText(_G.ExtFollowBtn, "AUTO FOLLOW")
            end
        end
        Library:Notify("Follow System", "Status: " .. (_G.FollowEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.Z then 
        _G.FlickEnabled = not _G.FlickEnabled
        SafeSetVisible(_G.ExtFlickBtn, _G.FlickEnabled)
        if not _G.FlickEnabled then
            _G.FlickActive = false
            SafeSetText(_G.ExtFlickBtn, "FLICK")
        end
        Library:Notify("Flick Toggle", "Status: " .. (_G.FlickEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.I then 
        _G.FOVEnabled = not _G.FOVEnabled
        if not _G.FOVEnabled then Camera.FieldOfView = 70 end
        Library:Notify("FOV Override", "Status: " .. (_G.FOVEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.O then 
        _G.FreezeEnabled = not _G.FreezeEnabled
        SafeSetVisible(_G.ExtFreezeBtn, _G.FreezeEnabled)
        Library:Notify("Freeze System", "Status: " .. (_G.FreezeEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.K then 
        _G.InfJumpEnabled = not _G.InfJumpEnabled
        Library:Notify("Inf Jump", "Status: " .. (_G.InfJumpEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.J then 
        _G.AutoHoldEnabled = not _G.AutoHoldEnabled
        SafeSetVisible(_G.ExtHoldBtn, _G.AutoHoldEnabled)
        if not _G.AutoHoldEnabled then
            _G.AutoHoldActive = false
            SafeSetText(_G.ExtHoldBtn, "HOLD BOMB")
        end
        Library:Notify("Auto Hold", "Status: " .. (_G.AutoHoldEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.U then 
        _G.CrosshairEnabled = not _G.CrosshairEnabled
        CrosshairContainer.Visible = _G.CrosshairEnabled
        pcall(function() UserInputService.MouseIconEnabled = not _G.CrosshairEnabled end)
        if _G.CrosshairEnabled then
            buildCrosshair(CrosshairContainer, _G.CurrentCrosshairStyle, 1.0)
        else
            pcall(function() Mouse.Icon = "" end)
        end
        Library:Notify("Crosshair", "Status: " .. (_G.CrosshairEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.Y then 
        _G.ResolutionEnabled = not _G.ResolutionEnabled
        Library:Notify("Resolution", "Status: " .. (_G.ResolutionEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.T then 
        _G.AutoWalkEnabled = not _G.AutoWalkEnabled
        SafeSetVisible(_G.ExtAutoWalkBtn, _G.AutoWalkEnabled)
        if not _G.AutoWalkEnabled then
            _G.AutoWalkActive = false
            SafeSetText(_G.ExtAutoWalkBtn, "AUTO WALK")
        end
        Library:Notify("Auto Walk", "Status: " .. (_G.AutoWalkEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.P then 
        triggerManualPass()
    elseif key == Enum.KeyCode.E then
        _G.PredictEnabled = not _G.PredictEnabled
        Library:Notify("Prediction Mode", "Status: " .. (_G.PredictEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.X then
        _G.HJEnabled = not _G.HJEnabled
        Library:Notify("HJ Toggle", "Status: " .. (_G.HJEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.C then
        _G.AutoJumpEnabled = not _G.AutoJumpEnabled
        if AutoJumpPremToggle and AutoJumpPremToggle.Set then
            AutoJumpPremToggle:Set(_G.AutoJumpEnabled)
        end
        Library:Notify("Auto Jump", "Status: " .. (_G.AutoJumpEnabled and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.G then
        _G.FaceClassic = not _G.FaceClassic
        if _G.FaceClassic then
            _G.FacePro = false
            if FaceProToggle and FaceProToggle.Set then FaceProToggle:Set(false) end
        end
        if FaceClassicToggle and FaceClassicToggle.Set then FaceClassicToggle:Set(_G.FaceClassic) end
        Library:Notify("Classic Face", "Status: " .. (_G.FaceClassic and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.H then
        _G.FacePro = not _G.FacePro
        if _G.FacePro then
            _G.FaceClassic = false
            if FaceClassicToggle and FaceClassicToggle.Set then FaceClassicToggle:Set(false) end
        end
        if FaceProToggle and FaceProToggle.Set then FaceProToggle:Set(_G.FacePro) end
        Library:Notify("Pro Face", "Status: " .. (_G.FacePro and "ON" or "OFF"), 1.5)
    end
end)

-- Character Added event connection to safely reset state
SafeConnect(LocalPlayer.CharacterAdded, function()
    lastHadBomb = false
    retreatTimer = 0
    autoWalkRetreatTimer = 0
    targetMemory = 0
    bombTimer = 0
    isTweening = false
    _G.CurrentJumpCount = 0
    lastShouldFollow = false
end)

print("[LOUIS HUB PREMIUM EDITION]: TBD Loader Ready to Use.")

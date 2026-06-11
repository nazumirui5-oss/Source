-- ========================================================================
-- [[ LOUIS HUB - MM2 FUNCTIONAL EDITION (INTEGRATED & OPTIMIZED) ]]
-- ========================================================================

-- Macro definition for local compatibility before obfuscation
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
-- [[ INTERNAL STATE & PHYSICS VARIABLES ]]
-- ========================================================
local SavedCFrame = nil
local SelectedPlayer = nil
local originalVelocity = Vector3.new(0, 0, 0)
local originalRotVelocity = Vector3.new(0, 0, 0)
local FlingFailsafeActive = false
local OriginalCFrameBeforeFling = nil
local SafePlatform = nil

-- Additional State For Coin Farm Underground Idle & Timer
local WasUnderground = false
local PreFarmCFrame = nil
local CollectedCoinsCount = 0
local CoinFarmTimeLeft = 60
local IsFlingingFromFarm = false
local FlingDurationLeft = 12

-- ========================================================================
-- [[ EXTERNAL BUTTON TEXT CUSTOMIZATION ]]
-- ========================================================================
local ExtButtonTexts = {
    Aimbot = "AIM",
    GrabGun = "GRAB",
    DoubleJump = "JUMP",
    Spin = "SPIN",
    TpSheriff = "SHERIFF",
    TpMurder = "MURDER",
    FlingMurder = "FLING_M",
    FlingSheriff = "FLING_S",
    SavePos = "SAVE_POS",
    LoadPos = "LOAD_POS",
    KillAll = "KILL_ALL",
    Bhop = "BHOP",
    SafeZone = "SAFE_ZONE",
    FlingGrab = "FS_GRAB",
    JumpBoost = "J_BOOST",
    SilentAim = "S_AIM"
}

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

-- 3. INTERNAL FEATURE CONFIGURATION (MM2 & MOVEMENT)
local Settings = {
    CameraAimbot = false,
    HitboxExpander = false,
    HitboxVisual = true,
    ESP = false,
    TracersESP = false,
    NameESP = false,
    EspInnocent = true,
    EspSheriff = true,
    EspMurderer = true,
    CoinESP = false,
    AutoGrabGun = false, 
    TargetPart = "HumanoidRootPart",
    HitboxSize = 20,
    FOVSize = 150,
    HideFOVCircle = false,
    AutoFlingMurder = false,
    AutoFlingSheriff = false,
    SpeedWalkEnabled = false,
    SpeedWalkValue = 16,
    AimbotExtEnabled = false,
    GrabGunExtEnabled = false,
    CameraFOVEnabled = false,
    CameraFOVValue = 70,
    FlyEnabled = false,
    FlySpeedValue = 50,
    JumpPowerEnabled = false,
    JumpPowerValue = 50,
    NoclipEnabled = false,
    InvisibleEnabled = false,
    KillAuraEnabled = false,
    KillAuraRadius = 15,
    DoubleJumpEnabled = false,
    DoubleJumpExtEnabled = false,
    DragLocked = false,
    SpinEnabled = false,
    SpinPower = 30,
    SpinExtEnabled = false,
    
    -- Coin Farm Configuration
    CoinFarmEnabled = false,
    CoinFarmTweenSpeed = 90, -- Default tween speed limited to max 90
    CoinUpTweenSpeed = 50,   -- Vertical collection speed
    CoinMaxDistance = 300,   -- Maximum coin detection range
    CoinFarmTimerValue = 1,  -- Default: 1 Minute

    -- Additional Integration Features
    InfiniteJump = false,
    AntiVoid = false,
    AntiFling = false,
    TouchFling = false,
    FlingPower = 100,
    
    -- Teleport & External Button Configuration
    TpSheriffExtEnabled = false,
    TpMurderExtEnabled = false,
    FlingMurderExtEnabled = false,
    FlingSheriffExtEnabled = false,
    PosExtEnabled = false,
    FlingGrabExtEnabled = false,

    -- Imported Settings
    AutoKillAll = false,
    SafeZoneEnabled = false,
    AutoBhopEnabled = false,
    EarlyRoleDetect = true,

    -- Custom Jump Boost & Silent Aim Configuration
    JumpBoostEnabled = false,
    JumpBoostValue = 35,
    SilentAimEnabled = false,
    SilentAimExtEnabled = false
}

local OriginalFOV = Camera.FieldOfView

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

local function SafeDrawing(className)
    local drawing = Drawing.new(className)
    table.insert(_G.LouisDrawings, drawing)
    return drawing
end

-- Clean billboard Name ESP from previous executions
for _, player in ipairs(Players:GetPlayers()) do
    pcall(function()
        if player.Character then
            local head = player.Character:FindFirstChild("Head")
            local billboard = head and head:FindFirstChild("MM2_NameESP")
            if billboard then billboard:Destroy() end
        end
    end)
end

-- ========================================================
-- [[ OPTIMIZATION: DYNAMIC INSTANCE CACHING ]]
-- ========================================================
local CoinCache = {}
local GunDropCache = {}

local function OnDescendantAdded(desc)
    local nameLower = desc.Name:lower()
    if nameLower == "gundrop" then
        table.insert(GunDropCache, desc)
    elseif desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent.Name:lower():find("gun") then
        table.insert(GunDropCache, desc.Parent)
    elseif nameLower:find("coin") or desc.Name == "Coin_Server" then
        table.insert(CoinCache, desc)
    end
end

local function OnDescendantRemoving(desc)
    local idx = table.find(GunDropCache, desc)
    if idx then table.remove(GunDropCache, idx) end
    local idx2 = table.find(CoinCache, desc)
    if idx2 then table.remove(CoinCache, idx2) end
end

pcall(function()
    for _, desc in ipairs(workspace:GetDescendants()) do
        OnDescendantAdded(desc)
    end
end)

SafeConnect(workspace.DescendantAdded, OnDescendantAdded)
SafeConnect(workspace.DescendantRemoving, OnDescendantRemoving)

-- ========================================================
-- [[ GRAPHICS FEATURES: POTATO OPTIMIZATION ]]
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

-- Advanced Lag Reduction & Optimization
local function CleanLagAndOptimize()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        settings().Rendering.QualityLevel = 1
        
        -- Disable post-processing graphics effects
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
                effect.Enabled = false
            end
        end
        
        -- Override material properties
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("MeshPart") then
                v.Material = Enum.Material.SmoothPlastic
                v.CastShadow = false
                v.Reflectance = 0
                if v:IsA("MeshPart") then
                    v.TextureID = ""
                end
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v:Destroy()
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Sparkles") or v:IsA("Fire") or v:IsA("Smoke") then
                v.Enabled = false
            end
        end
    end)
    Library:Notify("FPS Optimization", "Engine optimized successfully!", 3)
end

-- ========================================================
-- [[ AUTO REJOIN FUNCTIONALITY ]]
-- ========================================================
task.spawn(function()
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    local CoreGui = game:GetService("CoreGui")
    
    -- Method 1: Listen to CoreGui error panels
    pcall(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui"):WaitForChild("promptOverlay")
        promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                task.wait(1.5)
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
    end)
    
    -- Method 2: Listen to system errors directly
    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function()
            task.wait(1.5)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
end)

-- ========================================================
-- [[ POSITION & SAFE ZONE UTILITIES ]]
-- ========================================================
local function SavePosition()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        SavedCFrame = root.CFrame
    end
end

local function LoadSavedPosition()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and SavedCFrame then
        root.CFrame = SavedCFrame
    end
end

local function ToggleSafeZone(state)
    Settings.SafeZoneEnabled = state
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if state then
        if not SafePlatform then
            SafePlatform = Instance.new("Part")
            SafePlatform.Size = Vector3.new(20, 1, 20)
            SafePlatform.Position = Vector3.new(0, 1000, 0)
            SafePlatform.Anchored = true
            SafePlatform.CanCollide = true
            SafePlatform.Parent = workspace
        end
        if root then
            SavePosition()
            root.CFrame = SafePlatform.CFrame * CFrame.new(0, 3, 0)
        end
    else
        if SafePlatform then
            SafePlatform:Destroy()
            SafePlatform = nil
        end
        if SavedCFrame and root then
            root.CFrame = SavedCFrame
        end
    end
end

-- ========================================================
-- [[ MM2 ROLE DETECTION LOGIC ]]
-- ========================================================
local function GetMM2Role(Player)
    if not Player or not Player.Character then return "Innocent" end
    local Character = Player.Character
    local Backpack = Player:FindFirstChild("Backpack")
    
    if Character:FindFirstChild("Knife") or (Backpack and Backpack:FindFirstChild("Knife")) then
        return "Murderer"
    elseif Character:FindFirstChild("Gun") or (Backpack and Backpack:FindFirstChild("Gun")) then
        return "Sheriff"
    end
    return "Innocent"
end

local function GetTargetByRole(roleName)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and GetMM2Role(p) == roleName then
                return p
            end
        end
    end
    return nil
end

local function GetTargetForMurderer()
    local Target = nil
    local ShortestDistance = math.huge
    local CenterScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local Root = v.Character:FindFirstChild("HumanoidRootPart")
            local Hum = v.Character:FindFirstChildOfClass("Humanoid")
            
            if Root and Hum and Hum.Health > 0 then
                local role = GetMM2Role(v)
                if role == "Innocent" or role == "Sheriff" then
                    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
                    if OnScreen then
                        local Magnitude = (Vector2.new(ScreenPos.X, ScreenPos.Y) - CenterScreen).Magnitude
                        if Magnitude <= Settings.FOVSize and Magnitude < ShortestDistance then
                            ShortestDistance = Magnitude
                            Target = Root
                        end
                    end
                end
            end
        end
    end
    return Target
end

local function GetTargetForInnocentOrSheriff()
    local Target = nil
    local ShortestDistance = math.huge
    local CenterScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local Root = v.Character:FindFirstChild("HumanoidRootPart")
            local Hum = v.Character:FindFirstChildOfClass("Humanoid")
            
            if Root and Hum and Hum.Health > 0 then
                local role = GetMM2Role(v)
                if role == "Murderer" then
                    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
                    if OnScreen then
                        local Magnitude = (Vector2.new(ScreenPos.X, ScreenPos.Y) - CenterScreen).Magnitude
                        if Magnitude <= Settings.FOVSize and Magnitude < ShortestDistance then
                            ShortestDistance = Magnitude
                            Target = Root
                        end
                    end
                end
            end
        end
    end
    return Target
end

-- Teleport to an innocent player located furthest away from the Murderer
local function TeleportToSafeInnocent()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local murderer = GetTargetByRole("Murderer")
    local bestTarget = nil
    local maxDistance = -1
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local role = GetMM2Role(p)
            if role == "Innocent" then
                local tRoot = p.Character.HumanoidRootPart
                local dist = 1000 -- Safe high-value fallback
                if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                    dist = (tRoot.Position - murderer.Character.HumanoidRootPart.Position).Magnitude
                end
                
                if dist > maxDistance then
                    maxDistance = dist
                    bestTarget = tRoot
                end
            end
        end
    end
    
    if bestTarget then
        root.CFrame = bestTarget.CFrame * CFrame.new(0, 0, 3)
    end
end

-- ========================================================
-- [[ FEATURE 1 LOGIC: CAMERA AIMBOT ]]
-- ========================================================
local FOVCircle = SafeDrawing("Circle")
FOVCircle.Color = Color3.fromRGB(255, 0, 255)
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 60
FOVCircle.Radius = Settings.FOVSize
FOVCircle.Filled = false
FOVCircle.Visible = false

SafeConnect(RunService.RenderStepped, LPH_NO_VIRTUALIZE(function()
    if Settings.CameraAimbot and not Settings.HideFOVCircle then
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Radius = Settings.FOVSize
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end))

local function GetPredictedPosition(targetPart)
    if not targetPart then return nil end
    local BulletSpeed = 230
    local distance = (Camera.CFrame.Position - targetPart.Position).Magnitude
    local travelTime = distance / BulletSpeed
    local ping = 0.05
    pcall(function() ping = LocalPlayer:GetNetworkPing() end)
    local totalTime = travelTime + ping
    
    local velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.new()
    local predictedPos = targetPart.Position + (velocity * totalTime)
    return predictedPos
end

SafeConnect(RunService.RenderStepped, LPH_NO_VIRTUALIZE(function()
    if Settings.CameraAimbot and LocalPlayer.Character then
        local HoldsGun = LocalPlayer.Character:FindFirstChild("Gun")
        local HoldsKnife = LocalPlayer.Character:FindFirstChild("Knife")
        
        if (HoldsGun and HoldsGun:IsA("Tool")) or (HoldsKnife and HoldsKnife:IsA("Tool")) then
            local MyRole = GetMM2Role(LocalPlayer)
            local TargetPart = (MyRole == "Murderer") and GetTargetForMurderer() or GetTargetForInnocentOrSheriff()
            
            if TargetPart then
                local PredictedPos = GetPredictedPosition(TargetPart)
                if PredictedPos then
                    Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, PredictedPos)
                end
            end
        end
    end
end))

-- ========================================================
-- [[ SHERIFF SILENT AIM METAMETHOD HOOKS ]]
-- ========================================================
-- CATATAN: Hook __index (Mouse.Hit) telah dihapus dari versi ini untuk mencegah kamera membeku / mengunci,
-- karena manipulasi arah tembakan sekarang ditangani secara efisien melalui jaringan (__namecall).

pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if not checkcaller() and Settings.SilentAimEnabled then
            -- DYNAMIC DETECTOR (ANTI-RENAME): Mengubah arah tembakan langsung pada RemoteFunction milik Gun
            if method == "InvokeServer" and self:IsA("RemoteFunction") and self.Parent and self.Parent:IsA("Tool") and self.Parent.Name == "Gun" then
                local targetPlayer = GetTargetByRole("Murderer") or SelectedPlayer
                local targetPart = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    -- Parameter ke-2 adalah koordinat Vector3 tujuan tembakan
                    args[2] = targetPart.Position
                    return oldNamecall(self, unpack(args))
                end
            end

            -- Mengubah arah Raycast agar visual garis peluru di layar client sejajar dengan target
            if method == "FindPartOnRayWithIgnoreList" or method == "Raycast" or method == "FindPartOnRay" then
                local targetPlayer = GetTargetByRole("Murderer") or SelectedPlayer
                local targetPart = targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    if method == "Raycast" then
                        local origin = args[1]
                        local direction = (targetPart.Position - origin).Unit * 1000
                        args[2] = direction
                        return oldNamecall(self, unpack(args))
                    elseif method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" then
                        local ray = args[1]
                        local origin = ray.Origin
                        local direction = (targetPart.Position - origin).Unit * 1000
                        args[1] = Ray.new(origin, direction)
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end)

local function TriggerSilentAimShot()
    local target = GetTargetByRole("Murderer") or SelectedPlayer
    if not target then
        Library:Notify("Silent Aim", "No target found (Murderer or Selected Player).", 2)
        return
    end
    
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local gun = char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun"))
    
    if not gun then
        Library:Notify("Silent Aim", "Gun not found in your inventory.", 2)
        return
    end
    
    -- Temporarily force Silent Aim on
    local oldSilentAimState = Settings.SilentAimEnabled
    Settings.SilentAimEnabled = true
    
    -- Force equip weapon
    if gun.Parent == backpack then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(gun)
        else
            gun.Parent = char
        end
    end
    
    task.wait(0.1) -- wait for weapon equip
    
    if gun.Parent == char then
        gun:Activate()
        Library:Notify("Silent Aim Shot", "Fired bullet towards " .. target.Name, 2)
    end
    
    -- Cleanly transition state
    task.spawn(function()
        task.wait(0.5)
        Settings.SilentAimEnabled = oldSilentAimState
    end)
end

-- ========================================================
-- [[ FEATURE 2 LOGIC: DOUBLE JUMP & INFINITE JUMP ]]
-- ========================================================
local HasDoubleJumped = false
local CanDoubleJump = false

local function SetupDoubleJump(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    local stateConn = humanoid.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Landed then
            HasDoubleJumped = false
            CanDoubleJump = false
        elseif new == Enum.HumanoidStateType.Freefall then
            task.wait(0.12)
            if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
                CanDoubleJump = true
            end
        end
    end)
    table.insert(_G.LouisConnections, stateConn)
end

local DoubleJumpReq = UserInputService.JumpRequest:Connect(function()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    
    if humanoid and Settings.InfiniteJump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    
    if humanoid and root and humanoid.Health > 0 and Settings.DoubleJumpEnabled then
        if CanDoubleJump and not HasDoubleJumped then
            HasDoubleJumped = true
            root.Velocity = Vector3.new(root.Velocity.X, humanoid.JumpPower * 1.15, root.Velocity.Z)
        end
    end
end)
table.insert(_G.LouisConnections, DoubleJumpReq)

-- Bunnyhop Logic Loop
SafeConnect(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function()
    if Settings.AutoBhopEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.MoveDirection.Magnitude > 0 then
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end))

-- ========================================================
-- [[ FEATURE 3 LOGIC: GUN GRABBER ENGINE ]]
-- ========================================================
local IsGrabbing = false
local function SafeInstantTween(targetPart)
    if not targetPart or IsGrabbing then return end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if root and humanoid and humanoid.Health > 0 then
        IsGrabbing = true
        local originalCFrame = root.CFrame
        local targetCFrame = targetPart.CFrame + Vector3.new(0, 1.5, 0)
        
        root.CFrame = targetCFrame
        
        local timeout = 0
        while timeout < 1.5 do
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if character:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
                break
            end
            root.CFrame = targetCFrame
            task.wait(0.05)
            timeout = timeout + 0.05
        end
        
        if character and character:FindFirstChild("HumanoidRootPart") then
            root.CFrame = originalCFrame
        end
        
        task.wait(0.3)
        IsGrabbing = false
    end
end

local function ScanForDroppedGun()
    for _, object in ipairs(GunDropCache) do
        if object and object.Parent then
            local targetPart = object:IsA("BasePart") and object or object:FindFirstChildOfClass("BasePart")
            if targetPart then return targetPart end
        end
    end
    return nil
end

local function ApplyGunOutline(gunPart)
    if not gunPart or gunPart:FindFirstChild("LouisGunOutline") then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "LouisGunOutline"
    highlight.FillColor = Color3.fromRGB(0, 100, 255)
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Adornee = gunPart
    highlight.Parent = gunPart
end

local function ClearGunOutlines()
    for _, object in ipairs(workspace:GetDescendants()) do
        if object.Name == "LouisGunOutline" then object:Destroy() end
    end
end

task.spawn(function()
    while true do
        if Settings.AutoGrabGun or Settings.ESP then
            local activeGun = ScanForDroppedGun()
            if activeGun then
                if Settings.ESP then ApplyGunOutline(activeGun) end
                if Settings.AutoGrabGun then SafeInstantTween(activeGun) end
            end
        else
            ClearGunOutlines()
        end
        task.wait(0.5) -- Optimized: Reduced scanning rate to save CPU
    end
end)

-- ========================================================================
-- [[ COIN DETECTION AND FARM ENGINE ]]
-- ========================================================================
local CollectedCoins = {}
local ScannedCoins = {}
local CachedCoinContainer = nil

task.spawn(function()
    while true do
        task.wait(10)
        table.clear(CollectedCoins)
    end
end)

local function GetCoinContainer()
    if CachedCoinContainer and CachedCoinContainer.Parent then
        return CachedCoinContainer
    end
    CachedCoinContainer = nil
    
    local container = Workspace:FindFirstChild("CoinContainer", true)
    if container then
        CachedCoinContainer = container
        return container
    end
    return nil
end

local function FindCoinBasePart(coinServer)
    if not coinServer then return nil end
    if coinServer:IsA("BasePart") then
        return coinServer
    end
    local mainCoin = coinServer:FindFirstChild("MainCoin", true)
    if mainCoin and mainCoin:IsA("BasePart") then
        return mainCoin
    end
    local coinPart = coinServer:FindFirstChild("Coin", true)
    if coinPart and coinPart:IsA("BasePart") then
        return coinPart
    end
    local coinVisual = coinServer:FindFirstChild("CoinVisual", true)
    if coinVisual then
        if coinVisual:IsA("BasePart") then
            return coinVisual
        end
        local visualChild = coinVisual:FindFirstChild("MainCoin") or coinVisual:FindFirstChild("Coin") or coinVisual:FindFirstChildOfClass("BasePart")
        if visualChild and visualChild:IsA("BasePart") then
            return visualChild
        end
    end
    local anyPart = coinServer:FindFirstChildOfClass("BasePart") or coinServer:FindFirstChildOfClass("MeshPart")
    if anyPart then
        return anyPart
    end
    return nil
end

-- Optimized deep scanning by utilizing pre-scanned CoinCache
local function DeepScanWorkspaceCoins()
    table.clear(ScannedCoins)
    for _, coin in ipairs(CoinCache) do
        if coin and coin.Parent then
            local targetPart = FindCoinBasePart(coin)
            if targetPart then
                table.insert(ScannedCoins, targetPart)
            end
        end
    end
end

local function IsAnotherPlayerNear(coinPart)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if root and humanoid and humanoid.Health > 0 then
                local distance = (root.Position - coinPart.Position).Magnitude
                local role = GetMM2Role(player)
                
                if role == "Murderer" then
                    if distance < 35 then
                        return true
                    end
                else
                    if distance < 7 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function GetNearestCoin()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    DeepScanWorkspaceCoins()
    
    local closestCoin = nil
    local shortestDistance = math.huge
    
    for _, coinPart in ipairs(ScannedCoins) do
        if coinPart and coinPart.Parent and not CollectedCoins[coinPart] then
            if not IsAnotherPlayerNear(coinPart) then
                local distance = (root.Position - coinPart.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestCoin = coinPart
                end
            end
        end
    end
    
    if closestCoin then
        local distance = (root.Position - closestCoin.Position).Magnitude
        if distance <= Settings.CoinMaxDistance then
            return closestCoin
        end
    end
    
    return nil
end

local currentCoinTween = nil
local function CollectCoin(coinPart)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not coinPart then return end
    
    CollectedCoins[coinPart] = true
    if coinPart.Parent then
        CollectedCoins[coinPart.Parent] = true
    end

    local safeUnderCFrame = coinPart.CFrame * CFrame.new(0, -6.5, 0)
    local grabCFrame = coinPart.CFrame

    local distance = (root.Position - safeUnderCFrame.Position).Magnitude
    local speed = Settings.CoinFarmTweenSpeed or 90
    local tweenTime = distance / speed
    
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    root.Anchored = true

    if currentCoinTween then pcall(function() currentCoinTween:Cancel() end) end
    
    local tweenInfo1 = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
    currentCoinTween = TweenService:Create(root, tweenInfo1, {CFrame = safeUnderCFrame})
    currentCoinTween:Play()
    
    local completed = false
    local conn
    conn = currentCoinTween.Completed:Connect(function()
        completed = true
        if conn then conn:Disconnect() end
    end)
    
    while not completed and Settings.CoinFarmEnabled do
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        task.wait()
    end
    if conn then conn:Disconnect() end
    
    if Settings.CoinFarmEnabled and coinPart and coinPart.Parent then
        for _, child in ipairs(character:GetDescendants()) do
            if child:IsA("BasePart") then child.CanCollide = false end
        end

        local upSpeed = Settings.CoinUpTweenSpeed or 50
        local upTweenTime = math.clamp(6.5 / upSpeed, 0.05, 0.5)

        root.Anchored = true
        local upTween = TweenService:Create(root, TweenInfo.new(upTweenTime, Enum.EasingStyle.Linear), {CFrame = grabCFrame})
        upTween:Play()
        upTween.Completed:Wait()
        
        root.Anchored = false
        local startTime = os.clock()
        local initiallyExists = (coinPart and coinPart.Parent) and true or false
        while coinPart and coinPart.Parent and (os.clock() - startTime < 0.35) and Settings.CoinFarmEnabled do
            root.CFrame = grabCFrame
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            task.wait(0.01)
        end
        
        root.Anchored = true
        local downTween = TweenService:Create(root, TweenInfo.new(upTweenTime, Enum.EasingStyle.Linear), {CFrame = safeUnderCFrame})
        downTween:Play()
        downTween.Completed:Wait()

        task.wait(0.15)

        if initiallyExists and (not coinPart or not coinPart.Parent) then
            CollectedCoinsCount = CollectedCoinsCount + 1
        end
    end
    
    if currentCoinTween then currentCoinTween:Cancel() end
    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    task.wait(0.05)
end

-- ========================================================================
-- [[ COIN FARM DETECTOR BACK-THREAD TIMER SYSTEM ]]
-- ========================================================================
task.spawn(function()
    while true do
        task.wait(1)
        if Settings.CoinFarmEnabled then
            if not IsFlingingFromFarm then
                local nearest = GetNearestCoin()
                if nearest then
                    if CoinFarmTimeLeft > 0 then
                        CoinFarmTimeLeft = CoinFarmTimeLeft - 1
                        if CoinFarmTimeLeft % 10 == 0 and CoinFarmTimeLeft > 0 then
                            Library:Notify("Coin Farm Timer", "Fling Murderer in: " .. CoinFarmTimeLeft .. " seconds", 2)
                        end
                    else
                        IsFlingingFromFarm = true
                        FlingDurationLeft = 12
                        Library:Notify("Farm Fling Status", "Time is up! Launching to Fling Murderer for 12 seconds.", 3)
                    end
                end
            else
                if FlingDurationLeft > 0 then
                    FlingDurationLeft = FlingDurationLeft - 1
                else
                    IsFlingingFromFarm = false
                    CoinFarmTimeLeft = Settings.CoinFarmTimerValue * 60
                    Library:Notify("Farm Resumed", "Fling completed! Resuming coin collection.", 3)
                end
            end
        else
            CoinFarmTimeLeft = Settings.CoinFarmTimerValue * 60
            IsFlingingFromFarm = false
        end
    end
end)

-- MAIN COIN FARMING LOOP
task.spawn(LPH_NO_VIRTUALIZE(function()
    while true do
        if Settings.CoinFarmEnabled then
            if not PreFarmCFrame and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                PreFarmCFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
            end

            if IsFlingingFromFarm then
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local murderer = GetTargetByRole("Murderer")
                
                if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
                    local mRoot = murderer.Character.HumanoidRootPart
                    local mHum = murderer.Character:FindFirstChildOfClass("Humanoid")
                    
                    if mHum and mHum.Health > 0 and root then
                        root.Anchored = false
                        Settings.TouchFling = true
                        
                        for _, child in ipairs(LocalPlayer.Character:GetDescendants()) do
                            if child:IsA("BasePart") then child.CanCollide = true end
                        end
                        
                        local multiplier = Settings.FlingPower * 1000
                        root.AssemblyLinearVelocity = Vector3.new(multiplier, multiplier, multiplier)
                        root.AssemblyAngularVelocity = Vector3.new(0, multiplier, 0)
                        root.CFrame = mRoot.CFrame * CFrame.new(math.random(-1, 1) * 0.1, 0, math.random(-1, 1) * 0.1)
                    end
                    task.wait(0.02)
                else
                    Settings.TouchFling = false
                    if root then
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        root.Anchored = true
                        if not WasUnderground then
                            root.CFrame = root.CFrame * CFrame.new(0, -6.5, 0)
                            WasUnderground = true
                        end
                    end
                    task.wait(0.5)
                end
            else
                Settings.TouchFling = false
                local nearest = GetNearestCoin()
                if nearest then
                    WasUnderground = true
                    CollectCoin(nearest)
                else
                    local character = LocalPlayer.Character
                    local root = character and character:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        
                        if not WasUnderground then
                            root.CFrame = root.CFrame * CFrame.new(0, -6.5, 0)
                            WasUnderground = true
                        end
                        root.Anchored = true
                    end
                    task.wait(0.25)
                end
            end
        else
            if WasUnderground then
                Settings.TouchFling = false
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Anchored = false
                    if PreFarmCFrame then
                        root.CFrame = PreFarmCFrame
                    else
                        root.CFrame = root.CFrame * CFrame.new(0, 7.5, 0)
                    end
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
                WasUnderground = false
                PreFarmCFrame = nil
            end
            task.wait(0.5)
        end
    end
end))

-- ========================================================
-- [[ FEATURE 4 LOGIC: KILL AURA, AUTO KILL ALL, TELEPORT ]]
-- ========================================================
task.spawn(function()
    while true do
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if Settings.KillAuraEnabled and character and root then
            local knife = character:FindFirstChild("Knife")
            if knife and GetMM2Role(LocalPlayer) == "Murderer" then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = p.Character.HumanoidRootPart
                        local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if tHum and tHum.Health > 0 then
                            local distance = (root.Position - tRoot.Position).Magnitude
                            if distance <= Settings.KillAuraRadius then
                                pcall(function()
                                    knife:Activate()
                                    firetouchinterest(tRoot, knife.Handle, 0)
                                    firetouchinterest(tRoot, knife.Handle, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- AUTO-KILL ALL LOGIC
task.spawn(function()
    while true do
        task.wait(0.1)
        if Settings.AutoKillAll and LocalPlayer.Character and GetMM2Role(LocalPlayer) == "Murderer" then
            local knife = LocalPlayer.Character:FindFirstChild("Knife") or (LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild("Knife"))
            if knife then
                if not LocalPlayer.Character:FindFirstChild("Knife") then
                    knife.Parent = LocalPlayer.Character
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = p.Character.HumanoidRootPart
                        local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if tHum and tHum.Health > 0 then
                            pcall(function()
                                LocalPlayer.Character.HumanoidRootPart.CFrame = tRoot.CFrame * CFrame.new(0, 0, -1)
                                knife:Activate()
                                firetouchinterest(tRoot, knife.Handle, 0)
                                firetouchinterest(tRoot, knife.Handle, 1)
                            end)
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end
end)

local function TeleportAllPlayersToMe()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not root or GetMM2Role(LocalPlayer) ~= "Murderer" then return end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local tRoot = p.Character.HumanoidRootPart
            local tHum = p.Character:FindFirstChildOfClass("Humanoid")
            if tHum and tHum.Health > 0 then
                pcall(function() tRoot.CFrame = root.CFrame * CFrame.new(0, 0, -2) end)
            end
        end
    end
end

-- ========================================================================
-- [[ COIN ESP ENGINE ]]
-- ========================================================================
local function ClearCoinESP()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "LouisCoinESP" then 
            pcall(function() v:Destroy() end) 
        end
    end
end

local function ApplyCoinESP()
    if not Settings.CoinESP then 
        ClearCoinESP()
        return 
    end
    
    DeepScanWorkspaceCoins()

    for _, coinPart in ipairs(ScannedCoins) do
        if coinPart and coinPart.Parent and not coinPart:FindFirstChild("LouisCoinESP") then
            local box = Instance.new("BoxHandleAdornment")
            box.Name = "LouisCoinESP"
            box.Size = coinPart.Size + Vector3.new(0.1, 0.1, 0.1)
            box.Color3 = Color3.fromRGB(255, 215, 0)
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0.5
            box.Adornee = coinPart
            box.Parent = coinPart
        end
    end
end

task.spawn(function()
    while true do
        if Settings.CoinESP then
            pcall(ApplyCoinESP)
        end
        task.wait(1.5)
    end
end)

-- ========================================================
-- [[ FEATURE 5 LOGIC: TELEPORTS & TARGET SELECTIONS ]]
-- ========================================================
local function TeleportToSheriff()
    local target = GetTargetByRole("Sheriff")
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        root.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
    end
end

local function TeleportToMurderer()
    local target = GetTargetByRole("Murderer")
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        root.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
    end
end

local function TpToPlayer(targetPlayer)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
    end
end

-- ========================================================================
-- [[ OPTIMIZED TARGET FLING ]]
-- ========================================================================
local function FlingPlayer(targetPlayer)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local oldPos = root.CFrame
        local targetRoot = targetPlayer.Character.HumanoidRootPart
        local targetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        
        SavePosition()
        local originalFlingState = Settings.TouchFling
        Settings.TouchFling = true
        
        task.spawn(function()
            for i = 1, 150 do
                if not targetRoot or not targetHum or targetHum.Health <= 0 or not root or not char:FindFirstChild("HumanoidRootPart") then
                    break
                end
                root.CFrame = targetRoot.CFrame * CFrame.new(math.random(-1, 1) * 0.1, 0, math.random(-1, 1) * 0.1)
                task.wait(0.02)
            end
            Settings.TouchFling = originalFlingState
            root.CFrame = oldPos
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
    end
end

-- ========================================================================
-- [[ FLING SHERIFF + GRAB GUN (UPDATED SAFE TELEPORT) ]]
-- ========================================================================
local function SafeFlingSheriffAndGrab()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then 
        Library:Notify("Fling + Grab", "Character not ready or is dead.", 2)
        return 
    end
    
    local target = GetTargetByRole("Sheriff")
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        Library:Notify("Fling + Grab", "Sheriff not found or already eliminated.", 2.5)
        return
    end
    
    local targetRoot = target.Character.HumanoidRootPart
    local targetHum = target.Character:FindFirstChildOfClass("Humanoid")
    
    local originalPos = root.CFrame
    local originalFlingState = Settings.TouchFling
    
    Library:Notify("Fling + Grab", "Starting Fling Sheriff... Stay safe.", 2)
    
    Settings.TouchFling = true
    
    local flingSuccess = false
    local startTime = os.clock()
    while os.clock() - startTime < 3.5 do
        if not targetRoot or not targetHum or targetHum.Health <= 0 then
            flingSuccess = true
            break
        end
        if not root or humanoid.Health <= 0 then
            break
        end
        
        if root.Position.Y < -80 then
            root.CFrame = originalPos
            task.wait(0.1)
        end
        
        for _, child in ipairs(char:GetDescendants()) do
            if child:IsA("BasePart") then child.CanCollide = false end
        end
        
        root.CFrame = targetRoot.CFrame * CFrame.new(math.random(-1, 1) * 0.12, 0, math.random(-1, 1) * 0.12)
        task.wait(0.02)
    end
    
    Settings.TouchFling = originalFlingState
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    
    -- Teleport safely to an innocent player far from the murderer
    TeleportToSafeInnocent()
    task.wait(0.1)
    
    Library:Notify("Fling + Grab", "Fling finished! Scanning for dropped gun...", 2)
    local grabStartTime = os.clock()
    local gunGrabbed = false
    while os.clock() - grabStartTime < 5 do
        local activeGun = ScanForDroppedGun()
        if activeGun then
            Library:Notify("Fling + Grab", "Dropped gun detected! Snatching immediately...", 1.5)
            
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("BasePart") then child.CanCollide = false end
            end
            
            root.CFrame = activeGun.CFrame + Vector3.new(0, 1.5, 0)
            task.wait(0.3)
            
            -- Teleport to safe innocent
            TeleportToSafeInnocent()
            gunGrabbed = true
            break
        end
        task.wait(0.1)
    end
    
    TeleportToSafeInnocent()
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    
    if gunGrabbed then
        Library:Notify("Fling + Grab", "Successfully neutralized Sheriff and retrieved the Gun!", 3)
    else
        Library:Notify("Fling + Grab", "Sheriff neutralized, but Gun failed to collect or did not drop.", 3)
    end
end

-- ========================================================================
-- [[ MOBILITY PHYSICS ENGINE (FLY, NOCLIP, SPIN, FLING, SPEED, JUMP) ]]
-- ========================================================================
local SpinVelocity
local FlingVelocity

-- Centralized Noclip Management
SafeConnect(RunService.Stepped, LPH_NO_VIRTUALIZE(function()
    if (Settings.NoclipEnabled or Settings.CoinFarmEnabled or IsGrabbing) and LocalPlayer.Character then
        local isFlingingInFarm = Settings.CoinFarmEnabled and IsFlingingFromFarm
        if not isFlingingInFarm then
            for _, child in ipairs(LocalPlayer.Character:GetDescendants()) do
                if child:IsA("BasePart") and child.CanCollide then 
                    child.CanCollide = false 
                end
            end
        end
    end
end))

local function ToggleNoclip(state)
    Settings.NoclipEnabled = state
    if not state and LocalPlayer.Character and not Settings.CoinFarmEnabled then
        for _, child in ipairs(LocalPlayer.Character:GetDescendants()) do
            if child:IsA("BasePart") then child.CanCollide = true end
        end
    end
end

-- HEARTBEAT PHYSICS LOOP (Optimized property settings)
SafeConnect(RunService.Heartbeat, LPH_NO_VIRTUALIZE(function()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if root and humanoid and humanoid.Health > 0 then
        -- Jump Boost Speed Calculation & Base Speed Override
        local baseSpeed = 16
        if Settings.SpeedWalkEnabled then 
            baseSpeed = Settings.SpeedWalkValue 
        end
        
        local targetSpeed = baseSpeed
        if Settings.JumpBoostEnabled and humanoid.FloorMaterial == Enum.Material.Air then
            targetSpeed = Settings.JumpBoostValue
        end
        
        if humanoid.WalkSpeed ~= targetSpeed then
            humanoid.WalkSpeed = targetSpeed
        end
        
        if Settings.JumpPowerEnabled then
            if not humanoid.UseJumpPower then humanoid.UseJumpPower = true end
            if humanoid.JumpPower ~= Settings.JumpPowerValue then
                humanoid.JumpPower = Settings.JumpPowerValue
            end
        else
            if humanoid.UseJumpPower then humanoid.UseJumpPower = false end
            if humanoid.JumpPower ~= 50 then
                humanoid.JumpPower = 50
            end
        end
        
        if Settings.CameraFOVEnabled then
            if Camera.FieldOfView ~= Settings.CameraFOVValue then
                Camera.FieldOfView = Settings.CameraFOVValue
            end
        else
            if Camera.FieldOfView ~= OriginalFOV then
                Camera.FieldOfView = OriginalFOV
            end
        end

        if Settings.InvisibleEnabled then
            for _, child in ipairs(character:GetDescendants()) do
                if child:IsA("BasePart") or child:IsA("Decal") then
                    if child.Name ~= "HumanoidRootPart" and child.Transparency ~= 1 then 
                        child.Transparency = 1 
                    end
                end
            end
        end

        if Settings.TouchFling then
            local multiplier = Settings.FlingPower * 1000
            originalVelocity = root.AssemblyLinearVelocity
            originalRotVelocity = root.AssemblyAngularVelocity
            
            root.AssemblyLinearVelocity = Vector3.new(multiplier, multiplier, multiplier)
            root.AssemblyAngularVelocity = Vector3.new(0, multiplier, 0)
        end

        -- Optimized Anti-Fling Logic
        if Settings.AntiFling and not Settings.TouchFling then
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            if root.AssemblyLinearVelocity.Magnitude > 75 then
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
end))

SafeConnect(RunService.RenderStepped, LPH_NO_VIRTUALIZE(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and Settings.TouchFling then
        root.AssemblyLinearVelocity = originalVelocity
        root.AssemblyAngularVelocity = originalRotVelocity
    end
end))

task.spawn(function()
    while true do
        if Settings.AntiVoid and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root and root.Position.Y < -80 then
                if SavedCFrame then
                    root.CFrame = SavedCFrame
                else
                    local spawns = Workspace:FindFirstChildOfClass("SpawnLocation")
                    if not spawns and Workspace:FindFirstChild("SpawnLocations") then
                        spawns = Workspace.SpawnLocations:FindFirstChildOfClass("SpawnLocation")
                    end
                    if spawns then
                        root.CFrame = spawns.CFrame * CFrame.new(0, 3, 0)
                    end
                end
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        if Settings.AntiFling then
            pcall(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        for _, part in ipairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.3)
    end
end)

-- ========================================================
-- [[ FLY SYSTEM AND INPUT ]]
-- ========================================================
local function GetFlyDirection()
    local direction = Vector3.new(0, 0, 0)
    
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end
    end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.MoveDirection.Magnitude > 0 then
            local camLook = Camera.CFrame.LookVector
            direction = direction + (hum.MoveDirection + Vector3.new(0, camLook.Y * 1.2, 0))
        end
        
        if hum.Jump then
            direction = direction + Vector3.new(0, 1, 0)
        end
    end
    
    if direction.Magnitude > 0 then
        return direction.Unit
    end
    return Vector3.new(0, 0, 0)
end

local FlyConnection
local function UpdateFlyState(state)
    Settings.FlyEnabled = state
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if FlyConnection then FlyConnection:Disconnect() end
    if hum then hum.PlatformStand = false end
    
    if not state then return end
    
    if root and hum then
        hum.PlatformStand = true
        
        FlyConnection = SafeConnect(RunService.RenderStepped, function(dt)
            if not Settings.FlyEnabled or not root or not hum or hum.Health <= 0 then
                if FlyConnection then FlyConnection:Disconnect() end
                hum.PlatformStand = false
                return
            end
            
            root.AssemblyLinearVelocity = Vector3.new(0, 0.05, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            local look = Camera.CFrame.LookVector
            root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(look.X, 0, look.Z))
            
            local dir = GetFlyDirection()
            if dir.Magnitude > 0 then
                root.CFrame = root.CFrame + (dir * (Settings.FlySpeedValue * dt))
            end
        end)
    end
end

-- SPIN SYSTEM
local function UpdateSpinState(state)
    Settings.SpinEnabled = state
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if not state then
        if SpinVelocity then SpinVelocity:Destroy() end
        return
    end
    
    if root then
        if SpinVelocity then SpinVelocity:Destroy() end
        SpinVelocity = Instance.new("BodyAngularVelocity")
        SpinVelocity.MaxTorque = Vector3.new(0, 9e9, 0)
        SpinVelocity.AngularVelocity = Vector3.new(0, Settings.SpinPower, 0)
        SpinVelocity.Parent = root
    end
end

-- ========================================================
-- [[ INSTANT FLING ]]
-- ========================================================
local function UpdateFlingState(role, state)
    if role == "Murderer" then
        Settings.AutoFlingMurder = state
    elseif role == "Sheriff" then
        Settings.AutoFlingSheriff = state
    end
end

task.spawn(function()
    while true do
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if root and humanoid and humanoid.Health > 0 then
            if (Settings.AutoFlingMurder or Settings.AutoFlingSheriff) and not Settings.CoinFarmEnabled then
                local targetRole = Settings.AutoFlingMurder and "Murderer" or "Sheriff"
                local targetPlayer = GetTargetByRole(targetRole)

                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if not FlingFailsafeActive then
                        FlingFailsafeActive = true
                        OriginalCFrameBeforeFling = root.CFrame
                    end

                    root.Anchored = false
                    for _, child in ipairs(character:GetDescendants()) do
                        if child:IsA("BasePart") then child.CanCollide = true end
                    end

                    local tRoot = targetPlayer.Character.HumanoidRootPart
                    root.CFrame = tRoot.CFrame * CFrame.new(math.random(-1,1) * 0.1, 0, math.random(-1,1) * 0.1)
                    root.AssemblyLinearVelocity = Vector3.new(99999, 99999, 99999)
                    root.AssemblyAngularVelocity = Vector3.new(0, 99999, 0)
                else
                    if FlingFailsafeActive then
                        Settings.AutoFlingMurder = false
                        Settings.AutoFlingSheriff = false
                        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        task.wait(0.1)
                        if OriginalCFrameBeforeFling then
                            root.CFrame = OriginalCFrameBeforeFling
                        end
                        FlingFailsafeActive = false
                        OriginalCFrameBeforeFling = nil
                        
                        if _G.SyncFlingButtons then _G.SyncFlingButtons() end
                    end
                end
            end
        end
        task.wait()
    end
end)

-- ========================================================
-- [[ FEATURE 6 LOGIC: NAME ESP & HIGHLIGHT ESP SYSTEM ]]
-- ========================================================
local function ApplyNameESP(player)
    if not player or not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    local billboard = head:FindFirstChild("MM2_NameESP")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "MM2_NameESP"
        billboard.Size = UDim2.new(0, 100, 0, 20)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.AlwaysOnTop = true
        
        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 10
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        billboard.Parent = head
    end
    
    local role = GetMM2Role(player)
    local targetColor = Color3.fromRGB(0, 225, 0)
    if role == "Murderer" then targetColor = Color3.fromRGB(255, 0, 0)
    elseif role == "Sheriff" then targetColor = Color3.fromRGB(0, 0, 225) end
    
    local label = billboard:FindFirstChildOfClass("TextLabel")
    if label then
        label.Text = player.Name .. " [" .. role .. "]"
        label.TextColor3 = targetColor
    end
    
    local shouldShow = false
    if Settings.ESP and Settings.NameESP then
        if role == "Murderer" and Settings.EspMurderer then shouldShow = true
        elseif role == "Sheriff" and Settings.EspSheriff then shouldShow = true
        elseif role == "Innocent" and Settings.EspInnocent then shouldShow = true end
    end
    billboard.Enabled = shouldShow
end

local function ClearNameESP(player)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        local billboard = head and head:FindFirstChild("MM2_NameESP")
        if billboard then billboard:Destroy() end
    end
end

local ActiveTracers = {}
local function ClearAllTracers()
    for _, tracer in pairs(ActiveTracers) do
        tracer.Visible = false
        tracer:Remove()
    end
    table.clear(ActiveTracers)
end

-- ========================================================
-- [[ OPTIMIZED VISUALS & ESP / HITBOX SYSTEM ]]
-- ========================================================
-- 1. Slower loop for ESP Highlights and Hitbox scaling to save significant CPU cycles
task.spawn(function()
    while true do
        task.wait(0.1) -- Runs 10 times per second instead of every single physics frame
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character then
                local Root = Player.Character:FindFirstChild("HumanoidRootPart")
                local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
                
                if Root and Humanoid and Humanoid.Health > 0 then
                    local Role = GetMM2Role(Player)
                    local passesFilter = false
                    if Role == "Murderer" and Settings.EspMurderer then passesFilter = true
                    elseif Role == "Sheriff" and Settings.EspSheriff then passesFilter = true
                    elseif Role == "Innocent" and Settings.EspInnocent then passesFilter = true end
                    
                    -- Optimized Hitbox Expander with checks to avoid repetitive property writes
                    if Settings.HitboxExpander then
                        local targetSize = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                        if Root.Size ~= targetSize then
                            Root.Size = targetSize
                            if not IsGrabbing and not FlingFailsafeActive then Root.CanCollide = false end
                            if Settings.HitboxVisual then
                                Root.Transparency = 0.7
                                Root.Color = Color3.fromRGB(255, 0, 0)
                                Root.Material = Enum.Material.SmoothPlastic
                            else
                                Root.Transparency = 1
                            end
                        end
                    else
                        local defaultSize = Vector3.new(2, 2, 1)
                        if Root.Size ~= defaultSize then
                            Root.Size = defaultSize
                            Root.Transparency = 1
                        end
                    end

                    local TargetColor = Color3.fromRGB(0, 225, 0)
                    if Role == "Murderer" then TargetColor = Color3.fromRGB(255, 0, 0)
                    elseif Role == "Sheriff" then TargetColor = Color3.fromRGB(0, 0, 225) end

                    -- ESP Highlight
                    local Highlight = Player.Character:FindFirstChild("MM2_ESP")
                    if Settings.ESP and passesFilter then
                        if not Highlight then
                            Highlight = Instance.new("Highlight")
                            Highlight.Name = "MM2_ESP"
                            Highlight.Parent = Player.Character
                            Highlight.FillTransparency = 0.6
                            Highlight.OutlineTransparency = 0.1
                        end
                        if Highlight.FillColor ~= TargetColor then
                            Highlight.FillColor = TargetColor
                            Highlight.OutlineColor = TargetColor
                        end
                    else
                        if Highlight then Highlight:Destroy() end
                    end

                    -- Billboard ESP
                    if Settings.ESP and Settings.NameESP and passesFilter then
                        ApplyNameESP(Player)
                    else
                        ClearNameESP(Player)
                    end
                else
                    if Player.Character then
                        local Highlight = Player.Character:FindFirstChild("MM2_ESP")
                        if Highlight then Highlight:Destroy() end
                        ClearNameESP(Player)
                    end
                end
            end
        end
    end
end)

-- 2. Fast loop for Tracers (Must stay inside RenderStepped due to camera dependency)
SafeConnect(RunService.RenderStepped, LPH_NO_VIRTUALIZE(function()
    if not Settings.TracersESP then 
        ClearAllTracers() 
        return 
    end

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            local Root = Player.Character:FindFirstChild("HumanoidRootPart")
            local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
            
            if Root and Humanoid and Humanoid.Health > 0 then
                local Role = GetMM2Role(Player)
                local passesFilter = false
                if Role == "Murderer" and Settings.EspMurderer then passesFilter = true
                elseif Role == "Sheriff" and Settings.EspSheriff then passesFilter = true
                elseif Role == "Innocent" and Settings.EspInnocent then passesFilter = true end

                if Settings.TracersESP and passesFilter then
                    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Root.Position)
                    if OnScreen then
                        local Tracer = ActiveTracers[Player.Name]
                        if not Tracer then
                            Tracer = SafeDrawing("Line")
                            Tracer.Thickness = 1.5
                            Tracer.Transparency = 0.8
                            ActiveTracers[Player.Name] = Tracer
                        end
                        Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        Tracer.To = Vector2.new(ScreenPos.X, ScreenPos.Y)
                        
                        local TargetColor = Color3.fromRGB(0, 225, 0)
                        if Role == "Murderer" then TargetColor = Color3.fromRGB(255, 0, 0)
                        elseif Role == "Sheriff" then TargetColor = Color3.fromRGB(0, 0, 225) end
                        
                        Tracer.Color = TargetColor
                        Tracer.Visible = true
                    else
                        if ActiveTracers[Player.Name] then ActiveTracers[Player.Name].Visible = false end
                    end
                else
                    if ActiveTracers[Player.Name] then
                        ActiveTracers[Player.Name].Visible = false
                    end
                end
            else
                if ActiveTracers[Player.Name] then
                    ActiveTracers[Player.Name].Visible = false
                end
            end
        else
            if ActiveTracers[Player.Name] then
                ActiveTracers[Player.Name].Visible = false
            end
        end
    end
end))

-- ========================================================================
-- [[ EARLY ROLE DETECTION (BACKPACK & CHAR LISTENER) ]]
-- ========================================================================
local function MonitorRolesForEarlyDetect(player)
    if player == LocalPlayer then return end
    
    local function onChildAdded(child)
        if not Settings.EarlyRoleDetect then return end
        if child:IsA("Tool") then
            if child.Name == "Knife" then
                Library:Notify("Role Detected Early", player.DisplayName .. " (@" .. player.Name .. ") is MURDERER!", 5)
            elseif child.Name == "Gun" then
                Library:Notify("Role Detected Early", player.DisplayName .. " (@" .. player.Name .. ") is SHERIFF!", 5)
            end
        end
    end

    local function setupBackpack(backpack)
        backpack.ChildAdded:Connect(onChildAdded)
        for _, child in ipairs(backpack:GetChildren()) do
            onChildAdded(child)
        end
    end

    local function setupCharacter(char)
        char.ChildAdded:Connect(onChildAdded)
        for _, child in ipairs(char:GetChildren()) do
            onChildAdded(child)
        end
    end

    player.CharacterAdded:Connect(setupCharacter)
    if player.Character then setupCharacter(player.Character) end

    player.ChildAdded:Connect(function(child)
        if child.Name == "Backpack" then
            setupBackpack(child)
        end
    end)
    
    local bp = player:FindFirstChild("Backpack")
    if bp then setupBackpack(bp) end
end

for _, p in ipairs(Players:GetPlayers()) do
    MonitorRolesForEarlyDetect(p)
end
SafeConnect(Players.PlayerAdded, MonitorRolesForEarlyDetect)

-- ========================================================
-- [[ SYSTEM STATS HUD (FPS & PING LABELS) ]]
-- ========================================================
local HudGui = Instance.new("ScreenGui")
HudGui.Name = "LouisPerformanceHUD"
HudGui.DisplayOrder = -9999 -- Forced bottom layer
HudGui.ResetOnSpawn = false

local parentTarget = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
HudGui.Parent = parentTarget

local HudFrame = Instance.new("Frame")
HudFrame.Size = UDim2.new(0, 110, 0, 45)
HudFrame.Position = UDim2.new(1, -125, 0.5, -22)
HudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
HudFrame.BackgroundTransparency = 0.4
HudFrame.BorderSizePixel = 0
HudFrame.Parent = HudGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = HudFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(35, 35, 35)
UIStroke.Thickness = 1
UIStroke.Parent = HudFrame

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(1, 0, 0.5, 0)
FpsLabel.Position = UDim2.new(0, 0, 0, 0)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Font = Enum.Font.GothamSemibold
FpsLabel.TextSize = 11
FpsLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
FpsLabel.Text = "FPS: --"
FpsLabel.Parent = HudFrame

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(1, 0, 0.5, 0)
PingLabel.Position = UDim2.new(0, 0, 0.5, 0)
PingLabel.BackgroundTransparency = 1
PingLabel.Font = Enum.Font.GothamSemibold
PingLabel.TextSize = 11
PingLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
PingLabel.Text = "PING: -- ms"
PingLabel.Parent = HudFrame

local fpsCount = 0
local lastFpsTime = os.clock()
SafeConnect(RunService.RenderStepped, function()
    fpsCount = fpsCount + 1
    local now = os.clock()
    if now - lastFpsTime >= 1 then
        FpsLabel.Text = "FPS: " .. tostring(fpsCount)
        fpsCount = 0
        lastFpsTime = now
        
        local ping = 0
        pcall(function()
            ping = math.round(LocalPlayer:GetNetworkPing() * 1000)
        end)
        PingLabel.Text = "PING: " .. tostring(ping) .. " ms"
    end
end)

-- ========================================================
-- [[ EXTERNAL BUTTON INITIALIZATION FROM UI LIBRARY ]]
-- ========================================================
local ExtAimbotBtn = Library:CreateExternalButton("Aimbot", ExtButtonTexts.Aimbot, UDim2.new(0, 20, 0.5, -55), function()
    Settings.CameraAimbot = not Settings.CameraAimbot
    Library:Notify("Aimbot Toggle", "Status: " .. (Settings.CameraAimbot and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtAimbotBtn)

local ExtGrabBtn = Library:CreateExternalButton("GrabGun", ExtButtonTexts.GrabGun, UDim2.new(0, 20, 0.5, -10), function()
    local activeGun = ScanForDroppedGun()
    if activeGun then
        SafeInstantTween(activeGun)
        Library:Notify("Gun Grabber", "Attempting manual gun snatch!", 2)
    else
        Library:Notify("Gun Grabber", "No dropped gun found on map.", 2)
    end
end)
RegisterExternalButton(ExtGrabBtn)

local ExtDoubleJumpBtn = Library:CreateExternalButton("DoubleJump", ExtButtonTexts.DoubleJump, UDim2.new(0, 20, 0.5, 35), function()
    Settings.DoubleJumpEnabled = not Settings.DoubleJumpEnabled
    Library:Notify("Double Jump", "Status: " .. (Settings.DoubleJumpEnabled and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtDoubleJumpBtn)

local ExtSpinBtn = Library:CreateExternalButton("Spin", ExtButtonTexts.Spin, UDim2.new(0, 20, 0.5, 80), function()
    Settings.SpinEnabled = not Settings.SpinEnabled
    UpdateSpinState(Settings.SpinEnabled)
    Library:Notify("Spin Bot", "Status: " .. (Settings.SpinEnabled and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtSpinBtn)

local ExtTpSheriffBtn = Library:CreateExternalButton("TpSheriff", ExtButtonTexts.TpSheriff, UDim2.new(0, 70, 0.5, -55), function()
    TeleportToSheriff()
    Library:Notify("Teleport", "Teleporting to Sheriff...", 1.5)
end)
RegisterExternalButton(ExtTpSheriffBtn)

local ExtTpMurderBtn = Library:CreateExternalButton("TpMurderer", ExtButtonTexts.TpMurder, UDim2.new(0, 70, 0.5, -10), function()
    TeleportToMurderer()
    Library:Notify("Teleport", "Teleporting to Murderer...", 1.5)
end)
RegisterExternalButton(ExtTpMurderBtn)

local ExtFlingMurderBtn = Library:CreateExternalButton("FlingMurder", ExtButtonTexts.FlingMurder, UDim2.new(0, 70, 0.5, 35), function()
    Settings.AutoFlingMurder = not Settings.AutoFlingMurder
    if Settings.AutoFlingMurder then 
        Settings.AutoFlingSheriff = false 
        UpdateFlingState("Sheriff", false)
    end
    UpdateFlingState("Murderer", Settings.AutoFlingMurder)
    if _G.SyncFlingButtons then _G.SyncFlingButtons() end
    Library:Notify("Fling Hack", "Fling Murderer: " .. (Settings.AutoFlingMurder and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtFlingMurderBtn)

local ExtFlingSheriffBtn = Library:CreateExternalButton("FlingSheriff", ExtButtonTexts.FlingSheriff, UDim2.new(0, 70, 0.5, 80), function()
    Settings.AutoFlingSheriff = not Settings.AutoFlingSheriff
    if Settings.AutoFlingSheriff then 
        Settings.AutoFlingMurder = false 
        UpdateFlingState("Murderer", false)
    end
    UpdateFlingState("Sheriff", Settings.AutoFlingSheriff)
    if _G.SyncFlingButtons then _G.SyncFlingButtons() end
    Library:Notify("Fling Hack", "Fling Sheriff: " .. (Settings.AutoFlingSheriff and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtFlingSheriffBtn)

local ExtSavePosBtn = Library:CreateExternalButton("SavePos", ExtButtonTexts.SavePos, UDim2.new(0, 120, 0.5, -55), function()
    SavePosition()
    Library:Notify("POS Saved", "Saved local coordinates successfully!", 1.5)
end)
RegisterExternalButton(ExtSavePosBtn)

local ExtLoadPosBtn = Library:CreateExternalButton("LoadPos", ExtButtonTexts.LoadPos, UDim2.new(0, 120, 0.5, -10), function()
    if SavedCFrame then
        LoadSavedPosition()
        Library:Notify("POS Loaded", "Teleported to saved coordinate!", 1.5)
    else
        Library:Notify("POS Error", "No saved coordinate. Save position first!", 2)
    end
end)
RegisterExternalButton(ExtLoadPosBtn)

local ExtKillAllBtn = Library:CreateExternalButton("KillAll", ExtButtonTexts.KillAll, UDim2.new(0, 120, 0.5, 35), function()
    Settings.AutoKillAll = not Settings.AutoKillAll
    Library:Notify("Auto Kill All", "Status: " .. (Settings.AutoKillAll and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtKillAllBtn)

local ExtBhopBtn = Library:CreateExternalButton("Bhop", ExtButtonTexts.Bhop, UDim2.new(0, 120, 0.5, 80), function()
    Settings.AutoBhopEnabled = not Settings.AutoBhopEnabled
    Library:Notify("Auto Bhop", "Status: " .. (Settings.AutoBhopEnabled and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtBhopBtn)

local ExtSafeZoneBtn = Library:CreateExternalButton("SafeZone", ExtButtonTexts.SafeZone, UDim2.new(0, 170, 0.5, -55), function()
    Settings.SafeZoneEnabled = not Settings.SafeZoneEnabled
    ToggleSafeZone(Settings.SafeZoneEnabled)
    Library:Notify("Safe Zone", "Status: " .. (Settings.SafeZoneEnabled and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtSafeZoneBtn)

local ExtFlingGrabBtn = Library:CreateExternalButton("FlingGrab", ExtButtonTexts.FlingGrab, UDim2.new(0, 170, 0.5, -10), function()
    SafeFlingSheriffAndGrab()
end)
RegisterExternalButton(ExtFlingGrabBtn)

-- Custom Air Jump Boost Floating Button
local ExtJumpBoostBtn = Library:CreateExternalButton("JumpBoost", ExtButtonTexts.JumpBoost, UDim2.new(0, 170, 0.5, 35), function()
    Settings.JumpBoostEnabled = not Settings.JumpBoostEnabled
    Library:Notify("Jump Boost", "Air Jump Boost: " .. (Settings.JumpBoostEnabled and "ON" or "OFF"), 1.5)
end)
RegisterExternalButton(ExtJumpBoostBtn)

-- Sheriff Silent Aim Shooting Trigger Button
local ExtSilentAimBtn = Library:CreateExternalButton("SilentAim", ExtButtonTexts.SilentAim, UDim2.new(0, 170, 0.5, 80), function()
    TriggerSilentAimShot()
end)
RegisterExternalButton(ExtSilentAimBtn)

ExtAimbotBtn:SetVisible(false)
ExtGrabBtn:SetVisible(false)
ExtDoubleJumpBtn:SetVisible(false)
ExtSpinBtn:SetVisible(false)
ExtTpSheriffBtn:SetVisible(false)
ExtTpMurderBtn:SetVisible(false)
ExtFlingMurderBtn:SetVisible(false)
ExtFlingSheriffBtn:SetVisible(false)
ExtSavePosBtn:SetVisible(false)
ExtLoadPosBtn:SetVisible(false)
ExtKillAllBtn:SetVisible(false)
ExtBhopBtn:SetVisible(false)
ExtSafeZoneBtn:SetVisible(false)
ExtFlingGrabBtn:SetVisible(false)
ExtJumpBoostBtn:SetVisible(false)
ExtSilentAimBtn:SetVisible(false)

-- ========================================================================
-- [[ MAIN MENU STRUCTURE ]]
-- ========================================================================
local Window = Library:CreateWindow("LOUIS MM2 EDITION", "discord.gg/P2FEVBz2PG")
Window:BindToggleKey(Enum.KeyCode.RightControl)

Library:Notify("LOUIS HUB INSTANTIATED", "Press RightControl to hide/show Main UI.", 4)

-- --- TAB 1: MAIN INFO ---
local TabMain = Window:CreateTab("Welcome", "rbxassetid://6023426915")
TabMain:CreateParagraph("Welcome!", "Hello " .. LocalPlayer.Name .. "!\nThank you for executing Louis Premium Edition.")
TabMain:CreateParagraph("UI Instructions", "Keybind to open/hide menu: RightControl\nYou can toggle external buttons from the settings.")

TabMain:CreateParagraph("Official Community", "Join our Discord server to get the latest update information, report issues, and interact directly with the developers and the rest of the community!")
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

TabMain:CreateButton("Clean Lag & Optimize FPS Now", function()
    CleanLagAndOptimize()
end)

-- --- TAB 2: COMBAT ---
local TabCombat = Window:CreateTab("Combat Settings", "rbxassetid://4483345998")

TabCombat:CreateParagraph("Auto Kill Mechanics", "Fits murderer roles only.")
local KillAuraToggle = TabCombat:CreateToggle("Kill Aura Auto-Slash", false, function(state)
    Settings.KillAuraEnabled = state
end)

TabCombat:CreateSlider("Kill Aura Radius (Studs)", 5, 50, Settings.KillAuraRadius, function(val)
    Settings.KillAuraRadius = val
end)

TabCombat:CreateToggle("Auto-Kill All (Murderer Loop)", false, function(state)
    Settings.AutoKillAll = state
end)

TabCombat:CreateToggle("Show Auto-Kill All Button [KA]", false, function(state)
    ExtKillAllBtn:SetVisible(state)
end)

TabCombat:CreateButton("Teleport & Stack All Players to Me", function()
    TeleportAllPlayersToMe()
    Library:Notify("Combat Teleport", "Stacked all players for easy kill!", 2.5)
end)

TabCombat:CreateParagraph("Touch Fling (Collision System)", "Instant physical rotation style when character touches the enemy.")
TabCombat:CreateToggle("Activate Touch Fling", false, function(state)
    Settings.TouchFling = state
end)

TabCombat:CreateSlider("Fling Velocity Power multiplier", 1, 200, Settings.FlingPower, function(val)
    Settings.FlingPower = val
end)

TabCombat:CreateToggle("Anti Fling (Collision Resistance)", false, function(state)
    Settings.AntiFling = state
end)

TabCombat:CreateParagraph("Sheriff Silent Aim & Shoot", "Inject metamethod redirection to lock bullets on the Murderer.")
TabCombat:CreateToggle("Enable Gun Silent Aim Hook", false, function(state)
    Settings.SilentAimEnabled = state
end)

TabCombat:CreateToggle("Show Silent Aim Shooting Button [SA]", false, function(state)
    Settings.SilentAimExtEnabled = state
    ExtSilentAimBtn:SetVisible(state)
end)

TabCombat:CreateButton("Auto-Equip, Aim, & Fire Shot Now", function()
    TriggerSilentAimShot()
end)

TabCombat:CreateParagraph("Aimbot & Prediction", "Aimbot locks to murderer or targets based on role.")
local AimbotToggle = TabCombat:CreateToggle("Aim Assist Lock (Holding Gun/Knife)", false, function(state)
    Settings.CameraAimbot = state
end)

TabCombat:CreateToggle("Show Master Aimbot Button [A]", false, function(state)
    Settings.AimbotExtEnabled = state
    ExtAimbotBtn:SetVisible(state)
end)

TabCombat:CreateSlider("Aimbot FOV Range (Studs)", 50, 400, Settings.FOVSize, function(val)
    Settings.FOVSize = val
end)

TabCombat:CreateToggle("Hide Aimbot FOV Circle", false, function(state)
    Settings.HideFOVCircle = state
end)

TabCombat:CreateToggle("Camera FOV Override", false, function(state)
    Settings.CameraFOVEnabled = state
end)

TabCombat:CreateSlider("Camera Field Of View", 30, 120, Settings.CameraFOVValue, function(val)
    Settings.CameraFOVValue = val
end)

-- --- TAB 3: VISUAL & ESP ---
local TabVisuals = Window:CreateTab("Visual Hacks", "rbxassetid://4483345998")

TabVisuals:CreateToggle("Activate Esp Outline + Drop Gun Outline", false, function(state)
    Settings.ESP = state
    if not state then ClearGunOutlines() end
end)

TabVisuals:CreateToggle("Tracers Lines (To Players)", false, function(state)
    Settings.TracersESP = state
    if not state then ClearAllTracers() end
end)

TabVisuals:CreateToggle("Show Billboard Names + Roles", false, function(state)
    Settings.NameESP = state
end)

TabVisuals:CreateToggle("Coin Highlight ESP", false, function(state)
    Settings.CoinESP = state
    if not state then
        task.spawn(ClearCoinESP)
    end
end)

TabVisuals:CreateParagraph("Filter ESP Targets", "Filter who glows in ESP.")
TabVisuals:CreateToggle("Render Murderer Glow", true, function(state)
    Settings.EspMurderer = state
end)

TabVisuals:CreateToggle("Render Sheriff Glow", true, function(state)
    Settings.EspSheriff = state
end)

TabVisuals:CreateToggle("Render Innocent Glow", true, function(state)
    Settings.EspInnocent = state
end)

TabVisuals:CreateParagraph("Hitbox Scaling", "Increases targets Hitbox.")
TabVisuals:CreateToggle("Expand Player Hitbox", false, function(state)
    Settings.HitboxExpander = state
end)

TabVisuals:CreateToggle("Show Hitbox (Red Box)", true, function(state)
    Settings.HitboxVisual = state
end)

TabVisuals:CreateSlider("Hitbox Size Modifier", 2, 100, Settings.HitboxSize, function(val)
    Settings.HitboxSize = val
end)

-- --- TAB 4: MOVEMENT & UTILITY ---
local TabMovement = Window:CreateTab("Utility Movement", "rbxassetid://4483362458")

TabMovement:CreateParagraph("Speed & Jump Modifiers", "Modify walk speed and jump power.")
TabMovement:CreateToggle("Custom Walk Speed", false, function(state)
    Settings.SpeedWalkEnabled = state
    if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)

TabMovement:CreateSlider("Speed Force Value", 16, 120, Settings.SpeedWalkValue, function(val)
    Settings.SpeedWalkValue = val
end)

TabMovement:CreateToggle("Jump Speed Boost (Air Boost)", false, function(state)
    Settings.JumpBoostEnabled = state
end)

TabMovement:CreateSlider("Jump Boost Speed Force", 16, 120, Settings.JumpBoostValue, function(val)
    Settings.JumpBoostValue = val
end)

TabMovement:CreateToggle("Show Jump Boost Button [JB]", false, function(state)
    ExtJumpBoostBtn:SetVisible(state)
end)

TabMovement:CreateToggle("Custom Jump Power Force", false, function(state)
    Settings.JumpPowerEnabled = state
    if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        humanoid.UseJumpPower = false
        humanoid.JumpPower = 50
    end
end)

TabMovement:CreateSlider("Jump Power Modifier", 50, 250, Settings.JumpPowerValue, function(val)
    Settings.JumpPowerValue = val
end)

TabMovement:CreateToggle("Double Jump Feature", false, function(state)
    Settings.DoubleJumpEnabled = state
end)

TabMovement:CreateToggle("Show Double Jump Floating Button [DJ]", false, function(state)
    Settings.DoubleJumpExtEnabled = state
    ExtDoubleJumpBtn:SetVisible(state)
end)

TabMovement:CreateToggle("Infinite Jump (Infinite Jumping)", false, function(state)
    Settings.InfiniteJump = state
end)

TabMovement:CreateToggle("Auto Bunnyhop (Bhop)", false, function(state)
    Settings.AutoBhopEnabled = state
end)

TabMovement:CreateToggle("Show Auto Bhop Button [BHOP]", false, function(state)
    ExtBhopBtn:SetVisible(state)
end)

-- SPIN BOT
TabMovement:CreateParagraph("Spin Bot System", "Rotate your character physically.")
TabMovement:CreateToggle("Enable Spin Bot", false, function(state)
    UpdateSpinState(state)
end)

TabMovement:CreateSlider("Spin Force / Power", 10, 300, Settings.SpinPower, function(val)
    Settings.SpinPower = val
    if Settings.SpinEnabled and SpinVelocity then
        SpinVelocity.AngularVelocity = Vector3.new(0, val, 0)
    end
end)

TabMovement:CreateToggle("Show Spin External Button [S]", false, function(state)
    Settings.SpinExtEnabled = state
    ExtSpinBtn:SetVisible(state)
end)

TabMovement:CreateParagraph("Flight, Noclip & Safe Teleport", "Movement through spaces.")
TabMovement:CreateToggle("Velocity Fly Hack", false, function(state)
    UpdateFlyState(state)
end)

TabMovement:CreateSlider("Flight Velocity Speed", 10, 150, Settings.FlySpeedValue, function(val)
    Settings.FlySpeedValue = val
end)

TabMovement:CreateToggle("Noclip (Walk Through Walls)", false, function(state)
    ToggleNoclip(state)
end)

TabMovement:CreateToggle("Safe Zone Teleport (Hide Out)", false, function(state)
    ToggleSafeZone(Settings.SafeZoneEnabled)
end)

TabMovement:CreateToggle("Show Safe Zone Button [SZ]", false, function(state)
    ExtSafeZoneBtn:SetVisible(state)
end)

TabMovement:CreateToggle("Character Invisibility Hack", false, function(state)
    Settings.InvisibleEnabled = state
    if not state and LocalPlayer.Character then
        for _, child in ipairs(LocalPlayer.Character:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("Decal") then
                if child.Name ~= "HumanoidRootPart" then child.Transparency = 0 end
            end
        end
    end
end)

-- --- TAB 5: MM2 SPECIAL UTILITIES ---
local TabSpecial = Window:CreateTab("MM2 Specials", "rbxassetid://4483362458")

TabSpecial:CreateParagraph("Early Role Detection Settings", "Detect roles before action begins.")
TabSpecial:CreateToggle("Early Role Detector Notification", true, function(state)
    Settings.EarlyRoleDetect = state
end)

TabSpecial:CreateParagraph("Coin Autofarm", "Automatically scan and collect coins on the map.")
TabSpecial:CreateToggle("Activate Auto Farm Coins", false, function(state)
    Settings.CoinFarmEnabled = state
    if state then
        CoinFarmTimeLeft = Settings.CoinFarmTimerValue * 60
        IsFlingingFromFarm = false
    end
end)

TabSpecial:CreateSlider("Fling Murderer Timer (Minutes)", 1, 5, Settings.CoinFarmTimerValue, function(val)
    Settings.CoinFarmTimerValue = val
    if not IsFlingingFromFarm then
        CoinFarmTimeLeft = val * 60
    end
end)

TabSpecial:CreateSlider("Coin Farm Tween Speed", 20, 90, Settings.CoinFarmTweenSpeed, function(val)
    Settings.CoinFarmTweenSpeed = val
end)

TabSpecial:CreateSlider("Coin Up Tween Speed", 10, 150, Settings.CoinUpTweenSpeed, function(val)
    Settings.CoinUpTweenSpeed = val
end)

TabSpecial:CreateSlider("Max Coin Distance (Studs)", 50, 1000, Settings.CoinMaxDistance, function(val)
    Settings.CoinMaxDistance = val
end)

-- ========================================================================
-- [[ DYNAMIC ACTIVE PLAYER RETRIEVER LOGIC ]]
-- ========================================================================
local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    return names
end

TabSpecial:CreateParagraph("Target Operations", "Dynamically select a target player to launch attacks or teleport.")

local TargetDropdown
TargetDropdown = TabSpecial:CreateDropdown("Select Target Player", GetPlayerNames(), "", function(selectedName)
    local target = Players:FindFirstChild(selectedName)
    if target then
        SelectedPlayer = target
        Library:Notify("Target Selected", SelectedPlayer.DisplayName .. " (@" .. SelectedPlayer.Name .. ")", 2)
    end
end)

TabSpecial:CreateButton("Update Player List (Refresh)", function()
    local currentNames = GetPlayerNames()
    if TargetDropdown then
        if TargetDropdown.Refresh then
            pcall(function() TargetDropdown:Refresh(currentNames) end)
        elseif TargetDropdown.Update then
            pcall(function() TargetDropdown:Update(currentNames) end)
        end
    end
    Library:Notify("Player List", "Player list successfully updated!", 1.5)
end)

SafeConnect(Players.PlayerAdded, function()
    task.wait(1)
    local currentNames = GetPlayerNames()
    if TargetDropdown then
        if TargetDropdown.Refresh then pcall(function() TargetDropdown:Refresh(currentNames) end)
        elseif TargetDropdown.Update then pcall(function() TargetDropdown:Update(currentNames) end) end
    end
end)

SafeConnect(Players.PlayerRemoving, function()
    task.wait(1)
    local currentNames = GetPlayerNames()
    if TargetDropdown then
        if TargetDropdown.Refresh then pcall(function() TargetDropdown:Refresh(currentNames) end)
        elseif TargetDropdown.Update then pcall(function() TargetDropdown:Update(currentNames) end) end
    end
end)

TabSpecial:CreateButton("Launch Fling at Selected Target Character", function()
    if SelectedPlayer then
        Library:Notify("Fling Attack", "Launching physical fling attack at " .. SelectedPlayer.DisplayName, 2)
        FlingPlayer(SelectedPlayer)
    else
        Library:Notify("Error", "Select a target character from the dropdown above first!", 2.5)
    end
end)

TabSpecial:CreateButton("Instant Teleport to Selected Target Character", function()
    if SelectedPlayer then
        TpToPlayer(SelectedPlayer)
        Library:Notify("Instant Teleport", "Arrived at the location of " .. SelectedPlayer.DisplayName, 1.5)
    else
        Library:Notify("Error", "Select a target character from the dropdown above first!", 2.5)
    end
end)

TabSpecial:CreateParagraph("Fling Glitches", "Violent rotation engine designed to push physical targets.")

TabSpecial:CreateButton("Safe Fling Sheriff + Instant Grab Gun", function()
    SafeFlingSheriffAndGrab()
end)

TabSpecial:CreateToggle("Show Fling & Grab Button [FG]", false, function(state)
    Settings.FlingGrabExtEnabled = state
    ExtFlingGrabBtn:SetVisible(state)
end)

TabSpecial:CreateButton("Auto Fling Murderer Instance", function()
    Settings.AutoFlingMurder = not Settings.AutoFlingMurder
    if Settings.AutoFlingMurder then 
        Settings.AutoFlingSheriff = false 
        UpdateFlingState("Sheriff", false)
    end
    UpdateFlingState("Murderer", Settings.AutoFlingMurder)
    if _G.SyncFlingButtons then _G.SyncFlingButtons() end
end)

TabSpecial:CreateToggle("Show Fling Murderer Button [FM]", false, function(state)
    Settings.FlingMurderExtEnabled = state
    ExtFlingMurderBtn:SetVisible(state)
end)

TabSpecial:CreateButton("Auto Fling Sheriff Instance", function()
    Settings.AutoFlingSheriff = not Settings.AutoFlingSheriff
    if Settings.AutoFlingSheriff then 
        Settings.AutoFlingMurder = false 
        UpdateFlingState("Murderer", false)
    end
    UpdateFlingState("Sheriff", Settings.AutoFlingSheriff)
    if _G.SyncFlingButtons then _G.SyncFlingButtons() end
end)

TabSpecial:CreateToggle("Show Fling Sheriff Button [FS]", false, function(state)
    Settings.FlingSheriffExtEnabled = state
    ExtFlingSheriffBtn:SetVisible(state)
end)

TabSpecial:CreateParagraph("Grab Dropped Gun", "Teleports to gun then teleports back.")
TabSpecial:CreateToggle("Auto Grab Gun (On Dropped)", false, function(state)
    Settings.AutoGrabGun = state
end)

TabSpecial:CreateToggle("Show Manual Grab Gun Button [G]", false, function(state)
    Settings.GrabGunExtEnabled = state
    ExtGrabBtn:SetVisible(state)
end)

TabSpecial:CreateParagraph("Target Teleports", "Instant teleportation to key characters.")
TabSpecial:CreateButton("Teleport instantly to Sheriff", function()
    TeleportToSheriff()
end)

TabSpecial:CreateToggle("Show Teleport Sheriff Button [TS]", false, function(state)
    Settings.TpSheriffExtEnabled = state
    ExtTpSheriffBtn:SetVisible(state)
end)

TabSpecial:CreateButton("Teleport instantly to Murderer", function()
    TeleportToMurderer()
end)

TabSpecial:CreateToggle("Show Teleport Murderer Button [TM]", false, function(state)
    Settings.TpMurderExtEnabled = state
    ExtTpMurderBtn:SetVisible(state)
end)

TabSpecial:CreateToggle("Show Save/Load Position Buttons [POS]", false, function(state)
    Settings.PosExtEnabled = state
    ExtSavePosBtn:SetVisible(state)
    ExtLoadPosBtn:SetVisible(state)
end)

-- --- TAB 6: CONTROLS & SIZES ---
local TabControls = Window:CreateTab("Button Controls", "rbxassetid://4483362458")

TabControls:CreateParagraph("External Button Scales (%)", "Adjust the scale of each floating button dynamically.")

TabControls:CreateSlider("Aimbot Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtAimbotBtn, val / 100)
end)

TabControls:CreateSlider("Grab Gun Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtGrabBtn, val / 100)
end)

TabControls:CreateSlider("Double Jump Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtDoubleJumpBtn, val / 100)
end)

TabControls:CreateSlider("Spin Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtSpinBtn, val / 100)
end)

TabControls:CreateSlider("Tp Sheriff Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtTpSheriffBtn, val / 100)
end)

TabControls:CreateSlider("Tp Murderer Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtTpMurderBtn, val / 100)
end)

TabControls:CreateSlider("Fling Murderer Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtFlingMurderBtn, val / 100)
end)

TabControls:CreateSlider("Fling Sheriff Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtFlingSheriffBtn, val / 100)
end)

TabControls:CreateSlider("Save Position Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtSavePosBtn, val / 100)
end)

TabControls:CreateSlider("Load Position Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtLoadPosBtn, val / 100)
end)

TabControls:CreateSlider("Auto Kill All Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtKillAllBtn, val / 100)
end)

TabControls:CreateSlider("Bhop Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtBhopBtn, val / 100)
end)

TabControls:CreateSlider("Safe Zone Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtSafeZoneBtn, val / 100)
end)

TabControls:CreateSlider("Fling & Grab Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtFlingGrabBtn, val / 100)
end)

TabControls:CreateSlider("Jump Boost Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtJumpBoostBtn, val / 100)
end)

TabControls:CreateSlider("Silent Aim Button Scale", 10, 200, 100, function(val)
    SetButtonSize(ExtSilentAimBtn, val / 100)
end)

TabControls:CreateParagraph("Window Lock", "Lock window dragging positions.")
TabControls:CreateToggle("Lock Main UI Dragging", false, function(state)
    Window:SetDragLock(state)
    UpdateAllButtonsDragLock(state)
end)

-- --- TAB 7: CONFIGURATIONS ---
local TabConfig = Window:CreateTab("Configurations", "rbxassetid://6023426915")

TabConfig:CreateParagraph("Configuration Manager", "Manually save or load your configuration settings at any time.")

TabConfig:CreateButton("Save Config Now", function()
    Library:SaveConfig()
end)

TabConfig:CreateButton("Load Config Now", function()
    Library:LoadConfig()
end)

-- ========================================================================
-- [[ RESPONDERS SYSTEM & EVENT CONNECTIONS (PERSISTENCE) ]]
-- ========================================================================
_G.SyncFlingButtons = function()
    Library:Notify("Fling Update", "States updated.", 1.2)
end

if LocalPlayer.Character then
    pcall(SetupDoubleJump, LocalPlayer.Character)
end

SafeConnect(LocalPlayer.CharacterAdded, function(char)
    pcall(SetupDoubleJump, char)
    
    WasUnderground = false
    PreFarmCFrame = nil
    CachedCoinContainer = nil
    CollectedCoinsCount = 0
    IsFlingingFromFarm = false
    CoinFarmTimeLeft = Settings.CoinFarmTimerValue * 60
    
    local humanoid = char:WaitForChild("Humanoid")
    task.wait(0.5)
    
    if Settings.SpeedWalkEnabled then humanoid.WalkSpeed = Settings.SpeedWalkValue end
    if Settings.JumpPowerEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Settings.JumpPowerValue
    end
    if Settings.FlyEnabled then UpdateFlyState(true) end
    if Settings.SpinEnabled then UpdateSpinState(true) end
end)

-- Keyboard Quick Keybind Connection
SafeConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Q then
        Settings.CameraAimbot = not Settings.CameraAimbot
        Library:Notify("Aimbot Assist", "Status: " .. (Settings.CameraAimbot and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.X then
        Settings.ESP = not Settings.ESP
        Library:Notify("Visuals Toggle", "Status: " .. (Settings.ESP and "ON" or "OFF"), 1.5)
        if not Settings.ESP then ClearGunOutlines() end
    elseif key == Enum.KeyCode.C then
        Settings.HitboxExpander = not Settings.HitboxExpander
        Library:Notify("Hitbox Expander", "Status: " .. (Settings.HitboxExpander and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.H then
        Settings.AutoGrabGun = not Settings.AutoGrabGun
        Library:Notify("Auto Grab Gun", "Status: " .. (Settings.AutoGrabGun and "ON" or "OFF"), 1.5)
    elseif key == Enum.KeyCode.P then
        Settings.HideFOVCircle = not Settings.HideFOVCircle
        Library:Notify("FOV Visibility", "Status: " .. (Settings.HideFOVCircle and "Hidden" or "Visible"), 1.5)
    end
end)

print("[LOUIS HUB]: MM2 Loader Ready to Use.")

-- ==============================================================================
-- DELTA HUB - MM2 CLEAN EDITION (Aimbot + ESP + WallCheck Toggle)
-- ==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ตัวแปรควบคุมสถานะหลัก (ตามที่ต้องการ)
local AimbotEnabled = false
local ESPBoxEnabled = true
local WallCheckEnabled = true -- เปิด = ไม่ล็อกหลังกำแพง / ปิด = ล็อกทะลุกำแพงได้

local CachedTarget = nil
local LastCheckTick = 0
local CheckInterval = 0.05

-- 1. สร้าง UI หน้าต่างหลักและปุ่มลอย
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaHub_CleanEdition"
ScreenGui.ResetOnSpawn = false
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- ปุ่มไอคอนลอยเปิด-ปิด UI
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Size = UDim2.new(0, 52, 0, 52)
FloatingBtn.Position = UDim2.new(0, 30, 0.4, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
FloatingBtn.Text = "⚡"
FloatingBtn.TextSize = 26
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Parent = ScreenGui

Instance.new("UICorner", FloatingBtn).CornerRadius = UDim.new(1, 0)
local FloatStroke = Instance.new("UIStroke", FloatingBtn)
FloatStroke.Color = Color3.fromRGB(46, 204, 113)
FloatStroke.Thickness = 2

-- หน้าต่างเมนูหลัก
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 270, 0, 280)
MainFrame.Position = UDim2.new(0.5, -135, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(45, 45, 65)
MainStroke.Thickness = 1.5

-- แถบหัวข้อด้านบน
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.Text = "⚡ DELTA HUB | CLEAN"
Title.TextColor3 = Color3.fromRGB(46, 204, 113)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -30, 0, 1)
Divider.Position = UDim2.new(0, 15, 0, 45)
Divider.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

-- ฟังก์ชันสร้างปุ่มเมนู
local function CreateMenuButton(posY, defaultText, inactiveColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, 42)
    btn.Position = UDim2.new(0, 15, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    btn.Text = defaultText
    btn.TextColor3 = inactiveColor
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = MainFrame
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(45, 45, 65)
    stroke.Thickness = 1
    
    return btn, stroke
end

-- สร้างปุ่มตามฟังก์ชันที่เลือกไว้
local ToggleBtn, Stroke1 = CreateMenuButton(60, "Aimbot : OFF ❌", Color3.fromRGB(255, 100, 100))
local ESPBtn, Stroke2 = CreateMenuButton(110, "ESP Box + Distance : ON ✅", Color3.fromRGB(100, 255, 100))
local WallCheckBtn, Stroke3 = CreateMenuButton(160, "WallCheck (ไม่ล็อกหลังกำแพง) : ON ✅", Color3.fromRGB(100, 255, 100))
local CloseAllBtn, Stroke4 = CreateMenuButton(215, "❌ ปิดการทำงานทั้งหมด & ปิด UI", Color3.fromRGB(255, 70, 70))
CloseAllBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)

local function UpdateButtonState(btn, stroke, state, activeText, inactiveText, activeColor)
    if state then
        btn.Text = activeText
        btn.TextColor3 = activeColor
        stroke.Color = activeColor
    else
        btn.Text = inactiveText
        btn.TextColor3 = Color3.fromRGB(255, 100, 100)
        stroke.Color = Color3.fromRGB(45, 45, 65)
    end
end

-- เชื่อมโยงปุ่มกด
ToggleBtn.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    UpdateButtonState(ToggleBtn, Stroke1, AimbotEnabled, "Aimbot : ON ✅", "Aimbot : OFF ❌", Color3.fromRGB(100, 255, 100))
    if not AimbotEnabled then CachedTarget = nil end
end)

ESPBtn.MouseButton1Click:Connect(function()
    ESPBoxEnabled = not ESPBoxEnabled
    UpdateButtonState(ESPBtn, Stroke2, ESPBoxEnabled, "ESP Box + Distance : ON ✅", "ESP Box + Distance : OFF ❌", Color3.fromRGB(100, 255, 100))
end)

WallCheckBtn.MouseButton1Click:Connect(function()
    WallCheckEnabled = not WallCheckEnabled
    UpdateButtonState(WallCheckBtn, Stroke3, WallCheckEnabled, "WallCheck (ไม่ล็อกหลังกำแพง) : ON ✅", "WallCheck (ไม่ล็อกหลังกำแพง) : OFF ❌", Color3.fromRGB(100, 255, 100))
end)

local Connections = {}

-- ฟังก์ชันปิดการทำงานทั้งหมด (Kill Switch)
local function UnloadScript()
    AimbotEnabled = false
    ESPBoxEnabled = false
    WallCheckEnabled = false
    
    for _, conn in ipairs(Connections) do
        if conn and conn.Connected then conn:Disconnect() end
    end
    
    pcall(function()
        for _, cache in pairs(ESPCache) do
            if cache.Box then cache.Box:Remove() end
            if cache.DistanceText then cache.DistanceText:Remove() end
        end
    end)
    
    ScreenGui:Destroy()
end

CloseAllBtn.MouseButton1Click:Connect(UnloadScript)

local menuVisible = true
FloatingBtn.MouseButton1Click:Connect(function()
    menuVisible = not menuVisible
    MainFrame.Visible = menuVisible
end)

-- 2. ระบบแคช Drawing สำหรับ ESP กล่องเขียวและระยะทาง
local ESPCache = {}

local function CreateESP(player)
    if ESPCache[player] then return ESPCache[player] end

    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(46, 204, 113)
    box.Thickness = 1.5
    box.Filled = false

    local distText = Drawing.new("Text")
    distText.Visible = false
    distText.Color = Color3.fromRGB(46, 204, 113)
    distText.Size = 13
    distText.Center = true
    distText.Outline = true

    local cache = {Box = box, DistanceText = distText}
    ESPCache[player] = cache
    return cache
end

local function RemoveESP(player)
    if ESPCache[player] then
        if ESPCache[player].Box then ESPCache[player].Box:Remove() end
        if ESPCache[player].DistanceText then ESPCache[player].DistanceText:Remove() end
        ESPCache[player] = nil
    end
end

table.insert(Connections, Players.PlayerRemoving:Connect(RemoveESP))

-- 3. ฟังก์ชันตรวจสอบการมองเห็น (WallCheck: ถ้าเปิดอยู่ จะไม่ล็อกเป้าหมายที่อยู่หลังกำแพง)
local function IsVisible(targetPart)
    if not WallCheckEnabled then return true end -- ถ้าปิด WallCheck จะทะลุกำแพงได้
    
    local myChar = LocalPlayer.Character
    if not myChar then return false end
    
    local origin = Camera.CFrame.Position 
    local destination = targetPart.Position
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {myChar, targetPart.Parent}
    raycastParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, destination - origin, raycastParams)
    return result == nil -- ถ้าไม่มีอะไรขวาง แปลว่าโล่งโจ้ง ล็อกได้
end

-- 4. ฟังก์ชันหาเป้าหมายที่ใกล้ที่สุด (ล็อกหัว)
local function GetClosestTarget()
    local target = nil
    local shortestDist = math.huge
    local myChar = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return nil end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local pChar = player.Character
            local humanoid = pChar:FindFirstChild("Humanoid")
            local head = pChar:FindFirstChild("Head")
            
            if humanoid and humanoid.Health > 0 and head then
                if IsVisible(head) then
                    local distance = (myChar.HumanoidRootPart.Position - head.Position).Magnitude
                    if distance < shortestDist then
                        shortestDist = distance
                        target = head
                    end
                end
            end
        end
    end
    return target
end

-- 5. ลูปการทำงานหลัก (RenderStepped) ควบคุม ESP และ Aimbot
table.insert(Connections, RunService.RenderStepped:Connect(function()
    -- จัดการส่วน ESP Box และ Distance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local pChar = player.Character
            local cache = CreateESP(player)
            
            if ESPBoxEnabled and pChar and pChar:FindFirstChild("HumanoidRootPart") and pChar:FindFirstChild("Humanoid") and pChar.Humanoid.Health > 0 then
                local rootPart = pChar.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(rootPart.Position)

                if onScreen then
                    local head = pChar:FindFirstChild("Head")
                    local topPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or vector
                    local bottomPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

                    local height = math.abs(topPos.Y - bottomPos.Y)
                    local width = height / 2

                    cache.Box.Size = Vector2.new(width, height)
                    cache.Box.Position = Vector2.new(vector.X - width / 2, topPos.Y)
                    cache.Box.Visible = true

                    local distance = math.floor((Camera.CFrame.Position - rootPart.Position).Magnitude)
                    cache.DistanceText.Text = "[" .. distance .. "m]"
                    cache.DistanceText.Position = Vector2.new(vector.X, bottomPos.Y + 4)
                    cache.DistanceText.Visible = true
                else
                    cache.Box.Visible = false
                    cache.DistanceText.Visible = false
                end
            else
                cache.Box.Visible = false
                cache.DistanceText.Visible = false
            end
        end
    end

    -- จัดการส่วน Aimbot
    if not AimbotEnabled then return end
    
    local currentTime = tick()
    if currentTime - LastCheckTick >= CheckInterval then
        LastCheckTick = currentTime
        CachedTarget = GetClosestTarget()
    end
    
    if CachedTarget and CachedTarget.Parent and CachedTarget.Parent:FindFirstChild("Humanoid") and CachedTarget.Parent.Humanoid.Health > 0 then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, CachedTarget.Position)
    else
        CachedTarget = nil
    end
end))

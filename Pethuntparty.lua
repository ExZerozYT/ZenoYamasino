-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========================================================
-- โฟลเดอร์และไฟล์บันทึกการตั้งค่าใน executor workspace (x2shifthub)
-- ========================================================
local SETTINGS_FOLDER = "x2shifthub"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/config.json"

local config = {
    AutoAttack = false,
    AutoSprint = false,
    AutoChest = false,
    AutoReplay = false,
    GuiPos = nil
}

-- อ่านการตั้งค่าจาก workspace/x2shifthub/config.json
local function loadSettings()
    pcall(function()
        if isfile and isfile(SETTINGS_FILE) then
            local raw = readfile(SETTINGS_FILE)
            if raw and #raw > 0 then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    if data.AutoAttack ~= nil then config.AutoAttack = data.AutoAttack end
                    if data.AutoSprint ~= nil then config.AutoSprint = data.AutoSprint end
                    if data.AutoChest ~= nil then config.AutoChest = data.AutoChest end
                    if data.AutoReplay ~= nil then config.AutoReplay = data.AutoReplay end
                    if data.GuiPos ~= nil and type(data.GuiPos) == "table" then
                        config.GuiPos = data.GuiPos
                    end
                end
            end
        end
    end)
end

-- บันทึกการตั้งค่าลง workspace/x2shifthub/config.json
local function saveSettings()
    pcall(function()
        if makefolder and not (isfolder and isfolder(SETTINGS_FOLDER)) then
            makefolder(SETTINGS_FOLDER)
        end
        if writefile then
            local payload = HttpService:JSONEncode(config)
            writefile(SETTINGS_FILE, payload)
        end
    end)
end

-- โหลดคอนฟิกทันทีที่เริ่มสคริปต์
loadSettings()

-- ScreenGui หลัก
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "x2shift_ButtonsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
    screenGui.Parent = game:GetService("CoreGui")
elseif gethui then
    screenGui.Parent = gethui()
else
    screenGui.Parent = playerGui
end

if screenGui.Parent:FindFirstChild("x2shift_ButtonsGui") and screenGui.Parent["x2shift_ButtonsGui"] ~= screenGui then
    screenGui.Parent["x2shift_ButtonsGui"]:Destroy()
end
if screenGui.Parent:FindFirstChild("x2shift_AutoHub") then
    screenGui.Parent["x2shift_AutoHub"]:Destroy()
end

-- ========================================================
-- แคช UI Elements ของเกม (ลดการวนลูปซ้ำซ้อน ไม่ให้แลค)
-- ========================================================
local cachedAutoBtn = nil
local cachedSprintBtn = nil

local function getCachedAutoBtn()
    if cachedAutoBtn and cachedAutoBtn.Parent then
        return cachedAutoBtn
    end
    pcall(function()
        local hotbar = playerGui:FindFirstChild("Hud")
            and playerGui.Hud:FindFirstChild("Root")
            and playerGui.Hud.Root:FindFirstChild("HudLayer")
            and playerGui.Hud.Root.HudLayer:FindFirstChild("Hotbar")
        
        if hotbar then
            for _, frame in ipairs(hotbar:GetDescendants()) do
                if frame:IsA("Frame") and frame:FindFirstChild("TextLabel") and frame.TextLabel:IsA("TextLabel") and frame.TextLabel.Text:find("AUTO") then
                    local tb = frame:FindFirstChildWhichIsA("TextButton", true)
                    if tb then
                        cachedAutoBtn = tb
                        return
                    end
                end
            end
        end
    end)
    return cachedAutoBtn
end

local function isGameAutoOn()
    local btn = getCachedAutoBtn()
    if btn and btn:IsA("GuiObject") then
        return btn.BackgroundColor3.G > 0.6
    end
    return false
end

local function clickGameAutoButton()
    local btn = getCachedAutoBtn()
    local activated = false

    if btn then
        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(btn.Activated)) do
                    conn:Fire()
                    activated = true
                end
            end
        end)
        if not activated and firesignal then
            pcall(function()
                firesignal(btn.Activated)
                activated = true
            end)
        end
    end

    if not activated then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
            task.wait(0.04)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        end)
    end
end

local function setGameAutoState(targetState)
    if isGameAutoOn() ~= targetState then
        clickGameAutoButton()
    end
end

-- ========================================================
-- ตรวจจับและควบคุมปุ่ม วิ่ง [Shift] ของเกม
-- ========================================================
local function getCachedSprintBtn()
    if cachedSprintBtn and cachedSprintBtn.Parent then
        return cachedSprintBtn
    end
    pcall(function()
        local hotbar = playerGui:FindFirstChild("Hud")
            and playerGui.Hud:FindFirstChild("Root")
            and playerGui.Hud.Root:FindFirstChild("HudLayer")
            and playerGui.Hud.Root.HudLayer:FindFirstChild("Hotbar")

        if hotbar then
            for _, frame in ipairs(hotbar:GetDescendants()) do
                if frame:IsA("Frame") and frame:FindFirstChild("TextLabel") and frame.TextLabel:IsA("TextLabel") and frame.TextLabel.Text == "วิ่ง" then
                    local tb = frame:FindFirstChildWhichIsA("TextButton", true)
                    if tb then
                        cachedSprintBtn = tb
                        return
                    end
                end
            end
        end
    end)
    return cachedSprintBtn
end

local function isGameSprintOn()
    local btn = getCachedSprintBtn()
    if btn and btn:IsA("GuiObject") then
        return btn.BackgroundColor3.G > 0.6
    end
    return false
end

local function clickGameSprintButton()
    local btn = getCachedSprintBtn()
    local activated = false

    if btn then
        pcall(function()
            if getconnections then
                for _, conn in ipairs(getconnections(btn.Activated)) do
                    conn:Fire()
                    activated = true
                end
            end
        end)
        if not activated and firesignal then
            pcall(function()
                firesignal(btn.Activated)
                activated = true
            end)
        end
    end

    if not activated then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
            task.wait(0.04)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        end)
    end
end

local function setGameSprintState(targetState)
    if isGameSprintOn() ~= targetState then
        clickGameSprintButton()
    end
end

-- ========================================================
-- ลอจิกการทำงานของปุ่ม E (เปิดกล่องปาร์ตี้ - ค้นหาเจาะจงเฉพาะกล่อง)
-- ========================================================
local function triggerOpenPartyChest()
    pcall(function()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local chests = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "Party Chest" then
                table.insert(chests, obj)
            end
        end

        local opened = false
        for _, chest in ipairs(chests) do
            local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and prompt.Enabled then
                local base = prompt.Parent
                if base and base:IsA("BasePart") then
                    local dist = (base.Position - root.Position).Magnitude
                    if dist <= (prompt.MaxActivationDistance + 4) then
                        if fireproximityprompt then
                            fireproximityprompt(prompt)
                            opened = true
                        else
                            prompt:InputHoldBegin()
                            task.wait(0.08)
                            prompt:InputHoldEnd()
                            opened = true
                        end
                    end
                end
            end
        end

        if not opened then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end)
end

-- ========================================================
-- ลอจิกการทำงานของปุ่ม เล่นซ้ำ (เจาะจงเฉพาะ DungeonPopup)
-- ========================================================
local function triggerReplayButton()
    pcall(function()
        local root = playerGui:FindFirstChild("Hud") and playerGui.Hud:FindFirstChild("Root")
        local popup = root and root:FindFirstChild("DungeonPopup")
        
        if popup and popup.Visible then
            for _, d in ipairs(popup:GetDescendants()) do
                if d:IsA("GuiButton") and d.Visible then
                    local hasText = (d:IsA("TextButton") and d.Text:find("เล่นซ้ำ"))
                    if not hasText and d:FindFirstChild("Caption") then
                        hasText = d.Caption.Text:find("เล่นซ้ำ")
                    end
                    if hasText then
                        if getconnections then
                            for _, c in ipairs(getconnections(d.Activated)) do
                                c:Fire()
                                return
                            end
                        end
                        if firesignal then
                            firesignal(d.Activated)
                            return
                        end
                    end
                end
            end
        end
    end)
end

-- ========================================================
-- สร้างหน้าต่างเมนูสไตล์โมเดิร์น (Panel พร้อมปุ่มสวิตช์ Toggle)
-- ========================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 230, 0, 268)

local defaultGuiPos = UDim2.new(0.82, 0, 0.40, 0)
if config.GuiPos and type(config.GuiPos) == "table" then
    defaultGuiPos = UDim2.new(
        config.GuiPos.XScale or 0.82,
        config.GuiPos.XOffset or 0,
        config.GuiPos.YScale or 0.40,
        config.GuiPos.YOffset or 0
    )
end
mainFrame.Position = defaultGuiPos
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(50, 54, 66)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- บันทึกตำแหน่งล่าสุดลง config.json ทันทีที่ลากวาง
mainFrame.DragStopped:Connect(function()
    config.GuiPos = {
        XScale = mainFrame.Position.X.Scale,
        XOffset = mainFrame.Position.X.Offset,
        YScale = mainFrame.Position.Y.Scale,
        YOffset = mainFrame.Position.Y.Offset
    }
    saveSettings()
end)

-- Header Bar
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerCover = Instance.new("Frame")
headerCover.Name = "HeaderCover"
headerCover.Size = UDim2.new(1, 0, 0, 10)
headerCover.Position = UDim2.new(0, 0, 1, -10)
headerCover.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
headerCover.BorderSizePixel = 0
headerCover.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -20, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡ Pet Hunt Party"
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 15
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local contentList = Instance.new("Frame")
contentList.Name = "ContentList"
contentList.Size = UDim2.new(1, -20, 1, -44)
contentList.Position = UDim2.new(0, 10, 0, 42)
contentList.BackgroundTransparency = 1
contentList.Parent = mainFrame

local uilist = Instance.new("UIListLayout")
uilist.Padding = UDim.new(0, 8)
uilist.SortOrder = Enum.SortOrder.LayoutOrder
uilist.Parent = contentList

-- ========================================================
-- ฟังก์ชันสร้างปุ่มสวิตช์ (Switch UI Component)
-- ========================================================
local function createSwitch(name, titleText, keyShortcut, layoutOrder, onToggleCallback)
    local row = Instance.new("TextButton")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = layoutOrder
    row.Parent = contentList

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = Color3.fromRGB(42, 46, 58)
    rowStroke.Thickness = 1
    rowStroke.Parent = row

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -66, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = titleText
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(235, 235, 240)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "SubLabel"
    subLabel.Size = UDim2.new(1, -66, 0, 16)
    subLabel.Position = UDim2.new(0, 10, 0, 26)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = (keyShortcut and #keyShortcut > 0) and ("คีย์ลัด: [" .. keyShortcut .. "]") or "ออโต้เมื่อจบล่า/ดัน"
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 11
    subLabel.TextColor3 = Color3.fromRGB(150, 155, 170)
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = row

    local switchTrack = Instance.new("Frame")
    switchTrack.Name = "SwitchTrack"
    switchTrack.Size = UDim2.new(0, 44, 0, 24)
    switchTrack.Position = UDim2.new(1, -52, 0.5, -12)
    switchTrack.BackgroundColor3 = Color3.fromRGB(48, 52, 65)
    switchTrack.BorderSizePixel = 0
    switchTrack.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = switchTrack

    local switchThumb = Instance.new("Frame")
    switchThumb.Name = "SwitchThumb"
    switchThumb.Size = UDim2.new(0, 18, 0, 18)
    switchThumb.Position = UDim2.new(0, 3, 0.5, -9)
    switchThumb.BackgroundColor3 = Color3.fromRGB(200, 205, 215)
    switchThumb.BorderSizePixel = 0
    switchThumb.Parent = switchTrack

    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = switchThumb

    local isEnabled = false

    local function setVisual(state, animate)
        isEnabled = state
        local targetTrackColor = isEnabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(48, 52, 65)
        local targetThumbColor = isEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 205, 215)
        local targetThumbPos = isEnabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)

        if animate then
            local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(switchTrack, tweenInfo, {BackgroundColor3 = targetTrackColor}):Play()
            TweenService:Create(switchThumb, tweenInfo, {
                Position = targetThumbPos,
                BackgroundColor3 = targetThumbColor
            }):Play()
        else
            switchTrack.BackgroundColor3 = targetTrackColor
            switchThumb.BackgroundColor3 = targetThumbColor
            switchThumb.Position = targetThumbPos
        end
    end

    row.MouseButton1Click:Connect(function()
        local newState = not isEnabled
        setVisual(newState, true)
        if onToggleCallback then
            onToggleCallback(newState)
        end
    end)

    return {
        SetState = function(state, animate)
            if isEnabled ~= state then
                setVisual(state, animate)
            end
        end,
        GetState = function()
            return isEnabled
        end
    }
end

-- ========================================================
-- ติดตั้งสวิตช์
-- ========================================================
-- 1. Auto Attack (R)
local attackSwitch = createSwitch("AutoAttackSwitch", "Auto Attack", "R", 1, function(newState)
    config.AutoAttack = newState
    saveSettings()
    setGameAutoState(newState)
end)

-- 2. Auto Sprint / วิ่ง (Shift)
local sprintSwitch = createSwitch("AutoSprintSwitch", "Auto Sprint (วิ่ง)", "Shift", 2, function(newState)
    config.AutoSprint = newState
    saveSettings()
    setGameSprintState(newState)
end)

-- 3. Auto Replay / เล่นซ้ำ
local replaySwitch = createSwitch("AutoReplaySwitch", "Auto เล่นซ้ำ", "", 3, function(newState)
    config.AutoReplay = newState
    saveSettings()
    if config.AutoReplay then
        triggerReplayButton()
    end
end)

-- 4. Auto Chest Party (E)
local chestSwitch = createSwitch("AutoChestSwitch", "Auto Chest Party", "E", 4, function(newState)
    config.AutoChest = newState
    saveSettings()
end)

-- นำค่าจาก config.json มาแสดงผลบนสวิตช์
attackSwitch.SetState(config.AutoAttack, false)
sprintSwitch.SetState(config.AutoSprint, false)
replaySwitch.SetState(config.AutoReplay, false)
chestSwitch.SetState(config.AutoChest, false)

-- นำสถานะ config มาเปิดใช้งานระบบในเกมตอนเริ่ม
task.spawn(function()
    task.wait(0.5)
    if config.AutoAttack then
        setGameAutoState(true)
    end
    if config.AutoSprint then
        setGameSprintState(true)
    end
end)

-- ========================================================
-- ซิงค์แบบ Event-Driven (ไม่มีลูปหนัก ไม่กิน CPU)
-- ========================================================
local function bindGameWatchers()
    local autoBtn = getCachedAutoBtn()
    if autoBtn then
        autoBtn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            local on = autoBtn.BackgroundColor3.G > 0.6
            if config.AutoAttack ~= on then
                config.AutoAttack = on
                attackSwitch.SetState(on, true)
                saveSettings()
            end
        end)
    end

    local sprintBtn = getCachedSprintBtn()
    if sprintBtn then
        sprintBtn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            local on = sprintBtn.BackgroundColor3.G > 0.6
            if config.AutoSprint ~= on then
                config.AutoSprint = on
                sprintSwitch.SetState(on, true)
                saveSettings()
            end
        end)
    end
end
bindGameWatchers()

-- ลูปเช็คซิงค์เบาๆ
task.spawn(function()
    while true do
        task.wait(0.5)
        
        local gameAutoStatus = isGameAutoOn()
        if config.AutoAttack ~= gameAutoStatus then
            config.AutoAttack = gameAutoStatus
            attackSwitch.SetState(gameAutoStatus, true)
            saveSettings()
        end

        local gameSprintStatus = isGameSprintOn()
        if config.AutoSprint ~= gameSprintStatus then
            config.AutoSprint = gameSprintStatus
            sprintSwitch.SetState(gameSprintStatus, true)
            saveSettings()
        end
    end
end)

-- ลูปทำงาน Auto Replay
task.spawn(function()
    while true do
        if config.AutoReplay then
            triggerReplayButton()
        end
        task.wait(1)
    end
end)

-- คีย์ลัด R และ Shift บนคีย์บอร์ด
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.R then
            task.wait(0.1)
            local gameStatus = isGameAutoOn()
            config.AutoAttack = gameStatus
            attackSwitch.SetState(gameStatus, true)
            saveSettings()
        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            task.wait(0.1)
            local sprintStatus = isGameSprintOn()
            config.AutoSprint = sprintStatus
            sprintSwitch.SetState(sprintStatus, true)
            saveSettings()
        end
    end
end)

-- ลูปเปิดกล่องปาร์ตี้ E
task.spawn(function()
    while true do
        if config.AutoChest then
            triggerOpenPartyChest()
        end
        task.wait(0.8)
    end
end)

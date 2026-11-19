-- ========================================================
-- mine.lua
-- Combined Pet Hunt Party + Auto Dungeon Hub
-- ========================================================

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local SETTINGS_FILE = SETTINGS_FOLDER .. "/mine_config.json"

local config = {
    -- Pet Hunt Party
    AutoAttack = false,
    AutoSprint = false,
    AutoChest = false,
    AutoReplay = false,
    -- Auto Dungeon
    AutoDungeon = false,
    SelectedDungeon = "all",
    PreferredDiff = "highest",
    AutoBuyKeys = false,
    -- UI
    GuiPos = nil,
    GuiCollapsed = false
}

local function loadSettings()
    pcall(function()
        if isfile and isfile(SETTINGS_FILE) then
            local raw = readfile(SETTINGS_FILE)
            if raw and #raw > 0 then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    for k, v in pairs(data) do
                        if config[k] ~= nil or k == "GuiPos" then
                            config[k] = v
                        end
                    end
                end
            end
        end
    end)
end

local function saveSettings()
    pcall(function()
        if makefolder and not (isfolder and isfolder(SETTINGS_FOLDER)) then
            makefolder(SETTINGS_FOLDER)
        end
        if writefile then
            writefile(SETTINGS_FILE, HttpService:JSONEncode(config))
        end
    end)
end

loadSettings()

-- ========================================================
-- ตรวจสอบว่าอยู่ในดันเจี้ยนหรือไม่ (ใช้ร่วมกันทั้งเปิดกล่องและลงดัน)
-- ========================================================
local function isInsideDungeon()
    local attr = player:GetAttribute("Dungeon") or player:GetAttribute("InDungeon")
    if attr then return true end

    local wsDungeons = workspace:FindFirstChild("Dungeons")
        or workspace:FindFirstChild("Dungeon")
        or workspace:FindFirstChild("Tower")
    if wsDungeons then
        if wsDungeons:FindFirstChild(player.Name) then
            return true
        end
        if #wsDungeons:GetChildren() > 0 then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, run in ipairs(wsDungeons:GetChildren()) do
                    local ok, pivot = pcall(function() return run:GetPivot() end)
                    if ok and pivot and (pivot.Position - root.Position).Magnitude < 600 then
                        return true
                    end
                end
            end
        end
    end

    local hud = playerGui:FindFirstChild("Hud")
    local rootGui = hud and hud:FindFirstChild("Root")
    if rootGui then
        if rootGui:FindFirstChild("DungeonPopup") or rootGui:FindFirstChild("WorldBossResults") then
            return true
        end
        local hudLayer = rootGui:FindFirstChild("HudLayer")
        if hudLayer and (hudLayer:FindFirstChild("DungeonStage") or hudLayer:FindFirstChild("TowerFloor")) then
            return true
        end
    end

    return false
end

-- ========================================================
-- แคช UI Elements ของเกม (Auto Attack & Sprint)
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
            for _, btn in ipairs(hotbar:GetDescendants()) do
                if btn:IsA("TextButton") then
                    for _, lbl in ipairs(btn:GetDescendants()) do
                        if lbl:IsA("TextLabel") and (lbl.Text:find("AUTO") or lbl.Text:find("ออโต้")) then
                            cachedAutoBtn = btn
                            return
                        end
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
    return nil
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
    local current = isGameAutoOn()
    if current ~= nil then
        if current ~= targetState then
            clickGameAutoButton()
        end
    else
        clickGameAutoButton()
    end
end

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
            for _, btn in ipairs(hotbar:GetDescendants()) do
                if btn:IsA("TextButton") then
                    for _, lbl in ipairs(btn:GetDescendants()) do
                        if lbl:IsA("TextLabel") and (lbl.Text == "Run" or lbl.Text == "Shift" or lbl.Text == "วิ่ง") then
                            cachedSprintBtn = btn
                            return
                        end
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
    return nil
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
    local current = isGameSprintOn()
    if current ~= nil then
        if current ~= targetState then
            clickGameSprintButton()
        end
    else
        clickGameSprintButton()
    end
end

-- ========================================================
-- ลอจิกเปิดกล่องปาร์ตี้ & กล่องบอสดันเจี้ยน (E)
-- ========================================================
local isMovingToChest = false
local CHEST_MAX_DISTANCE_WORLD = 80
local CHEST_MAX_DISTANCE_DUNGEON = 300

local function getBasePartForPrompt(prompt)
    if not prompt or not prompt.Parent then return nil end
    local p = prompt.Parent
    if p:IsA("BasePart") then
        return p
    elseif p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then
        return p.Parent
    end
    local model = prompt:FindFirstAncestorWhichIsA("Model")
    if model then
        return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function triggerOpenPartyChest()
    if isMovingToChest then return end

    pcall(function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not humanoid or humanoid.Health <= 0 then return end

        local inDungeon = isInsideDungeon()
        local maxScanDistance = inDungeon and CHEST_MAX_DISTANCE_DUNGEON or CHEST_MAX_DISTANCE_WORLD

        local candidatePrompts = {}
        local seenPrompts = {}

        local function checkAndAddPrompt(prompt)
            if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then return end
            if seenPrompts[prompt] then return end

            local pName = prompt.Name:lower()
            local actText = (prompt.ActionText or ""):lower()
            local objText = (prompt.ObjectText or ""):lower()
            local parentName = (prompt.Parent and prompt.Parent.Name or ""):lower()
            local ancModel = prompt:FindFirstAncestorWhichIsA("Model")
            local modelName = (ancModel and ancModel.Name or ""):lower()

            local isChest = pName:find("chest") or pName:find("box") or pName:find("open")
                or parentName:find("chest") or parentName:find("box") or parentName:find("prompt")
                or modelName:find("chest") or modelName:find("box")
                or actText:find("open") or actText:find("claim") or actText:find("collect") or actText:find("เปิด") or actText:find("รับ")
                or objText:find("chest") or objText:find("box") or objText:find("กล่อง") or objText:find("หีบ")

            if isChest then
                seenPrompts[prompt] = true
                table.insert(candidatePrompts, prompt)
            end
        end

        for _, obj in ipairs(workspace:GetChildren()) do
            local nameLower = obj.Name:lower()
            if nameLower:find("party chest") or nameLower:find("chest") or nameLower:find("box") then
                for _, p in ipairs(obj:GetDescendants()) do
                    checkAndAddPrompt(p)
                end
            end
        end

        local dungeonContainers = {
            workspace:FindFirstChild("Dungeons"),
            workspace:FindFirstChild("Dungeon"),
            workspace:FindFirstChild("Drops"),
            workspace:FindFirstChild("Chests"),
            workspace:FindFirstChild("Debris"),
            workspace:FindFirstChild("Tower")
        }

        for _, container in ipairs(dungeonContainers) do
            if container then
                for _, desc in ipairs(container:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") then
                        checkAndAddPrompt(desc)
                    end
                end
            end
        end

        local nearestBase = nil
        local nearestPrompt = nil
        local nearestDist = maxScanDistance

        for _, prompt in ipairs(candidatePrompts) do
            local base = getBasePartForPrompt(prompt)
            if base then
                local dist = (base.Position - root.Position).Magnitude
                if dist <= maxScanDistance and dist < nearestDist then
                    nearestDist = dist
                    nearestPrompt = prompt
                    nearestBase = base
                end
            end
        end

        if not nearestPrompt or not nearestBase then return end

        local maxRange = (nearestPrompt.MaxActivationDistance or 10) + 4

        local function openChest()
            if not (nearestPrompt and nearestPrompt.Parent and nearestPrompt.Enabled) then return false end
            if fireproximityprompt then
                fireproximityprompt(nearestPrompt)
                return true
            else
                local holdTime = nearestPrompt.HoldDuration or 0.1
                nearestPrompt:InputHoldBegin()
                task.wait(math.max(holdTime + 0.05, 0.1))
                nearestPrompt:InputHoldEnd()
                return true
            end
        end

        if nearestDist <= maxRange then
            if not openChest() then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
        else
            isMovingToChest = true
            local savedCFrame = root.CFrame

            local toRoot = (root.Position - nearestBase.Position)
            local flatOffset = Vector3.new(toRoot.X, 0, toRoot.Z)
            if flatOffset.Magnitude > 0.1 then
                flatOffset = flatOffset.Unit * 3.5
            else
                flatOffset = Vector3.new(0, 0, 3.5)
            end
            local targetPos = nearestBase.Position + flatOffset + Vector3.new(0, 1.5, 0)
            local targetCFrame = CFrame.new(targetPos, nearestBase.Position)

            local speed = 80
            local tweenTime = math.clamp(nearestDist / speed, 0.1, 4)

            local goTween = TweenService:Create(root, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                CFrame = targetCFrame
            })
            goTween:Play()
            goTween.Completed:Wait()

            task.wait(0.15)

            if not openChest() then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end

            task.wait(0.3)

            if root and root.Parent and humanoid.Health > 0 then
                local backDist = (savedCFrame.Position - root.Position).Magnitude
                local backTime = math.clamp(backDist / speed, 0.1, 4)
                local backTween = TweenService:Create(root, TweenInfo.new(backTime, Enum.EasingStyle.Linear), {
                    CFrame = savedCFrame
                })
                backTween:Play()
                backTween.Completed:Wait()
            end

            isMovingToChest = false
        end
    end)

    isMovingToChest = false
end

-- ========================================================
-- ลอจิก Auto Replay (DungeonPopup & WorldBossResults)
-- ========================================================
local function triggerReplayButton()
    pcall(function()
        local root = playerGui:FindFirstChild("Hud") and playerGui.Hud:FindFirstChild("Root")
        if not root then return end

        local popups = {
            root:FindFirstChild("DungeonPopup"),
            root:FindFirstChild("WorldBossResults")
        }

        for _, popup in ipairs(popups) do
            if popup and popup.Visible then
                for _, d in ipairs(popup:GetDescendants()) do
                    if d:IsA("GuiButton") and d.Visible then
                        local hasText = false
                        if d:IsA("TextButton") then
                            local t = d.Text:upper()
                            if t:find("REPLAY") or t:find("AGAIN") or t:find("RETRY") or d.Text:find("เล่นซ้ำ") then
                                hasText = true
                            end
                        end
                        if not hasText then
                            for _, child in ipairs(d:GetDescendants()) do
                                if child:IsA("TextLabel") then
                                    local ct = child.Text:upper()
                                    if ct:find("REPLAY") or ct:find("AGAIN") or ct:find("RETRY") or child.Text:find("เล่นซ้ำ") then
                                        hasText = true
                                        break
                                    end
                                end
                            end
                        end
                        if hasText then
                            local clicked = false
                            if getconnections then
                                for _, c in ipairs(getconnections(d.Activated)) do
                                    c:Fire()
                                    clicked = true
                                end
                            end
                            if not clicked and firesignal then
                                firesignal(d.Activated)
                                clicked = true
                            end
                            if clicked then return end
                        end
                    end
                end
            end
        end
    end)
end

-- ========================================================
-- ลอจิก Auto Dungeon (Dynamic Metadata & Net Interface)
-- ========================================================
local function getDungeonsConfig()
    local success, res = pcall(function()
        local shared = ReplicatedStorage:WaitForChild("Shared", 5)
        local cfg = shared and shared:WaitForChild("Config", 5)
        local dungeonsMod = cfg and cfg:WaitForChild("Dungeons", 5)
        if dungeonsMod then
            return require(dungeonsMod)
        end
    end)
    if success and res then return res end
    return nil
end

local function getDungeonRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes and remotes:FindFirstChild("Dungeon") then
        return remotes.Dungeon
    end
    local success, net = pcall(function()
        return require(ReplicatedStorage.Shared.Net)
    end)
    if success and net and net.func then
        return net.func("Dungeon")
    end
    return nil
end

local function invokeDungeon(...)
    local remote = getDungeonRemote()
    if remote then
        local success, res = pcall(function(...)
            return remote:InvokeServer(...)
        end, ...)
        if success then return res end
    end
    return { ok = false }
end

local function getAvailableDungeons()
    local Dungeons = getDungeonsConfig()
    if not Dungeons or not Dungeons.list then return {} end

    local myLevel = player:GetAttribute("Level") or 1
    local myGold = player:GetAttribute("Gold") or 0
    local available = {}

    local state = invokeDungeon("state")
    local keys = (state and state.keys) or 0
    local freeRuns = (state and state.free) or {}

    for _, d in ipairs(Dungeons.list) do
        local isSoon = d.soon
        if isSoon then
            if d.id == "gold" and Dungeons.vaultOpensAt then
                isSoon = (workspace:GetServerTimeNow() < Dungeons.vaultOpensAt)
            elseif d.endless and Dungeons.towerOpensAt then
                isSoon = (workspace:GetServerTimeNow() < Dungeons.towerOpensAt)
            end
        end

        if not isSoon then
            local defaultFree = d.freeRuns or Dungeons.freeRuns or 3
            local runsLeft = freeRuns[d.id]
            if runsLeft == nil then
                runsLeft = player:GetAttribute("DungeonFree_" .. d.id) or defaultFree
            end

            local canRun = (runsLeft > 0)
            if not canRun and d.keys == true then
                if keys > 0 then
                    canRun = true
                elseif config.AutoBuyKeys and myGold >= (d.keyPrice or Dungeons.keyPrice or 250000) then
                    canRun = true
                end
            end

            if d.endless or d.unlimited then
                canRun = true
            end

            local chosenDiff = nil
            if d.difficulties and #d.difficulties > 0 then
                if config.PreferredDiff == "hard" then
                    for _, diff in ipairs(d.difficulties) do
                        if diff.id == "hard" and myLevel >= (diff.level or 1) then
                            chosenDiff = diff
                            break
                        end
                    end
                elseif config.PreferredDiff == "normal" then
                    for _, diff in ipairs(d.difficulties) do
                        if diff.id == "normal" and myLevel >= (diff.level or 1) then
                            chosenDiff = diff
                            break
                        end
                    end
                end

                if not chosenDiff then
                    for i = #d.difficulties, 1, -1 do
                        local diff = d.difficulties[i]
                        if myLevel >= (diff.level or 1) then
                            chosenDiff = diff
                            break
                        end
                    end
                end
            else
                chosenDiff = { id = "normal", level = 1 }
            end

            if canRun and chosenDiff then
                table.insert(available, {
                    dungeon = d,
                    diff = chosenDiff,
                    runsLeft = runsLeft,
                    hasKeys = keys > 0
                })
            end
        end
    end

    return available
end

local isEntering = false
local function tryEnterDungeon()
    if isEntering or isInsideDungeon() then return end
    isEntering = true

    pcall(function()
        local list = getAvailableDungeons()
        if #list == 0 then return end

        local targetEntry = nil
        if config.SelectedDungeon ~= "all" then
            for _, item in ipairs(list) do
                if item.dungeon.id == config.SelectedDungeon then
                    targetEntry = item
                    break
                end
            end
        else
            targetEntry = list[1]
        end

        if not targetEntry then return end

        if targetEntry.dungeon.keys and not (targetEntry.runsLeft > 0) and not targetEntry.hasKeys then
            if config.AutoBuyKeys then
                invokeDungeon("buyKey")
                task.wait(0.5)
            end
        end

        local res = invokeDungeon("enter", targetEntry.dungeon.id, targetEntry.diff.id)
        if res and res.ok then
            if res.waiting then
                invokeDungeon("ready", true)
            end
        end
    end)

    task.wait(2)
    isEntering = false
end

-- ========================================================
-- สร้างหน้าต่างเมนูรวม (Mine Hub UI)
-- ========================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "x2shift_MineGui"
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

for _, oldName in ipairs({ "x2shift_MineGui", "x2shift_ButtonsGui", "x2shift_AutoDungeonGui", "x2shift_AutoHub" }) do
    local old = screenGui.Parent:FindFirstChild(oldName)
    if old and old ~= screenGui then
        old:Destroy()
    end
end

local EXPANDED_SIZE = UDim2.new(0, 260, 0, 444)
local COLLAPSED_SIZE = UDim2.new(0, 260, 0, 38)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = config.GuiCollapsed and COLLAPSED_SIZE or EXPANDED_SIZE
mainFrame.ClipsDescendants = true

local defaultGuiPos = UDim2.new(0.80, 0, 0.25, 0)
if config.GuiPos and type(config.GuiPos) == "table" then
    defaultGuiPos = UDim2.new(
        config.GuiPos.XScale or 0.80,
        config.GuiPos.XOffset or 0,
        config.GuiPos.YScale or 0.25,
        config.GuiPos.YOffset or 0
    )
end
mainFrame.Position = defaultGuiPos
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
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
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerCover = Instance.new("Frame")
headerCover.Name = "HeaderCover"
headerCover.Size = UDim2.new(1, 0, 0, 10)
headerCover.Position = UDim2.new(0, 0, 1, -10)
headerCover.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
headerCover.BorderSizePixel = 0
headerCover.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -54, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡ Mine Hub (Party + Dungeon)"
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local collapseBtn = Instance.new("TextButton")
collapseBtn.Name = "CollapseBtn"
collapseBtn.Size = UDim2.new(0, 24, 0, 24)
collapseBtn.Position = UDim2.new(1, -32, 0.5, -12)
collapseBtn.BackgroundColor3 = Color3.fromRGB(45, 49, 62)
collapseBtn.BorderSizePixel = 0
collapseBtn.Text = config.GuiCollapsed and "+" or "−"
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 16
collapseBtn.TextColor3 = Color3.fromRGB(235, 235, 240)
collapseBtn.Parent = header

local collapseCorner = Instance.new("UICorner")
collapseCorner.CornerRadius = UDim.new(0, 6)
collapseCorner.Parent = collapseBtn

local contentList = Instance.new("Frame")
contentList.Name = "ContentList"
contentList.Size = UDim2.new(1, -20, 1, -48)
contentList.Position = UDim2.new(0, 10, 0, 44)
contentList.BackgroundTransparency = 1
contentList.Visible = not config.GuiCollapsed
contentList.Parent = mainFrame

headerCover.Visible = not config.GuiCollapsed

local collapseTween = nil
local function setCollapsed(collapsed, animate)
    config.GuiCollapsed = collapsed
    collapseBtn.Text = collapsed and "+" or "−"
    headerCover.Visible = not collapsed

    if collapseTween then
        collapseTween:Cancel()
        collapseTween = nil
    end

    local targetSize = collapsed and COLLAPSED_SIZE or EXPANDED_SIZE
    if animate then
        if not collapsed then
            contentList.Visible = true
        end
        collapseTween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = targetSize }
        )
        collapseTween.Completed:Connect(function()
            if config.GuiCollapsed then
                contentList.Visible = false
            end
        end)
        collapseTween:Play()
    else
        mainFrame.Size = targetSize
        contentList.Visible = not collapsed
    end
end

collapseBtn.MouseButton1Click:Connect(function()
    setCollapsed(not config.GuiCollapsed, true)
    saveSettings()
end)

local uilist = Instance.new("UIListLayout")
uilist.Padding = UDim.new(0, 8)
uilist.SortOrder = Enum.SortOrder.LayoutOrder
uilist.Parent = contentList

-- Switch Component Helper
local function createSwitch(name, titleText, descText, layoutOrder, onToggleCallback)
    local row = Instance.new("TextButton")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
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
    subLabel.Text = descText
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
            TweenService:Create(switchTrack, tweenInfo, { BackgroundColor3 = targetTrackColor }):Play()
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
-- ติดตั้งสวิตช์ทั้งหมด
-- ========================================================
local attackSwitch = createSwitch("AutoAttackSwitch", "Auto Attack", "คีย์ลัด: [R]", 1, function(newState)
    config.AutoAttack = newState
    saveSettings()
    setGameAutoState(newState)
end)

local sprintSwitch = createSwitch("AutoSprintSwitch", "Auto Sprint (วิ่ง)", "คีย์ลัด: [Shift]", 2, function(newState)
    config.AutoSprint = newState
    saveSettings()
    setGameSprintState(newState)
end)

local chestSwitch = createSwitch("AutoChestSwitch", "Auto Chest Party", "คีย์ลัด: [E]", 3, function(newState)
    config.AutoChest = newState
    saveSettings()
end)

local replaySwitch = createSwitch("AutoReplaySwitch", "Auto Replay (เล่นซ้ำ)", "กดเล่นซ้ำทันทีเมื่อจบ", 4, function(newState)
    config.AutoReplay = newState
    saveSettings()
    if config.AutoReplay then
        triggerReplayButton()
    end
end)

local autoDungeonSwitch = createSwitch("AutoDungeonSwitch", "Auto Enter Dungeon", "ลงดันทั้งหมดอัตโนมัติ", 5, function(newState)
    config.AutoDungeon = newState
    saveSettings()
end)

local autoKeySwitch = createSwitch("AutoKeySwitch", "Auto Buy Keys", "ซื้อกุญแจอัตโนมัติเมื่อหมด", 6, function(newState)
    config.AutoBuyKeys = newState
    saveSettings()
end)

-- Difficulty Picker Row
local diffRow = Instance.new("Frame")
diffRow.Name = "DiffRow"
diffRow.Size = UDim2.new(1, 0, 0, 48)
diffRow.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
diffRow.BorderSizePixel = 0
diffRow.LayoutOrder = 7
diffRow.Parent = contentList

local diffCorner = Instance.new("UICorner")
diffCorner.CornerRadius = UDim.new(0, 8)
diffCorner.Parent = diffRow

local diffStroke = Instance.new("UIStroke")
diffStroke.Color = Color3.fromRGB(42, 46, 58)
diffStroke.Thickness = 1
diffStroke.Parent = diffRow

local diffLabel = Instance.new("TextLabel")
diffLabel.Name = "Label"
diffLabel.Size = UDim2.new(0.48, 0, 1, 0)
diffLabel.Position = UDim2.new(0, 10, 0, 0)
diffLabel.BackgroundTransparency = 1
diffLabel.Text = "ระดับความยาก:"
diffLabel.Font = Enum.Font.GothamBold
diffLabel.TextSize = 12
diffLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
diffLabel.TextXAlignment = Enum.TextXAlignment.Left
diffLabel.Parent = diffRow

local diffBtn = Instance.new("TextButton")
diffBtn.Name = "DiffBtn"
diffBtn.Size = UDim2.new(0.45, 0, 0, 30)
diffBtn.Position = UDim2.new(0.52, 0, 0.5, -15)
diffBtn.BackgroundColor3 = Color3.fromRGB(45, 49, 62)
diffBtn.BorderSizePixel = 0
diffBtn.Font = Enum.Font.GothamBold
diffBtn.TextSize = 11
diffBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
diffBtn.Parent = diffRow

local diffBtnCorner = Instance.new("UICorner")
diffBtnCorner.CornerRadius = UDim.new(0, 6)
diffBtnCorner.Parent = diffBtn

local diffModes = { "highest", "normal", "hard" }
local diffNames = { highest = "สูงสุดที่ไหว", normal = "ปกติ (Normal)", hard = "ยาก (Hard)" }

local function updateDiffBtn()
    diffBtn.Text = diffNames[config.PreferredDiff] or "สูงสุดที่ไหว"
end
updateDiffBtn()

diffBtn.MouseButton1Click:Connect(function()
    local curIdx = table.find(diffModes, config.PreferredDiff) or 1
    local nextIdx = (curIdx % #diffModes) + 1
    config.PreferredDiff = diffModes[nextIdx]
    updateDiffBtn()
    saveSettings()
end)

-- นำค่าจาก config มาแสดงผลบนสวิตช์
attackSwitch.SetState(config.AutoAttack, false)
sprintSwitch.SetState(config.AutoSprint, false)
chestSwitch.SetState(config.AutoChest, false)
replaySwitch.SetState(config.AutoReplay, false)
autoDungeonSwitch.SetState(config.AutoDungeon, false)
autoKeySwitch.SetState(config.AutoBuyKeys, false)

-- เปิดใช้งาน AutoAttack / AutoSprint ตามคอนฟิกตอนเริ่ม
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
-- ซิงค์ปุ่มเกมแบบ Event-Driven & Hotkeys (R / Shift)
-- ========================================================
local autoConn = nil
local sprintConn = nil

local function bindGameWatchers()
    local autoBtn = getCachedAutoBtn()
    if autoBtn and not autoConn then
        autoConn = autoBtn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            local on = autoBtn.BackgroundColor3.G > 0.6
            if config.AutoAttack ~= on then
                config.AutoAttack = on
                attackSwitch.SetState(on, true)
                saveSettings()
            end
        end)
    end

    local sprintBtn = getCachedSprintBtn()
    if sprintBtn and not sprintConn then
        sprintConn = sprintBtn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
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

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        if input.KeyCode == Enum.KeyCode.R then
            task.wait(0.15)
            local gameStatus = isGameAutoOn()
            if gameStatus ~= nil and config.AutoAttack ~= gameStatus then
                config.AutoAttack = gameStatus
                attackSwitch.SetState(gameStatus, true)
                saveSettings()
            end
        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            task.wait(0.15)
            local sprintStatus = isGameSprintOn()
            if sprintStatus ~= nil and config.AutoSprint ~= sprintStatus then
                config.AutoSprint = sprintStatus
                sprintSwitch.SetState(sprintStatus, true)
                saveSettings()
            end
        end
    end
end)

-- ========================================================
-- Background Loops
-- ========================================================
-- 1. ซิงค์สถานะ Auto Attack / Sprint
task.spawn(function()
    while true do
        task.wait(0.5)
        bindGameWatchers()

        local gameAutoStatus = isGameAutoOn()
        if gameAutoStatus ~= nil and config.AutoAttack ~= gameAutoStatus then
            config.AutoAttack = gameAutoStatus
            attackSwitch.SetState(gameAutoStatus, true)
            saveSettings()
        end

        local gameSprintStatus = isGameSprintOn()
        if gameSprintStatus ~= nil and config.AutoSprint ~= gameSprintStatus then
            config.AutoSprint = gameSprintStatus
            sprintSwitch.SetState(gameSprintStatus, true)
            saveSettings()
        end
    end
end)

-- 2. Auto Chest Party (E)
task.spawn(function()
    while true do
        if config.AutoChest then
            triggerOpenPartyChest()
        end
        task.wait(0.8)
    end
end)

-- 3. Auto Replay
task.spawn(function()
    while true do
        if config.AutoReplay then
            triggerReplayButton()
        end
        task.wait(1)
    end
end)

-- 4. Auto Enter Dungeon
task.spawn(function()
    while true do
        task.wait(2)
        if config.AutoDungeon and not isInsideDungeon() then
            tryEnterDungeon()
        end
    end
end)

-- 5. Auto Accept Ready / Join Popup
task.spawn(function()
    while true do
        task.wait(0.5)
        if config.AutoDungeon then
            pcall(function()
                local root = playerGui:FindFirstChild("Hud") and playerGui.Hud:FindFirstChild("Root")
                local popup = root and root:FindFirstChild("DungeonPopup")
                if popup and popup.Visible then
                    for _, btn in ipairs(popup:GetDescendants()) do
                        if btn:IsA("TextButton") and (btn.Text:find("เข้าร่วม") or btn.Text:upper():find("JOIN")) then
                            if getconnections then
                                for _, c in ipairs(getconnections(btn.Activated)) do
                                    c:Fire()
                                end
                            elseif firesignal then
                                firesignal(btn.Activated)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

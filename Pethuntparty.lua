-- ========================================================
-- PetHuntHub.lua
-- Language: Luau | Platform: Roblox (Executor) | Target: Pet Hunt Party
-- Unified Hub: Farm + Auto Dungeon + Boss Tracker
-- ========================================================

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========================================================
-- Settings & Persistence (x2shifthub)
-- ========================================================
local SETTINGS_FOLDER = "x2shifthub"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/pethunt_hub_config.json"

local config = {
    -- Farm
    AutoAttack = false,
    AutoSprint = false,
    AutoChest = false,
    AutoReplay = false,
    AutoRejoin = false,
    -- Dungeon
    AutoDungeon = false,
    SelectedDungeon = "all",
    PreferredDiff = "highest",
    DungeonCrypt = true,
    DungeonGold = true,
    DungeonEndless = true,
    -- Boss
    SelectedBoss = "Birdbath Owl",
    -- UI
    ActiveTab = "Farm",
    GuiPos = nil,
    GuiCollapsed = false,
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
-- Dungeon Detection
-- ========================================================
local lastInRunCheck = 0
local cachedInRun = false

local function getDungeonRemoteQuick()
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

local function isInsideDungeon(forceRefresh)
    local attr = player:GetAttribute("Dungeon") or player:GetAttribute("InDungeon")
    if attr then return true end

    local hud = playerGui:FindFirstChild("Hud")
    local rootGui = hud and hud:FindFirstChild("Root")
    if rootGui then
        local hudLayer = rootGui:FindFirstChild("HudLayer")
        if hudLayer then
            local dgStage = hudLayer:FindFirstChild("DungeonStage")
            local twFloor = hudLayer:FindFirstChild("TowerFloor")
            if (dgStage and dgStage.Visible) or (twFloor and twFloor.Visible) then
                return true
            end
        end
    end

    local now = os.clock()
    if forceRefresh or (now - lastInRunCheck) >= 1.5 then
        lastInRunCheck = now
        local remote = getDungeonRemoteQuick()
        if remote then
            local ok, st = pcall(function()
                return remote:InvokeServer("state")
            end)
            if ok and type(st) == "table" and st.inRun ~= nil then
                cachedInRun = (st.inRun == true)
            end
        end
    end

    return cachedInRun
end

-- ========================================================
-- Game UI Cache (Auto Attack & Sprint)
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
-- Auto Chest Party & Dungeon Chest (E)
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
            workspace:FindFirstChild("Tower"),
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
-- Auto Replay
-- ========================================================
local function triggerReplayButton()
    pcall(function()
        local root = playerGui:FindFirstChild("Hud") and playerGui.Hud:FindFirstChild("Root")
        if not root then return end

        local popups = {
            root:FindFirstChild("DungeonPopup"),
            root:FindFirstChild("WorldBossResults"),
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
-- Auto Dungeon Logic
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
                    hasKeys = keys > 0,
                })
            end
        end
    end

    return available
end

local function isDungeonEnabled(dungeonId)
    if dungeonId == "crypt" then return config.DungeonCrypt ~= false end
    if dungeonId == "gold" then return config.DungeonGold ~= false end
    if dungeonId == "endless" then return config.DungeonEndless ~= false end
    return true
end

local isEntering = false
local function tryEnterDungeon()
    if isEntering or isInsideDungeon() then return end
    isEntering = true

    pcall(function()
        local list = getAvailableDungeons()
        if #list == 0 then return end

        local targetEntry = nil
        for _, item in ipairs(list) do
            if isDungeonEnabled(item.dungeon.id) then
                if config.SelectedDungeon == "all" or item.dungeon.id == config.SelectedDungeon then
                    targetEntry = item
                    break
                end
            end
        end

        if not targetEntry then return end

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
-- Boss Data, Status & Flight System
-- ========================================================
local knownBossMap = {
    ["Birdbath Owl"] = { id = "birdbath_owl", field = "Field_backyard", level = 12 },
    ["Teacup Unicorn"] = { id = "teacup_unicorn", field = "Field_cafe", level = 22 },
    ["Lighthouse Narwhal"] = { id = "lighthouse_narwhal", field = "Field_splash", level = 32 },
    ["Rocking Pegasus"] = { id = "rocking_pegasus", field = "Field_toy", level = 42 },
    ["Crystal Qilin"] = { id = "crystal_qilin", field = "Field_gem", level = 52 },
    ["Snowflake Reindeer"] = { id = "snowflake_reindeer", field = "Field_snow", level = 62 },
    ["Eclipse Wolf"] = { id = "eclipse_wolf", field = "Field_moon", level = 70 },
    ["Thunderbird"] = { id = "thunderbird", field = "Field_sky", level = 77 },
    ["Golden Mask Jaguar"] = { id = "golden_mask_jaguar", field = "Field_jungle", level = 84 },
    ["Neon Motorbike Cheetah"] = { id = "neon_motorbike_cheetah", field = "Field_neon", level = 90 },
    ["Grimoire Griffin"] = { id = "grimoire_griffin", field = "Field_wizard", level = 95 },
    ["Erupting Volcano Tortoise"] = { id = "erupting_volcano_tortoise", field = "Field_volcano", level = 99 },
    ["Bramble Crown Bear"] = { id = "bramble_crown_bear", field = "Field_grove", level = 99 },
    ["Tempest Bell Roc"] = { id = "tempest_bell_roc", field = "Field_gale", level = 99 },
    ["Wishing Well Crocodile"] = { id = "wishing_well_crocodile", field = "Field_mist", level = 99 },
    ["Ember Obelisk Cobra"] = { id = "ember_obelisk_cobra", field = "Field_ember", level = 99 },
    ["Heartwood Shrine Yak"] = { id = "heartwood_shrine_yak", field = "Field_heart", level = 99 },
}

local function loadBossConfig()
    pcall(function()
        local mConfig = require(ReplicatedStorage.Shared.Config.Monsters)
        if mConfig and mConfig.defs then
            for id, data in pairs(mConfig.defs) do
                if data.isBoss and data.name and not id:find("^dg_") then
                    if knownBossMap[data.name] then
                        knownBossMap[data.name].id = id
                        knownBossMap[data.name].level = data.level or knownBossMap[data.name].level
                    else
                        knownBossMap[data.name] = {
                            id = id,
                            field = "Field_" .. (data.set or "custom"),
                            level = data.level or 1,
                        }
                    end
                end
            end
        end
    end)
end
loadBossConfig()

local function scanDynamicBosses()
    pcall(function()
        local monstersFolder = workspace:FindFirstChild("Monsters")
        if not monstersFolder then return end

        local counts = {}
        for _, m in ipairs(monstersFolder:GetChildren()) do
            if m:IsA("Model") then
                counts[m.Name] = (counts[m.Name] or 0) + 1
            end
        end

        for _, m in ipairs(monstersFolder:GetChildren()) do
            if m:IsA("Model") and counts[m.Name] == 1 and not knownBossMap[m.Name] then
                local lvl = m:GetAttribute("Level") or 1
                knownBossMap[m.Name] = { field = "Field_Custom", level = lvl }
            end
        end
    end)
end
scanDynamicBosses()

local function getBossLevel(bossName)
    local info = knownBossMap[bossName]
    if info and info.level then return info.level end
    local monsters = workspace:FindFirstChild("Monsters")
    if monsters then
        local m = monsters:FindFirstChild(bossName)
        if m then
            local lvl = m:GetAttribute("Level")
            if lvl then return lvl end
        end
    end
    return nil
end

local function getBossDisplayName(bossName)
    local lvl = getBossLevel(bossName)
    if lvl then
        return string.format("%s  [Lv.%d]", bossName, lvl)
    end
    return bossName
end

local function getBossModel(bossName)
    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return nil end
    local m = monsters:FindFirstChild(bossName)
    if m and m:IsA("Model") then return m end
    return nil
end

local function getBossId(bossName)
    local info = knownBossMap[bossName]
    if info and info.id then return info.id end
    return bossName:lower():gsub("%s+", "_")
end

local function getBossRespawnRemaining(bossName)
    local monsters = workspace:FindFirstChild("Monsters")
    if not monsters then return nil end
    local attrName = "BossBack_" .. getBossId(bossName)
    local respawnAt = monsters:GetAttribute(attrName)
    if type(respawnAt) == "number" then
        local now = workspace:GetServerTimeNow()
        local rem = math.ceil(respawnAt - now)
        if rem > 0 then
            return rem
        end
    end
    return nil
end

local function formatCountdown(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hrs = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hrs > 0 then
        return string.format("%02d:%02d:%02d", hrs, mins, secs)
    end
    return string.format("%02d:%02d", mins, secs)
end

local function getBossStatusInfo(bossName)
    local bossModel = getBossModel(bossName)
    if bossModel then
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return "ALIVE", "เกิดแล้ว", Color3.fromRGB(52, 211, 153)
        end
    end

    local rem = getBossRespawnRemaining(bossName)
    if rem then
        return "COOLDOWN", formatCountdown(rem), Color3.fromRGB(251, 191, 36)
    end

    if bossModel then
        return "DEAD", "ตายแล้ว", Color3.fromRGB(251, 191, 36)
    end

    return "WAITING", "ยังไม่เกิด", Color3.fromRGB(248, 113, 113)
end

-- ========================================================
-- Redesigned Modern Hub UI (Dark Slate + Cyan/Emerald)
-- ========================================================
local THEME = {
    Bg          = Color3.fromRGB(15, 17, 23),
    Surface     = Color3.fromRGB(22, 25, 34),
    SurfaceHi   = Color3.fromRGB(30, 35, 48),
    Border      = Color3.fromRGB(44, 50, 68),
    BorderHi    = Color3.fromRGB(68, 78, 106),
    TextPrimary = Color3.fromRGB(241, 245, 249),
    TextMuted   = Color3.fromRGB(148, 163, 184),
    Accent      = Color3.fromRGB(56, 189, 248),
    AccentDim   = Color3.fromRGB(24, 58, 82),
    Green       = Color3.fromRGB(52, 211, 153),
    Amber       = Color3.fromRGB(251, 191, 36),
    Red         = Color3.fromRGB(248, 113, 113),
    TrackOff    = Color3.fromRGB(45, 51, 66),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "x2shift_PetHuntHub"
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

for _, oldName in ipairs({
    "x2shift_PetHuntHub",
    "x2shift_MineGui",
    "x2shift_BossTrackerGui",
    "x2shift_ButtonsGui",
    "x2shift_AutoDungeonGui",
    "x2shift_AutoHub",
}) do
    local old = screenGui.Parent:FindFirstChild(oldName)
    if old and old ~= screenGui then
        old:Destroy()
    end
end

local EXPANDED_SIZE = UDim2.new(0, 310, 0, 406)
local COLLAPSED_SIZE = UDim2.new(0, 310, 0, 44)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = config.GuiCollapsed and COLLAPSED_SIZE or EXPANDED_SIZE
mainFrame.BackgroundColor3 = THEME.Bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Parent = screenGui

local defaultGuiPos = UDim2.new(0.75, 0, 0.22, 0)
if config.GuiPos and type(config.GuiPos) == "table" then
    defaultGuiPos = UDim2.new(
        config.GuiPos.XScale or 0.75,
        config.GuiPos.XOffset or 0,
        config.GuiPos.YScale or 0.22,
        config.GuiPos.YOffset or 0
    )
end
mainFrame.Position = defaultGuiPos

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = THEME.Border
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- ========================================================
-- Header + Custom Smooth Dragging
-- ========================================================
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = THEME.Surface
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

local headerMask = Instance.new("Frame")
headerMask.Name = "HeaderMask"
headerMask.Size = UDim2.new(1, 0, 0, 14)
headerMask.Position = UDim2.new(0, 0, 1, -14)
headerMask.BackgroundColor3 = THEME.Surface
headerMask.BorderSizePixel = 0
headerMask.Visible = not config.GuiCollapsed
headerMask.Parent = header

local headerDivider = Instance.new("Frame")
headerDivider.Size = UDim2.new(1, 0, 0, 1)
headerDivider.Position = UDim2.new(0, 0, 1, -1)
headerDivider.BackgroundColor3 = THEME.Border
headerDivider.BorderSizePixel = 0
headerDivider.Visible = not config.GuiCollapsed
headerDivider.Parent = header

-- Accent dot
local brandDot = Instance.new("Frame")
brandDot.Size = UDim2.new(0, 8, 0, 8)
brandDot.Position = UDim2.new(0, 14, 0.5, -4)
brandDot.BackgroundColor3 = THEME.Accent
brandDot.BorderSizePixel = 0
brandDot.Parent = header
Instance.new("UICorner", brandDot).CornerRadius = UDim.new(1, 0)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -130, 1, 0)
titleLabel.Position = UDim2.new(0, 28, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Zeno Yamasino hub"
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 13
titleLabel.TextColor3 = THEME.TextPrimary
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Active count badge
local activeBadge = Instance.new("TextLabel")
activeBadge.Name = "ActiveBadge"
activeBadge.Size = UDim2.new(0, 58, 0, 20)
activeBadge.Position = UDim2.new(1, -98, 0.5, -10)
activeBadge.BackgroundColor3 = THEME.AccentDim
activeBadge.BorderSizePixel = 0
activeBadge.Text = "0 ON"
activeBadge.Font = Enum.Font.GothamBold
activeBadge.TextSize = 10
activeBadge.TextColor3 = THEME.Accent
activeBadge.Parent = header
Instance.new("UICorner", activeBadge).CornerRadius = UDim.new(1, 0)

-- Collapse Button
local collapseBtn = Instance.new("TextButton")
collapseBtn.Name = "CollapseBtn"
collapseBtn.Size = UDim2.new(0, 26, 0, 26)
collapseBtn.Position = UDim2.new(1, -34, 0.5, -13)
collapseBtn.BackgroundColor3 = THEME.SurfaceHi
collapseBtn.BorderSizePixel = 0
collapseBtn.Text = config.GuiCollapsed and "+" or "−"
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 15
collapseBtn.TextColor3 = THEME.TextPrimary
collapseBtn.Parent = header
Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 7)

-- Smooth Drag on Header
do
    local dragging = false
    local dragStart, startPos

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            config.GuiPos = {
                XScale = mainFrame.Position.X.Scale,
                XOffset = mainFrame.Position.X.Offset,
                YScale = mainFrame.Position.Y.Scale,
                YOffset = mainFrame.Position.Y.Offset,
            }
            saveSettings()
        end
    end)
end

-- ========================================================
-- Body Container (Clipped when collapsed)
-- ========================================================
local bodyContainer = Instance.new("Frame")
bodyContainer.Name = "BodyContainer"
bodyContainer.Size = UDim2.new(1, 0, 1, -44)
bodyContainer.Position = UDim2.new(0, 0, 0, 44)
bodyContainer.BackgroundTransparency = 1
bodyContainer.Visible = not config.GuiCollapsed
bodyContainer.Parent = mainFrame

-- ========================================================
-- Segmented Tab Bar (Farm | Dungeon | Boss)
-- ========================================================
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -24, 0, 34)
tabBar.Position = UDim2.new(0, 12, 0, 10)
tabBar.BackgroundColor3 = THEME.Surface
tabBar.BorderSizePixel = 0
tabBar.Parent = bodyContainer
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 9)
local tabBarStroke = Instance.new("UIStroke", tabBar)
tabBarStroke.Color = THEME.Border
tabBarStroke.Thickness = 1

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local tabPadding = Instance.new("UIPadding", tabBar)
tabPadding.PaddingLeft = UDim.new(0, 4)
tabPadding.PaddingRight = UDim.new(0, 4)

local tabButtons = {}
local tabPages = {}

local pagesHolder = Instance.new("Frame")
pagesHolder.Name = "PagesHolder"
pagesHolder.Size = UDim2.new(1, -24, 1, -66)
pagesHolder.Position = UDim2.new(0, 12, 0, 54)
pagesHolder.BackgroundTransparency = 1
pagesHolder.Parent = bodyContainer

local function createTab(id, labelText, order)
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. id
    btn.Size = UDim2.new(1/3, -3, 0, 26)
    btn.BackgroundColor3 = THEME.Surface
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = labelText
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = THEME.TextMuted
    btn.LayoutOrder = order
    btn.Parent = tabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local page = Instance.new("Frame")
    page.Name = "Page_" .. id
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = pagesHolder

    tabButtons[id] = btn
    tabPages[id] = page
    return page
end

local farmPage = createTab("Farm", "Farm", 1)
local dungeonPage = createTab("Dungeon", "Dungeon", 2)
local bossPage = createTab("Boss", "Boss", 3)

local function setActiveTab(tabId, save)
    if not tabPages[tabId] then tabId = "Farm" end
    config.ActiveTab = tabId
    for id, page in pairs(tabPages) do
        local isSelected = (id == tabId)
        page.Visible = isSelected
        local btn = tabButtons[id]
        TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = isSelected and THEME.AccentDim or THEME.Surface,
            TextColor3 = isSelected and THEME.Accent or THEME.TextMuted,
        }):Play()
    end
    if save then
        saveSettings()
    end
end

for id, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        setActiveTab(id, true)
    end)
end

-- Footer hint
local footerHint = Instance.new("TextLabel")
footerHint.Size = UDim2.new(1, -24, 0, 14)
footerHint.Position = UDim2.new(0, 12, 1, -16)
footerHint.BackgroundTransparency = 1
footerHint.Text = "RightCtrl: ซ่อน/แสดงหน้าต่าง  •  x2shifthub"
footerHint.Font = Enum.Font.Gotham
footerHint.TextSize = 10
footerHint.TextColor3 = THEME.TextMuted
footerHint.TextXAlignment = Enum.TextXAlignment.Center
footerHint.Parent = bodyContainer

-- ========================================================
-- Active Badge Updater
-- ========================================================
local function updateActiveBadge()
    local count = 0
    if config.AutoAttack then count += 1 end
    if config.AutoSprint then count += 1 end
    if config.AutoChest then count += 1 end
    if config.AutoReplay then count += 1 end
    if config.AutoRejoin then count += 1 end
    if config.AutoDungeon then count += 1 end

    activeBadge.Text = count .. " ON"
    if count > 0 then
        activeBadge.BackgroundColor3 = Color3.fromRGB(16, 56, 44)
        activeBadge.TextColor3 = THEME.Green
    else
        activeBadge.BackgroundColor3 = THEME.SurfaceHi
        activeBadge.TextColor3 = THEME.TextMuted
    end
end

-- ========================================================
-- Reusable Modern Switch Component
-- ========================================================
local function createSwitch(parent, name, titleText, descText, layoutOrder, onToggleCallback)
    local row = Instance.new("TextButton")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = THEME.Surface
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = layoutOrder
    row.Parent = parent

    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = THEME.Border
    rowStroke.Thickness = 1

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, -68, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 7)
    label.BackgroundTransparency = 1
    label.Text = titleText
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = THEME.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "SubLabel"
    subLabel.Size = UDim2.new(1, -68, 0, 16)
    subLabel.Position = UDim2.new(0, 12, 0, 28)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = descText
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 10
    subLabel.TextColor3 = THEME.TextMuted
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = row

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 42, 0, 22)
    track.Position = UDim2.new(1, -54, 0.5, -11)
    track.BackgroundColor3 = THEME.TrackOff
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame")
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = UDim2.new(0, 3, 0.5, -8)
    thumb.BackgroundColor3 = Color3.fromRGB(203, 213, 225)
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local isEnabled = false

    local function setVisual(state, animate)
        isEnabled = state
        local tTrack = state and THEME.Green or THEME.TrackOff
        local tThumb = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(203, 213, 225)
        local tPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local tStroke = state and Color3.fromRGB(36, 98, 76) or THEME.Border

        if animate then
            local ti = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(track, ti, { BackgroundColor3 = tTrack }):Play()
            TweenService:Create(thumb, ti, { Position = tPos, BackgroundColor3 = tThumb }):Play()
            TweenService:Create(rowStroke, ti, { Color = tStroke }):Play()
        else
            track.BackgroundColor3 = tTrack
            thumb.BackgroundColor3 = tThumb
            thumb.Position = tPos
            rowStroke.Color = tStroke
        end
    end

    row.MouseButton1Click:Connect(function()
        local newState = not isEnabled
        setVisual(newState, true)
        if onToggleCallback then
            onToggleCallback(newState)
        end
        updateActiveBadge()
    end)

    return {
        SetState = function(state, animate)
            if isEnabled ~= state then
                setVisual(state, animate)
                updateActiveBadge()
            end
        end,
        GetState = function()
            return isEnabled
        end,
    }
end

-- ========================================================
-- TAB 1: FARM PAGE
-- ========================================================
local farmList = Instance.new("UIListLayout", farmPage)
farmList.Padding = UDim.new(0, 8)
farmList.SortOrder = Enum.SortOrder.LayoutOrder

local attackSwitch = createSwitch(farmPage, "AutoAttackSwitch", "Auto Attack", "ซิงค์ปุ่มโจมตีอัตโนมัติ  •  คีย์ลัด [R]", 1, function(state)
    config.AutoAttack = state
    saveSettings()
    setGameAutoState(state)
end)

local sprintSwitch = createSwitch(farmPage, "AutoSprintSwitch", "Auto Sprint", "เปิดวิ่งอัตโนมัติ  •  คีย์ลัด [Shift]", 2, function(state)
    config.AutoSprint = state
    saveSettings()
    setGameSprintState(state)
end)

local chestSwitch = createSwitch(farmPage, "AutoChestSwitch", "Auto Chest Party", "เดินเก็บกล่องปาร์ตี้ & กล่องบอสดัน [E]", 3, function(state)
    config.AutoChest = state
    saveSettings()
end)

local replaySwitch = createSwitch(farmPage, "AutoReplaySwitch", "Auto Replay", "กดเล่นซ้ำทันทีเมื่อจบดันหรือเวิลด์บอส", 4, function(state)
    config.AutoReplay = state
    saveSettings()
    if state then
        triggerReplayButton()
    end
end)

local rejoinSwitch = createSwitch(farmPage, "AutoRejoinSwitch", "Auto Rejoin", "เข้าเซิร์ฟเวอร์ใหม่อัตโนมัติเมื่อเน็ตหลุด/ถูกเตะ", 5, function(state)
    config.AutoRejoin = state
    saveSettings()
end)

-- ========================================================
-- TAB 2: DUNGEON PAGE
-- ========================================================
local dungeonList = Instance.new("UIListLayout", dungeonPage)
dungeonList.Padding = UDim.new(0, 8)
dungeonList.SortOrder = Enum.SortOrder.LayoutOrder

-- Live Dungeon Status Pill
local dgStatusCard = Instance.new("Frame")
dgStatusCard.Name = "DgStatusCard"
dgStatusCard.Size = UDim2.new(1, 0, 0, 34)
dgStatusCard.BackgroundColor3 = THEME.Surface
dgStatusCard.BorderSizePixel = 0
dgStatusCard.LayoutOrder = 1
dgStatusCard.Parent = dungeonPage
Instance.new("UICorner", dgStatusCard).CornerRadius = UDim.new(0, 10)
local dgStroke = Instance.new("UIStroke", dgStatusCard)
dgStroke.Color = THEME.Border
dgStroke.Thickness = 1

local dgDot = Instance.new("Frame", dgStatusCard)
dgDot.Size = UDim2.new(0, 8, 0, 8)
dgDot.Position = UDim2.new(0, 12, 0.5, -4)
dgDot.BackgroundColor3 = THEME.Accent
dgDot.BorderSizePixel = 0
Instance.new("UICorner", dgDot).CornerRadius = UDim.new(1, 0)

local dgStatusLabel = Instance.new("TextLabel", dgStatusCard)
dgStatusLabel.Size = UDim2.new(1, -34, 1, 0)
dgStatusLabel.Position = UDim2.new(0, 28, 0, 0)
dgStatusLabel.BackgroundTransparency = 1
dgStatusLabel.Text = "สถานะปัจจุบัน: อยู่ด้านนอก (Lobby)"
dgStatusLabel.Font = Enum.Font.GothamBold
dgStatusLabel.TextSize = 11
dgStatusLabel.TextColor3 = THEME.TextPrimary
dgStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

local autoDungeonSwitch = createSwitch(dungeonPage, "AutoDungeonSwitch", "Auto Enter Dungeon", "เข้าดันเจี้ยนที่เลือกอัตโนมัติ + กด Join", 2, function(state)
    config.AutoDungeon = state
    saveSettings()
end)

-- 3 Dungeon Selection Switches
local function createMiniSwitch(parent, name, titleText, layoutOrder, onToggleCallback)
    local row = Instance.new("TextButton")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3 = THEME.Bg
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = layoutOrder
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = titleText
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0, 34, 0, 18)
    track.Position = UDim2.new(1, -44, 0.5, -9)
    track.BackgroundColor3 = THEME.TrackOff
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = UDim2.new(0, 3, 0.5, -6)
    thumb.BackgroundColor3 = Color3.fromRGB(203, 213, 225)
    thumb.BorderSizePixel = 0
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local isEnabled = false
    local function setVisual(state, animate)
        isEnabled = state
        local tTrack = state and THEME.Green or THEME.TrackOff
        local tThumb = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(203, 213, 225)
        local tPos = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        if animate then
            local ti = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(track, ti, { BackgroundColor3 = tTrack }):Play()
            TweenService:Create(thumb, ti, { Position = tPos, BackgroundColor3 = tThumb }):Play()
        else
            track.BackgroundColor3 = tTrack
            thumb.BackgroundColor3 = tThumb
            thumb.Position = tPos
        end
    end

    row.MouseButton1Click:Connect(function()
        local newState = not isEnabled
        setVisual(newState, true)
        if onToggleCallback then onToggleCallback(newState) end
    end)

    return {
        SetState = function(state, animate)
            setVisual(state, animate)
        end,
    }
end

local dgFilterCard = Instance.new("Frame")
dgFilterCard.Name = "DgFilterCard"
dgFilterCard.Size = UDim2.new(1, 0, 0, 106)
dgFilterCard.BackgroundColor3 = THEME.Surface
dgFilterCard.BorderSizePixel = 0
dgFilterCard.LayoutOrder = 3
dgFilterCard.Parent = dungeonPage
Instance.new("UICorner", dgFilterCard).CornerRadius = UDim.new(0, 10)
local dgFilterStroke = Instance.new("UIStroke", dgFilterCard)
dgFilterStroke.Color = THEME.Border
dgFilterStroke.Thickness = 1

local dgFilterPad = Instance.new("UIPadding", dgFilterCard)
dgFilterPad.PaddingTop = UDim.new(0, 7)
dgFilterPad.PaddingBottom = UDim.new(0, 7)
dgFilterPad.PaddingLeft = UDim.new(0, 8)
dgFilterPad.PaddingRight = UDim.new(0, 8)

local dgFilterLayout = Instance.new("UIListLayout", dgFilterCard)
dgFilterLayout.Padding = UDim.new(0, 4)
dgFilterLayout.SortOrder = Enum.SortOrder.LayoutOrder

local cryptSwitch = createMiniSwitch(dgFilterCard, "DungeonCryptSwitch", "Grim Antler's Crypt", 1, function(state)
    config.DungeonCrypt = state
    saveSettings()
end)

local goldSwitch = createMiniSwitch(dgFilterCard, "DungeonGoldSwitch", "Golden Vault", 2, function(state)
    config.DungeonGold = state
    saveSettings()
end)

local endlessSwitch = createMiniSwitch(dgFilterCard, "DungeonEndlessSwitch", "Endless Tower", 3, function(state)
    config.DungeonEndless = state
    saveSettings()
end)

-- Segmented Difficulty Selector Card
local diffCard = Instance.new("Frame")
diffCard.Name = "DiffCard"
diffCard.Size = UDim2.new(1, 0, 0, 62)
diffCard.BackgroundColor3 = THEME.Surface
diffCard.BorderSizePixel = 0
diffCard.LayoutOrder = 4
diffCard.Parent = dungeonPage
Instance.new("UICorner", diffCard).CornerRadius = UDim.new(0, 10)
local diffCardStroke = Instance.new("UIStroke", diffCard)
diffCardStroke.Color = THEME.Border
diffCardStroke.Thickness = 1

local diffHeader = Instance.new("TextLabel", diffCard)
diffHeader.Size = UDim2.new(1, -24, 0, 18)
diffHeader.Position = UDim2.new(0, 12, 0, 8)
diffHeader.BackgroundTransparency = 1
diffHeader.Text = "ระดับความยากที่ต้องการ"
diffHeader.Font = Enum.Font.GothamBold
diffHeader.TextSize = 11
diffHeader.TextColor3 = THEME.TextMuted
diffHeader.TextXAlignment = Enum.TextXAlignment.Left

local diffSegmentHolder = Instance.new("Frame", diffCard)
diffSegmentHolder.Size = UDim2.new(1, -24, 0, 28)
diffSegmentHolder.Position = UDim2.new(0, 12, 0, 30)
diffSegmentHolder.BackgroundColor3 = THEME.Bg
diffSegmentHolder.BorderSizePixel = 0
Instance.new("UICorner", diffSegmentHolder).CornerRadius = UDim.new(0, 8)

local diffSegLayout = Instance.new("UIListLayout", diffSegmentHolder)
diffSegLayout.FillDirection = Enum.FillDirection.Horizontal
diffSegLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
diffSegLayout.VerticalAlignment = Enum.VerticalAlignment.Center
diffSegLayout.Padding = UDim.new(0, 4)

local diffButtons = {}
local diffOptions = {
    { id = "highest", label = "สูงสุดที่ไหว" },
    { id = "normal",  label = "Normal" },
    { id = "hard",    label = "Hard" },
}

local function updateDiffVisual()
    for _, opt in ipairs(diffOptions) do
        local b = diffButtons[opt.id]
        local active = (config.PreferredDiff == opt.id)
        b.BackgroundColor3 = active and THEME.AccentDim or Color3.fromRGB(20, 23, 31)
        b.TextColor3 = active and THEME.Amber or THEME.TextMuted
    end
end

for idx, opt in ipairs(diffOptions) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/3, -4, 0, 22)
    b.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = opt.label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.TextColor3 = THEME.TextMuted
    b.LayoutOrder = idx
    b.Parent = diffSegmentHolder
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    diffButtons[opt.id] = b
    b.MouseButton1Click:Connect(function()
        config.PreferredDiff = opt.id
        updateDiffVisual()
        saveSettings()
    end)
end
updateDiffVisual()

-- ========================================================
-- TAB 3: BOSS PAGE + ALL TIMERS SIDE PANEL
-- ========================================================
-- Boss Dropdown Button
local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Name = "DropdownButton"
dropdownBtn.Size = UDim2.new(1, 0, 0, 36)
dropdownBtn.Position = UDim2.new(0, 0, 0, 0)
dropdownBtn.BackgroundColor3 = THEME.Surface
dropdownBtn.BorderSizePixel = 0
dropdownBtn.Text = ""
dropdownBtn.AutoButtonColor = false
dropdownBtn.ZIndex = 5
dropdownBtn.Parent = bossPage
Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 10)
local ddStroke = Instance.new("UIStroke", dropdownBtn)
ddStroke.Color = THEME.BorderHi
ddStroke.Thickness = 1

local selectedLabel = Instance.new("TextLabel", dropdownBtn)
selectedLabel.Size = UDim2.new(1, -38, 1, 0)
selectedLabel.Position = UDim2.new(0, 12, 0, 0)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = getBossDisplayName(config.SelectedBoss)
selectedLabel.Font = Enum.Font.GothamBold
selectedLabel.TextSize = 12
selectedLabel.TextColor3 = THEME.TextPrimary
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
selectedLabel.ZIndex = 6

local arrowIcon = Instance.new("TextLabel", dropdownBtn)
arrowIcon.Size = UDim2.new(0, 22, 1, 0)
arrowIcon.Position = UDim2.new(1, -28, 0, 0)
arrowIcon.BackgroundTransparency = 1
arrowIcon.Text = "▼"
arrowIcon.Font = Enum.Font.GothamBold
arrowIcon.TextSize = 10
arrowIcon.TextColor3 = THEME.Accent
arrowIcon.ZIndex = 6

-- Boss Status Card
local statusCard = Instance.new("Frame", bossPage)
statusCard.Name = "StatusCard"
statusCard.Size = UDim2.new(1, 0, 0, 60)
statusCard.Position = UDim2.new(0, 0, 0, 44)
statusCard.BackgroundColor3 = THEME.Surface
statusCard.BorderSizePixel = 0
Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 10)
local scStroke = Instance.new("UIStroke", statusCard)
scStroke.Color = THEME.Border
scStroke.Thickness = 1

local statusIndicator = Instance.new("Frame", statusCard)
statusIndicator.Size = UDim2.new(0, 9, 0, 9)
statusIndicator.Position = UDim2.new(0, 12, 0, 14)
statusIndicator.BackgroundColor3 = THEME.Red
statusIndicator.BorderSizePixel = 0
Instance.new("UICorner", statusIndicator).CornerRadius = UDim.new(1, 0)

local statusText = Instance.new("TextLabel", statusCard)
statusText.Size = UDim2.new(1, -34, 0, 18)
statusText.Position = UDim2.new(0, 28, 0, 10)
statusText.BackgroundTransparency = 1
statusText.Text = "สถานะ: กำลังตรวจสอบ..."
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 12
statusText.TextColor3 = THEME.TextPrimary
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextTruncate = Enum.TextTruncate.AtEnd

local fieldText = Instance.new("TextLabel", statusCard)
fieldText.Size = UDim2.new(1, -24, 0, 16)
fieldText.Position = UDim2.new(0, 12, 0, 34)
fieldText.BackgroundTransparency = 1
fieldText.Text = "สถานที่: -"
fieldText.Font = Enum.Font.Gotham
fieldText.TextSize = 11
fieldText.TextColor3 = THEME.TextMuted
fieldText.TextXAlignment = Enum.TextXAlignment.Left

-- Action Button Row 1: All Boss Timers
local timerToggleBtn = Instance.new("TextButton", bossPage)
timerToggleBtn.Size = UDim2.new(1, 0, 0, 38)
timerToggleBtn.Position = UDim2.new(0, 0, 0, 114)
timerToggleBtn.BackgroundColor3 = THEME.SurfaceHi
timerToggleBtn.BorderSizePixel = 0
timerToggleBtn.Text = "ดูเวลาเกิดบอสทุกตัว"
timerToggleBtn.Font = Enum.Font.GothamBold
timerToggleBtn.TextSize = 11
timerToggleBtn.TextColor3 = THEME.TextPrimary
Instance.new("UICorner", timerToggleBtn).CornerRadius = UDim.new(0, 9)
local ttStroke = Instance.new("UIStroke", timerToggleBtn)
ttStroke.Color = THEME.BorderHi
ttStroke.Thickness = 1

-- Action Row 2: Server Hop Button
local hopBtn = Instance.new("TextButton", bossPage)
hopBtn.Name = "ServerHopButton"
hopBtn.Size = UDim2.new(1, 0, 0, 38)
hopBtn.Position = UDim2.new(0, 0, 0, 160)
hopBtn.BackgroundColor3 = Color3.fromRGB(36, 54, 96)
hopBtn.BorderSizePixel = 0
hopBtn.Text = "Server Hop (ย้ายเซิร์ฟเวอร์)"
hopBtn.Font = Enum.Font.GothamBold
hopBtn.TextSize = 11
hopBtn.TextColor3 = Color3.fromRGB(226, 238, 255)
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 9)
local hopStroke = Instance.new("UIStroke", hopBtn)
hopStroke.Color = Color3.fromRGB(64, 96, 168)
hopStroke.Thickness = 1

local isHopping = false
local function serverHop()
    if isHopping then return end
    isHopping = true
    hopBtn.Text = "กำลังค้นหาเซิร์ฟเวอร์..."
    hopBtn.BackgroundColor3 = THEME.SurfaceHi

    task.spawn(function()
        local placeId = game.PlaceId
        local currentJobId = game.JobId
        local servers = {}

        local ok, res = pcall(function()
            local url = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                placeId
            )
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if ok and type(res) == "table" and type(res.data) == "table" then
            for _, srv in ipairs(res.data) do
                if type(srv) == "table"
                    and srv.id
                    and srv.id ~= currentJobId
                    and tonumber(srv.playing)
                    and tonumber(srv.maxPlayers)
                    and srv.playing < srv.maxPlayers
                then
                    table.insert(servers, srv.id)
                end
            end
        end

        if #servers > 0 then
            local targetId = servers[math.random(1, #servers)]
            hopBtn.Text = "กำลังย้ายเซิร์ฟเวอร์..."
            local tpOk = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, targetId, player)
            end)
            if not tpOk then
                pcall(function()
                    TeleportService:Teleport(placeId, player)
                end)
            end
        else
            hopBtn.Text = "ย้ายเซิร์ฟเวอร์ (Auto)..."
            pcall(function()
                TeleportService:Teleport(placeId, player)
            end)
        end

        task.wait(5)
        isHopping = false
        hopBtn.Text = "Server Hop (ย้ายเซิร์ฟเวอร์)"
        hopBtn.BackgroundColor3 = Color3.fromRGB(36, 54, 96)
    end)
end

hopBtn.MouseButton1Click:Connect(serverHop)

-- Dropdown List Overlay
local dropdownListFrame = Instance.new("Frame", bossPage)
dropdownListFrame.Name = "DropdownList"
dropdownListFrame.Size = UDim2.new(1, 0, 0, 195)
dropdownListFrame.Position = UDim2.new(0, 0, 0, 40)
dropdownListFrame.BackgroundColor3 = THEME.Bg
dropdownListFrame.BorderSizePixel = 0
dropdownListFrame.Visible = false
dropdownListFrame.ZIndex = 20
Instance.new("UICorner", dropdownListFrame).CornerRadius = UDim.new(0, 10)
local ddlStroke = Instance.new("UIStroke", dropdownListFrame)
ddlStroke.Color = THEME.BorderHi
ddlStroke.Thickness = 1.5

local scrollList = Instance.new("ScrollingFrame", dropdownListFrame)
scrollList.Size = UDim2.new(1, -8, 1, -10)
scrollList.Position = UDim2.new(0, 4, 0, 5)
scrollList.BackgroundTransparency = 1
scrollList.ScrollBarThickness = 4
scrollList.ScrollBarImageColor3 = THEME.BorderHi
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.ZIndex = 21

local listLayout = Instance.new("UIListLayout", scrollList)
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
end)

-- ========================================================
-- All Boss Timers Side Panel
-- ========================================================
local timerPanel = Instance.new("Frame", mainFrame)
timerPanel.Name = "AllBossTimerPanel"
timerPanel.Size = UDim2.new(0, 276, 0, 406)
timerPanel.Position = UDim2.new(0, -284, 0, 0)
timerPanel.BackgroundColor3 = THEME.Bg
timerPanel.BorderSizePixel = 0
timerPanel.Visible = false
timerPanel.ZIndex = 10
Instance.new("UICorner", timerPanel).CornerRadius = UDim.new(0, 14)
local tpPanelStroke = Instance.new("UIStroke", timerPanel)
tpPanelStroke.Color = THEME.Border
tpPanelStroke.Thickness = 1.5

local tpHeader = Instance.new("Frame", timerPanel)
tpHeader.Size = UDim2.new(1, 0, 0, 44)
tpHeader.BackgroundColor3 = THEME.Surface
tpHeader.BorderSizePixel = 0
tpHeader.ZIndex = 11
Instance.new("UICorner", tpHeader).CornerRadius = UDim.new(0, 14)

local tpHeaderMask = Instance.new("Frame", tpHeader)
tpHeaderMask.Size = UDim2.new(1, 0, 0, 14)
tpHeaderMask.Position = UDim2.new(0, 0, 1, -14)
tpHeaderMask.BackgroundColor3 = THEME.Surface
tpHeaderMask.BorderSizePixel = 0
tpHeaderMask.ZIndex = 11

local tpTitle = Instance.new("TextLabel", tpHeader)
tpTitle.Size = UDim2.new(1, -24, 1, 0)
tpTitle.Position = UDim2.new(0, 14, 0, 0)
tpTitle.BackgroundTransparency = 1
tpTitle.Text = "BOSS TIMERS (คลิกเพื่อเลือก)"
tpTitle.Font = Enum.Font.GothamBlack
tpTitle.TextSize = 12
tpTitle.TextColor3 = THEME.TextPrimary
tpTitle.TextXAlignment = Enum.TextXAlignment.Left
tpTitle.ZIndex = 12

local tpScroll = Instance.new("ScrollingFrame", timerPanel)
tpScroll.Size = UDim2.new(1, -12, 1, -54)
tpScroll.Position = UDim2.new(0, 6, 0, 48)
tpScroll.BackgroundTransparency = 1
tpScroll.ScrollBarThickness = 4
tpScroll.ScrollBarImageColor3 = THEME.BorderHi
tpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tpScroll.ZIndex = 11

local tpLayout = Instance.new("UIListLayout", tpScroll)
tpLayout.Padding = UDim.new(0, 4)
tpLayout.SortOrder = Enum.SortOrder.LayoutOrder
tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tpScroll.CanvasSize = UDim2.new(0, 0, 0, tpLayout.AbsoluteContentSize.Y + 6)
end)

local timerRowRefs = {}

local function updateTimerPanelUI()
    if not timerPanel.Visible then return end
    for bossName, refs in pairs(timerRowRefs) do
        local _, label, color = getBossStatusInfo(bossName)
        refs.dot.BackgroundColor3 = color
        refs.timeLabel.Text = label
        refs.timeLabel.TextColor3 = color
        refs.row.BackgroundColor3 = (config.SelectedBoss == bossName)
            and THEME.SurfaceHi
            or THEME.Surface
    end
end

local function updateBossStatusUI()
    local selected = config.SelectedBoss
    selectedLabel.Text = getBossDisplayName(selected)

    local bossModel = getBossModel(selected)
    local info = knownBossMap[selected]
    local field = (info and info.field) or "ไม่ระบุ"
    local rem = getBossRespawnRemaining(selected)

    if bossModel then
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        local alive = hum and hum.Health > 0

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local distText = ""
        if root then
            local bossPos = (bossModel.PrimaryPart and bossModel.PrimaryPart.Position) or bossModel:GetAttribute("Home")
            if typeof(bossPos) ~= "Vector3" then
                bossPos = bossModel:GetPivot().Position
            end
            local dist = math.floor((bossPos - root.Position).Magnitude)
            distText = string.format(" (%d ม.)", dist)
        end

        if alive then
            statusIndicator.BackgroundColor3 = THEME.Green
            statusText.Text = "บอสเกิดแล้ว! (ALIVE)" .. distText
        elseif rem then
            statusIndicator.BackgroundColor3 = THEME.Amber
            statusText.Text = string.format("รอเกิด (%s)", formatCountdown(rem))
        else
            statusIndicator.BackgroundColor3 = THEME.Amber
            statusText.Text = "บอสตายแล้ว (DEAD)" .. distText
        end
    else
        if rem then
            statusIndicator.BackgroundColor3 = THEME.Amber
            statusText.Text = string.format("รอเกิด (%s)", formatCountdown(rem))
        else
            statusIndicator.BackgroundColor3 = THEME.Red
            statusText.Text = "ยังไม่เกิด (WAITING)"
        end
    end
    fieldText.Text = "สถานที่: " .. field

    updateTimerPanelUI()
end

local function getSortedBossList()
    local list = {}
    for bName, bData in pairs(knownBossMap) do
        local lvl = (type(bData) == "table" and bData.level) or 1
        table.insert(list, { name = bName, level = lvl })
    end
    table.sort(list, function(a, b)
        if a.level == b.level then
            return a.name < b.name
        end
        return a.level < b.level
    end)
    return list
end

local populateDropdownItems
populateDropdownItems = function()
    for _, ch in ipairs(scrollList:GetChildren()) do
        if ch:IsA("TextButton") then
            ch:Destroy()
        end
    end

    for order, item in ipairs(getSortedBossList()) do
        local name = item.name
        local lvl = item.level
        local isSelected = (config.SelectedBoss == name)

        local itemBtn = Instance.new("TextButton")
        itemBtn.Name = "Item_" .. name
        itemBtn.Size = UDim2.new(1, -6, 0, 28)
        itemBtn.BackgroundColor3 = isSelected and THEME.AccentDim or THEME.Surface
        itemBtn.BorderSizePixel = 0
        itemBtn.Text = ""
        itemBtn.AutoButtonColor = true
        itemBtn.LayoutOrder = order
        itemBtn.ZIndex = 22
        itemBtn.Parent = scrollList
        Instance.new("UICorner", itemBtn).CornerRadius = UDim.new(0, 7)

        local nameLabel = Instance.new("TextLabel", itemBtn)
        nameLabel.Size = UDim2.new(1, -108, 1, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 11
        nameLabel.TextColor3 = isSelected and THEME.Accent or THEME.TextPrimary
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Text = name
        nameLabel.ZIndex = 23

        local _, statusShort, statusCol = getBossStatusInfo(name)
        local timeBadge = Instance.new("TextLabel", itemBtn)
        timeBadge.Size = UDim2.new(0, 52, 1, 0)
        timeBadge.Position = UDim2.new(1, -98, 0, 0)
        timeBadge.BackgroundTransparency = 1
        timeBadge.Font = Enum.Font.GothamBold
        timeBadge.TextSize = 10
        timeBadge.TextColor3 = statusCol
        timeBadge.TextXAlignment = Enum.TextXAlignment.Right
        timeBadge.Text = statusShort
        timeBadge.ZIndex = 23

        local levelBadge = Instance.new("TextLabel", itemBtn)
        levelBadge.Size = UDim2.new(0, 42, 1, 0)
        levelBadge.Position = UDim2.new(1, -46, 0, 0)
        levelBadge.BackgroundTransparency = 1
        levelBadge.Font = Enum.Font.GothamBold
        levelBadge.TextSize = 10
        levelBadge.TextColor3 = THEME.Amber
        levelBadge.TextXAlignment = Enum.TextXAlignment.Right
        levelBadge.Text = string.format("Lv.%d", lvl)
        levelBadge.ZIndex = 23

        itemBtn.MouseButton1Click:Connect(function()
            config.SelectedBoss = name
            saveSettings()
            dropdownListFrame.Visible = false
            arrowIcon.Text = "▼"
            updateBossStatusUI()
            populateDropdownItems()
        end)
    end
end

local function populateTimerPanel()
    for _, ch in ipairs(tpScroll:GetChildren()) do
        if ch:IsA("TextButton") then
            ch:Destroy()
        end
    end
    timerRowRefs = {}

    for order, item in ipairs(getSortedBossList()) do
        local name = item.name
        local lvl = item.level

        local row = Instance.new("TextButton")
        row.Name = "TimerRow_" .. name
        row.Size = UDim2.new(1, -6, 0, 28)
        row.BackgroundColor3 = (config.SelectedBoss == name) and THEME.SurfaceHi or THEME.Surface
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = true
        row.LayoutOrder = order
        row.ZIndex = 12
        row.Parent = tpScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

        local dot = Instance.new("Frame", row)
        dot.Size = UDim2.new(0, 7, 0, 7)
        dot.Position = UDim2.new(0, 8, 0.5, -3)
        dot.BackgroundColor3 = THEME.Red
        dot.BorderSizePixel = 0
        dot.ZIndex = 13
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local bNameLabel = Instance.new("TextLabel", row)
        bNameLabel.Size = UDim2.new(1, -118, 1, 0)
        bNameLabel.Position = UDim2.new(0, 20, 0, 0)
        bNameLabel.BackgroundTransparency = 1
        bNameLabel.Font = Enum.Font.GothamMedium
        bNameLabel.TextSize = 11
        bNameLabel.TextColor3 = THEME.TextPrimary
        bNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        bNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        bNameLabel.Text = name
        bNameLabel.ZIndex = 13

        local lvlLabel = Instance.new("TextLabel", row)
        lvlLabel.Size = UDim2.new(0, 34, 1, 0)
        lvlLabel.Position = UDim2.new(1, -96, 0, 0)
        lvlLabel.BackgroundTransparency = 1
        lvlLabel.Font = Enum.Font.Gotham
        lvlLabel.TextSize = 10
        lvlLabel.TextColor3 = THEME.TextMuted
        lvlLabel.TextXAlignment = Enum.TextXAlignment.Right
        lvlLabel.Text = string.format("Lv.%d", lvl)
        lvlLabel.ZIndex = 13

        local timeLabel = Instance.new("TextLabel", row)
        timeLabel.Size = UDim2.new(0, 56, 1, 0)
        timeLabel.Position = UDim2.new(1, -60, 0, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Font = Enum.Font.GothamBold
        timeLabel.TextSize = 11
        timeLabel.TextColor3 = THEME.Red
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        timeLabel.Text = "-"
        timeLabel.ZIndex = 13

        timerRowRefs[name] = {
            row = row,
            dot = dot,
            timeLabel = timeLabel,
        }

        row.MouseButton1Click:Connect(function()
            config.SelectedBoss = name
            saveSettings()
            updateBossStatusUI()
            populateDropdownItems()
        end)
    end

    updateTimerPanelUI()
end

dropdownBtn.MouseButton1Click:Connect(function()
    dropdownListFrame.Visible = not dropdownListFrame.Visible
    arrowIcon.Text = dropdownListFrame.Visible and "▲" or "▼"
    if dropdownListFrame.Visible then
        scanDynamicBosses()
        populateDropdownItems()
    end
end)

timerToggleBtn.MouseButton1Click:Connect(function()
    timerPanel.Visible = not timerPanel.Visible
    if timerPanel.Visible then
        timerToggleBtn.BackgroundColor3 = Color3.fromRGB(16, 56, 44)
        timerToggleBtn.TextColor3 = THEME.Green
        scanDynamicBosses()
        populateTimerPanel()
    else
        timerToggleBtn.BackgroundColor3 = THEME.SurfaceHi
        timerToggleBtn.TextColor3 = THEME.TextPrimary
    end
end)

-- ========================================================
-- Collapse / Expand Logic
-- ========================================================
local collapseTween = nil
local function setCollapsed(collapsed, animate)
    config.GuiCollapsed = collapsed
    collapseBtn.Text = collapsed and "+" or "−"
    headerMask.Visible = not collapsed
    headerDivider.Visible = not collapsed

    if collapsed then
        timerPanel.Visible = false
        timerToggleBtn.BackgroundColor3 = THEME.SurfaceHi
        timerToggleBtn.TextColor3 = THEME.TextPrimary
        dropdownListFrame.Visible = false
        arrowIcon.Text = "▼"
    end

    if collapseTween then
        collapseTween:Cancel()
        collapseTween = nil
    end

    local targetSize = collapsed and COLLAPSED_SIZE or EXPANDED_SIZE
    if animate then
        if not collapsed then
            bodyContainer.Visible = true
        end
        collapseTween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = targetSize }
        )
        collapseTween.Completed:Connect(function()
            if config.GuiCollapsed then
                bodyContainer.Visible = false
            end
        end)
        collapseTween:Play()
    else
        mainFrame.Size = targetSize
        bodyContainer.Visible = not collapsed
    end
end

collapseBtn.MouseButton1Click:Connect(function()
    setCollapsed(not config.GuiCollapsed, true)
    saveSettings()
end)

-- ========================================================
-- Hydrate Initial UI State
-- ========================================================
attackSwitch.SetState(config.AutoAttack, false)
sprintSwitch.SetState(config.AutoSprint, false)
chestSwitch.SetState(config.AutoChest, false)
replaySwitch.SetState(config.AutoReplay, false)
rejoinSwitch.SetState(config.AutoRejoin, false)
autoDungeonSwitch.SetState(config.AutoDungeon, false)
cryptSwitch.SetState(config.DungeonCrypt ~= false, false)
goldSwitch.SetState(config.DungeonGold ~= false, false)
endlessSwitch.SetState(config.DungeonEndless ~= false, false)
updateActiveBadge()

setActiveTab(config.ActiveTab or "Farm", false)
populateDropdownItems()
populateTimerPanel()
updateBossStatusUI()

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
-- Event-Driven Watchers & Hotkeys
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
    -- Close boss dropdown when clicking outside
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dropdownListFrame.Visible then
            local mousePos = UserInputService:GetMouseLocation()
            local listAbs = dropdownListFrame.AbsolutePosition
            local listSize = dropdownListFrame.AbsoluteSize
            local btnAbs = dropdownBtn.AbsolutePosition
            local btnSize = dropdownBtn.AbsoluteSize

            local inList = mousePos.X >= listAbs.X and mousePos.X <= (listAbs.X + listSize.X)
                       and mousePos.Y >= (listAbs.Y + 36) and mousePos.Y <= (listAbs.Y + listSize.Y + 36)
            local inBtn = mousePos.X >= btnAbs.X and mousePos.X <= (btnAbs.X + btnSize.X)
                      and mousePos.Y >= (btnAbs.Y + 36) and mousePos.Y <= (btnAbs.Y + btnSize.Y + 36)

            if not inList and not inBtn then
                dropdownListFrame.Visible = false
                arrowIcon.Text = "▼"
            end
        end
    end

    if not processed then
        if input.KeyCode == Enum.KeyCode.RightControl then
            screenGui.Enabled = not screenGui.Enabled
        elseif input.KeyCode == Enum.KeyCode.R then
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
-- 1. Sync Auto Attack / Sprint + Dungeon Status Indicator
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

        local inDg = isInsideDungeon()
        if inDg then
            dgDot.BackgroundColor3 = THEME.Green
            dgStatusLabel.Text = "สถานะปัจจุบัน: อยู่ในดันเจี้ยน (In Dungeon)"
        else
            dgDot.BackgroundColor3 = THEME.Accent
            dgStatusLabel.Text = "สถานะปัจจุบัน: อยู่ด้านนอก (Lobby)"
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

-- 6. Boss Status UI Updater
task.spawn(function()
    while true do
        task.wait(0.3)
        updateBossStatusUI()
    end
end)

-- 7. Auto Rejoin on Disconnect / Network Drop
local isRejoining = false
local function triggerAutoRejoin()
    if not config.AutoRejoin or isRejoining then return end
    isRejoining = true

    task.spawn(function()
        while config.AutoRejoin do
            local ok = pcall(function()
                if #Players:GetPlayers() <= 1 then
                    TeleportService:Teleport(game.PlaceId, player)
                else
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                end
            end)
            if not ok then
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, player)
                end)
            end
            task.wait(3)
        end
        isRejoining = false
    end)
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if config.AutoRejoin and msg and msg ~= "" then
            triggerAutoRejoin()
        end
    end)
end)

pcall(function()
    local promptOverlay = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5)
        and game:GetService("CoreGui").RobloxPromptGui:FindFirstChild("promptOverlay")
    if promptOverlay then
        promptOverlay.ChildAdded:Connect(function(child)
            if config.AutoRejoin and child.Name == "ErrorPrompt" then
                triggerAutoRejoin()
            end
        end)
    end
end)

print("[x2shift] PetHuntHub (Farm + Dungeon + Boss) Loaded!")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer

-- Optimized settings
local insertSpeed = 0.1
local collectSpeed = 0.1
local sellInterval = 1
local autoInsert = false
local autoSell = false
local autoCollect = false
local autoRejoin = true
local instantActions = false

-- Optimized caching system
local protectedItems = {}
local cachedPlot = nil
local cachedPlatforms = nil
local cachedInventory = nil
local lastCacheUpdate = 0
local cacheInterval = 2 -- Reduced cache interval

-- Heartbeat connection for optimized loops
local heartbeatConnection = nil
local lastInsertTime = 0
local lastCollectTime = 0
local lastSellTime = 0

local characterNames = {
    "Ballerina Cappuccina", "Blueberrinni Octopussini", "Bobrito Bandito",
    "Bombardino Crocodilo", "Bombombini Gusini", "Boneca Ambalabu",
    "Brr Brr Patapim", "Cappuccino Assassino", "Chimpanzini Bananini",
    "Elephantuchi Bananuchi", "Frigo Camelo", "Girafa Celestre",
    "Glorbo Fruttodrillo", "La Vaca Saturno Saturnita", "Lirili Larila",
    "Rhino Toasterino", "Tralalero Tralala", "Trippi Troppi",
    "Trulimero Trulicina", "Tung Tung Sahur"
}

local Window = Fluent:CreateWindow({
    Title = "COMBO_DOCHT",
    SubTitle = "Verzögerungsfreie Leistung",
    TabWidth = 180,
    Size = UDim2.fromOffset(650, 520),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Haupt", Icon = "zap" }),
    Tools = Window:AddTab({ Title = "Tools", Icon = "wrench" }),
    Settings = Window:AddTab({ Title = "Einstellungen", Icon = "cog" })
}

local ignoreItems = {
    ["Mini Coil"] = true, ["Cheese"] = true, ["Darkmatter Coil"] = true,
    ["Frost Coil"] = true, ["Improved Coil"] = true, ["Megaphone"] = true,
    ["Mythical Speakers"] = true, ["Rainbow Coil"] = true, ["Speed Coil"] = true,
    ["Super Coil"] = true,
}

-- Optimized cache update function
local function updateCache()
    local currentTime = tick()
    if currentTime - lastCacheUpdate > cacheInterval then
        cachedPlot = nil
        cachedPlatforms = nil
        cachedInventory = nil
        lastCacheUpdate = currentTime
    end
end

local function findMyPlot()
    local plotsFolder = Workspace:WaitForChild("Gameplay"):WaitForChild("Plots")
    local playerName = localPlayer.Name
    
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        local spawn = plot:FindFirstChild("SpawnPart")
        if owner and spawn and spawn:FindFirstChild("BillboardGui") then
            local tl = spawn.BillboardGui:FindFirstChild("TextLabel")
            if (owner.Value == localPlayer) or (tl and tl.Text:lower():find(playerName:lower())) then
                return plot
            end
        end
    end
    return nil
end

local function getPlayerPlot()
    updateCache()
    if cachedPlot then return cachedPlot end
    cachedPlot = findMyPlot()
    return cachedPlot
end

local function getPlatforms()
    updateCache()
    if cachedPlatforms then return cachedPlatforms end
    local plot = getPlayerPlot()
    if plot then
        cachedPlatforms = plot:FindFirstChild("Platforms")
    end
    return cachedPlatforms
end

local function getInventory()
    updateCache()
    if cachedInventory then return cachedInventory end
    cachedInventory = localPlayer:FindFirstChild("Inventory")
    return cachedInventory
end

local function isItemProtected(itemName)
    if not itemName then return false end
    
    -- Direct name match
    if protectedItems[itemName] then return true end
    
    -- Check for partial matches (in case of name variations)
    for protectedName, isProtected in pairs(protectedItems) do
        if isProtected and string.find(itemName:lower(), protectedName:lower(), 1, true) then
            return true
        end
    end
    
    return false
end

local function isPlatformAvailable(platform)
    if not platform then return false end
    local model = platform:FindFirstChild("Model")
    if not model then return true end
    local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
    if not humanoid then return true end
    return humanoid.Health <= 0
end

local function getFirstInventoryItemName()
    local inv = getInventory()
    if not inv then return nil end
    for _, item in ipairs(inv:GetChildren()) do
        -- Check if item is in ignore list OR protected
        if not ignoreItems[item.Name] and not isItemProtected(item.Name) then
            local platformRef = item:FindFirstChild("Platform")
            if not platformRef or not platformRef.Value then
                return item.Name
            end
        end
    end
    return nil
end

-- Optimized insert function
local function insertIntoPlatform(platform)
    local success, result = pcall(function()
        local platName = tostring(platform.Name)
        local itemName = getFirstInventoryItemName()
        if not itemName then return false end

        local targetPlayerRef = Players:FindFirstChild(localPlayer.Name)
        if not targetPlayerRef then return false end
        
        local platformsRef = targetPlayerRef:FindFirstChild("Platforms")
        local inventoryRef = targetPlayerRef:FindFirstChild("Inventory")
        if not platformsRef or not inventoryRef then return false end
        
        local platformRef = platformsRef:FindFirstChild(platName)
        local itemRef = inventoryRef:FindFirstChild(itemName)
        if not platformRef or not itemRef then return false end

        local args = {[1] = platformRef, [2] = itemRef}
        ReplicatedStorage.Events.Gameplay.InsertCharacter:InvokeServer(unpack(args))
        return true
    end)
    
    return success and result
end

-- Optimized auto insert
local function optimizedAutoInsert()
    local platforms = getPlatforms()
    if not platforms then return end
    
    local insertCount = 0
    for _, platform in ipairs(platforms:GetChildren()) do
        if isPlatformAvailable(platform) and insertCount < 3 then -- Limit concurrent inserts
            if insertIntoPlatform(platform) then
                insertCount = insertCount + 1
            end
        end
    end
end

-- Optimized sell function
local function sellPlatform(platformNum)
    local success = pcall(function()
        local targetPlayerRef = Players:FindFirstChild(localPlayer.Name)
        if not targetPlayerRef then return false end
        
        local platformsRef = targetPlayerRef:FindFirstChild("Platforms")
        if not platformsRef then return false end
        
        local platformRef = platformsRef:FindFirstChild(tostring(platformNum))
        if not platformRef then return false end
        
        local args = {[1] = platformRef}
        ReplicatedStorage.Events.Gameplay.SellCharacter:InvokeServer(unpack(args))
        return true
    end)
    return success
end

-- Optimized sell all
local function optimizedSellAll()
    local platforms = getPlatforms()
    if not platforms then return end
    
    local sellCount = 0
    for _, plat in ipairs(platforms:GetChildren()) do
        local model = plat:FindFirstChild("Model")
        -- Check if model exists AND is not protected before selling
        if model and not isItemProtected(model.Name) and sellCount < 5 then -- Limit concurrent sells
            if sellPlatform(plat.Name) then
                sellCount = sellCount + 1
            end
        end
    end
end

-- Optimized collect function
local function optimizedCollectDummy()
    local success, result = pcall(function()
        local dummyFolder = Workspace.Gameplay:FindFirstChild("Dummys")
        if not dummyFolder then return 0 end
        
        local bestDummies = {}
        for _, dummyModel in pairs(dummyFolder:GetChildren()) do
            if dummyModel:IsA("Model") and dummyModel:FindFirstChild("HumanoidRootPart") then
                local overhead = dummyModel.HumanoidRootPart:FindFirstChild("DummyOverhead")
                if overhead and overhead:FindFirstChild("Frame") and overhead.Frame:FindFirstChild("Give") then
                    local giveAmount = tonumber(overhead.Frame.Give.Text:match("%d+")) or 0
                    if giveAmount > 0 then
                        table.insert(bestDummies, {name = dummyModel.Name, amount = giveAmount})
                    end
                end
            end
        end
        
        if #bestDummies == 0 then return 0 end
        
        -- Sort and take top 3
        table.sort(bestDummies, function(a, b) return a.amount > b.amount end)
        local collectCount = math.min(3, #bestDummies)
        
        local collected = 0
        local values = ReplicatedStorage:FindFirstChild("Values")
        if not values then return 0 end
        
        local dummys = values:FindFirstChild("Dummys")
        if not dummys then return 0 end
        
        for i = 1, collectCount do
            local dummyValue = dummys:FindFirstChild(bestDummies[i].name)
            if dummyValue then
                ReplicatedStorage.Events.Gameplay.PickupDummy:InvokeServer(dummyValue)
                collected = collected + 1
            end
        end
        
        return collected
    end)
    
    return success and result or 0
end

-- Single optimized loop using RunService.Heartbeat
local function startOptimizedLoop()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
    end
    
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Auto Insert with timing
        if autoInsert and (currentTime - lastInsertTime) >= insertSpeed then
            optimizedAutoInsert()
            lastInsertTime = currentTime
        end
        
        -- Auto Collect with timing
        if autoCollect and (currentTime - lastCollectTime) >= collectSpeed then
            optimizedCollectDummy()
            lastCollectTime = currentTime
        end
        
        -- Auto Sell with timing
        if autoSell and (currentTime - lastSellTime) >= sellInterval then
            optimizedSellAll()
            lastSellTime = currentTime
        end
    end)
end

-- Anti-AFK (simplified)
local function optimizedAntiAFK()
    spawn(function()
        while autoRejoin do
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            wait(30)
        end
    end)
end

local function setupAutoRejoin()
    pcall(function()
        game.CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                wait(1)
                TeleportService:Teleport(game.PlaceId)
            end
        end)
    end)
end

local function unlockEverything()
    local tools = {
        "Cheese", "Darkmatter Coil", "Frost Coil", "Improved Coil", "Megaphone",
        "Mini Coil", "Mythical Speakers", "Rainbow Coil", "Speed Coil", "Super Coil"
    }
    
    local backpack = localPlayer:WaitForChild("Backpack")
    local addedCount = 0
    
    for _, toolName in ipairs(tools) do
        local toolPath = ReplicatedStorage:FindFirstChild("Models")
        if toolPath then toolPath = toolPath:FindFirstChild("Tools") end
        if toolPath then toolPath = toolPath:FindFirstChild(toolName) end
        if toolPath then
            local clonedTool = toolPath:Clone()
            clonedTool.Parent = backpack
            addedCount = addedCount + 1
        end
    end
    
    Fluent:Notify({
        Title = "WERKZEUGE FREIGESCHALTET",
        Content = "Hinzugefügt" .. addedCount .. " tools!",
        Duration = 3
    })
end

local function createProtectedToggles()
    for _, characterName in ipairs(characterNames) do
        protectedItems[characterName] = false
        
        Tabs.Main:AddToggle("Protect_" .. characterName:gsub("[^%w]", ""), {
            Title = "Schützt" .. characterName,
            Default = false,
            Callback = function(value)
                protectedItems[characterName] = value
            end
        })
    end
end

-- Debug function
local function debugPlotInfo()
    local plot = getPlayerPlot()
    if plot then
        Fluent:Notify({
            Title = "GRUNDSTÜCK GEFUNDEN",
            Content = "Plot: " .. plot.Name,
            Duration = 3
        })
        
        local platforms = getPlatforms()
        if platforms then
            Fluent:Notify({
                Title = "PLATFORMS",
                Content = "Gefunden" .. #platforms:GetChildren() .. " platforms",
                Duration = 3
            })
        end
    else
        Fluent:Notify({
            Title = "ERROR",
            Content = "Nicht gefunden!",
            Duration = 5
        })
    end
end

-- Main Controls
Tabs.Main:AddToggle("AutoInsert", {
    Title = "Automatisch einfügen",
    Default = false,
    Callback = function(value) 
        autoInsert = value 
        if value then
            Fluent:Notify({Title = "Automatisch einfügen", Content = "Enabled!", Duration = 2})
        end
    end
})

Tabs.Main:AddSlider("InsertSpeed", {
    Title = "Geschwindigkeit einfügen",
    Min = 0.1,
    Max = 5,
    Default = 0.5,
    Rounding = 1,
    Callback = function(value) insertSpeed = value end
})

Tabs.Main:AddToggle("AutoCollect", {
    Title = "Automatisches Sammeln",
    Default = false,
    Callback = function(value) 
        autoCollect = value 
        if value then
            Fluent:Notify({Title = "AUTOMATISCHES SAMMELN", Content = "Enabled!", Duration = 2})
        end
    end
})

Tabs.Main:AddSlider("CollectSpeed", {
    Title = "Sammle Geschwindigkeit",
    Min = 0.1,
    Max = 5,
    Default = 0.5,
    Rounding = 1,
    Callback = function(value) collectSpeed = value end
})

Tabs.Main:AddToggle("AutoSell", {
    Title = "Automatischer Verkauf",
    Default = false,
    Callback = function(value) 
        autoSell = value 
        if value then
            Fluent:Notify({Title = "AUTOMATISCH VERKAUFEN", Content = "Enabled!", Duration = 2})
        end
    end
})

Tabs.Main:AddSlider("SellInterval", {
    Title = "Verkaufsgeschwindigkeit",
    Min = 0.5,
    Max = 10,
    Default = 2,
    Rounding = 1,
    Callback = function(value) sellInterval = value end
})

Tabs.Main:AddButton({
    Title = "Einstellungen optimieren",
    Callback = function()
        insertSpeed = 0.5
        collectSpeed = 0.3
        sellInterval = 1.5
        Fluent:Notify({Title = "OPTIMIERTES", Content = "Settings optimized for performance!", Duration = 3})
    end
})

-- Tools Tab (removed manual buttons, kept essential tools)
Tabs.Tools:AddButton({
    Title = "Debug-Plot-Info",
    Callback = function() debugPlotInfo() end
})

Tabs.Tools:AddButton({
    Title = "Alle Tools freischalten",
    Callback = function() unlockEverything() end
})

Tabs.Tools:AddButton({
    Title = "Teleportieren zum besten Dummy",
    Callback = function()
        pcall(function()
            local bestDummy, highestAmount = nil, 0
            local dummyFolder = Workspace.Gameplay:FindFirstChild("Dummys")
            
            if dummyFolder then
                for _, dummy in pairs(dummyFolder:GetChildren()) do
                    if dummy:IsA("Model") and dummy:FindFirstChild("HumanoidRootPart") then
                        local overhead = dummy.HumanoidRootPart:FindFirstChild("DummyOverhead")
                        if overhead and overhead:FindFirstChild("Frame") and overhead.Frame:FindFirstChild("Give") then
                            local amount = tonumber(overhead.Frame.Give.Text:match("%d+")) or 0
                            if amount > highestAmount then
                                highestAmount = amount
                                bestDummy = dummy
                            end
                        end
                    end
                end
            end
            
            if bestDummy and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                localPlayer.Character.HumanoidRootPart.CFrame = bestDummy.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                Fluent:Notify({Title = "TELEPORTIERT", Content = "Value: " .. highestAmount, Duration = 3})
            end
        end)
    end
})

-- Settings Tab
Tabs.Settings:AddToggle("AutoRejoin", {
    Title = "Automatisch wieder beitreten",
    Default = true,
    Callback = function(value) autoRejoin = value end
})

-- Initialize everything
createProtectedToggles()
startOptimizedLoop()
optimizedAntiAFK()
setupAutoRejoin()

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("COMBO_WICK_DOMINATOR")
SaveManager:SetFolder("COMBO_WICK_DOMINATOR/optimized")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

Fluent:Notify({
    Title = "COMBO_DOCHT OPTIMIERT",
    Content = "LAG-FREIES Skript erfolgreich geladen!",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()

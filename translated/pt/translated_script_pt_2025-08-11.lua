local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local config = {
    autoFarmRunning = false,
    teleportDistance = 1000000,
    baseTeleportDistance = 1000000,
    resetTeleportDistance = 900000,
    height = 200,
    flySpeed = 100,
    returnDelay = 2.0,
    characterLoadDelay = 1.0,
    cycleDelay = 0.5,
    useInstantReturn = true,
    launchWaitTime = 1.5,
    launchRetryAttempts = 5,
    launchRetryDelay = 0.3,
    antiAfkEnabled = true
}

local flyConnection
local teleportCount = 0
local returnCount = 0
local returnTimer = nil
local remoteCache = {}
local antiAfkConnections = {}

local function setupAntiAfk()
    if not config.antiAfkEnabled then return end
    
    antiAfkConnections[1] = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    antiAfkConnections[2] = task.spawn(function()
        while config.antiAfkEnabled do
            task.wait(60)
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.5)
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end)
    
    antiAfkConnections[3] = task.spawn(function()
        while config.antiAfkEnabled do
            task.wait(120)
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(Vector2.new(0,0))
            task.wait(0.1)
            VirtualUser:Button1Up(Vector2.new(0,0))
        end
    end)
    
    antiAfkConnections[4] = task.spawn(function()
        while config.antiAfkEnabled do
            task.wait(90)
            keypress(0x20)
            task.wait(0.1)
            keyrelease(0x20)
        end
    end)
end

local function stopAntiAfk()
    for _, connection in pairs(antiAfkConnections) do
        if connection and connection.Connected then
            connection:Disconnect()
        elseif connection then
            task.cancel(connection)
        end
    end
    antiAfkConnections = {}
end

local function cacheRemotes()
    spawn(function()
        local success = pcall(function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
            if remotes then
                remoteCache.Launch = remotes:WaitForChild("Launch", 10)
                remoteCache.Return = remotes:WaitForChild("Return", 10)
            end
        end)
    end)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local character = getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function alive()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if root and humanoid and humanoid.Health > 0 then
            return true
        end
    end
    return false
end

local function launchCar()
    local success = false
    local attempts = 0
    
    while not success and attempts < config.launchRetryAttempts do
        attempts = attempts + 1
        
        if remoteCache.Launch then
            success = pcall(function()
                remoteCache.Launch:FireServer()
            end)
        end
        
        if not success then
            success = pcall(function()
                local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
                local launch = remotes:WaitForChild("Launch", 5)
                launch:FireServer()
            end)
        end
        
        if success then
            task.wait(config.launchWaitTime)
            return true
        else
            if attempts < config.launchRetryAttempts then
                task.wait(config.launchRetryDelay)
            end
        end
    end
    
    return false
end

local function returnCar()
    local success = false
    local attempts = 0
    
    while not success and attempts < 3 do
        attempts = attempts + 1
        
        if remoteCache.Return then
            success = pcall(function()
                remoteCache.Return:FireServer()
            end)
        else
            success = pcall(function()
                local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
                local returnRemote = remotes:WaitForChild("Return", 5)
                returnRemote:FireServer()
            end)
        end
        
        if not success and attempts < 3 then
            task.wait(0.2)
        end
    end
    
    if success then
        returnCount = returnCount + 1
        return true
    else
        return false
    end
end

local function startFlying()
    if config.useInstantReturn then
        return
    end
    
    local root = getRoot()
    if not root then return end
    
    local startPos = root.Position
    
    flyConnection = RunService.Heartbeat:Connect(function()
        local currentRoot = getRoot()
        if not currentRoot or not alive() then
            stopFlying()
            return
        end
        
        local currentPos = currentRoot.Position
        local moveAmount = config.flySpeed / 60
        
        currentRoot.CFrame = CFrame.new(
            Vector3.new(
                currentPos.X + moveAmount,
                config.height,
                currentPos.Z
            ),
            Vector3.new(
                currentPos.X + moveAmount + 1,
                config.height,
                currentPos.Z
            )
        )
    end)
end

local function stopFlying()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    
    if returnTimer then
        task.cancel(returnTimer)
        returnTimer = nil
    end
end

local function safeTeleport()
    local root = getRoot()
    if not root or not alive() then 
        return false
    end
    
    stopFlying()
    
    local launchSuccess = launchCar()
    if not launchSuccess then
        return false
    end
    
    if teleportCount % 5 == 0 and teleportCount > 0 then
        config.teleportDistance = config.resetTeleportDistance
    else
        config.teleportDistance = config.baseTeleportDistance
    end
    
    local currentPos = root.Position
    local newPos = Vector3.new(
        currentPos.X + config.teleportDistance,
        config.height,
        currentPos.Z
    )
    
    root.CFrame = CFrame.new(newPos, newPos + Vector3.new(1, 0, 0))
    teleportCount = teleportCount + 1
    
    if config.useInstantReturn then
        task.wait(config.returnDelay)
        returnCar()
    else
        task.wait(0.2)
        startFlying()
        
        returnTimer = task.spawn(function()
            task.wait(config.returnDelay)
            if config.autoFarmRunning then
                returnCar()
                stopFlying()
            end
        end)
    end
    
    return true
end

local function waitForCharacterLoad()
    local maxWait = 0
    repeat
        task.wait(0.1)
        maxWait = maxWait + 0.1
    until (LocalPlayer.Character and 
           LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
           LocalPlayer.Character:FindFirstChild("Humanoid") and
           LocalPlayer.Character.Humanoid.Health > 0) or maxWait > 10
    
    if maxWait >= 10 then
        return false
    end
    
    task.wait(config.characterLoadDelay)
    return true
end

local function startAutoFarm()
    config.autoFarmRunning = true
    
    spawn(function()
        while config.autoFarmRunning do
            if not alive() then
                if not waitForCharacterLoad() then
                    task.wait(2)
                    continue
                end
            end
            
            local teleportSuccess = safeTeleport()
            if teleportSuccess then
                local deathWait = 0
                local maxDeathWait = 15
                repeat
                    task.wait(0.5)
                    deathWait = deathWait + 0.5
                until not alive() or not config.autoFarmRunning or deathWait > maxDeathWait
                
                if config.autoFarmRunning then
                    if not waitForCharacterLoad() then
                    end
                    
                    task.wait(config.cycleDelay)
                end
            else
                task.wait(3)
            end
        end
    end)
end

local function stopAutoFarm()
    config.autoFarmRunning = false
    stopFlying()
end

local Window = Fluent:CreateWindow({
    Title = "COMBO_WICK",
    SubTitle = "",
    TabWidth = 160,
    Size = UDim2.fromOffset(400, 250),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tab = Window:AddTab({
    Title = "Principal",
    Icon = ""
})

local AutoFarmToggle = Tab:AddToggle("AutoFarm", {
    Title = "Auto Farm",
    Default = false
})

AutoFarmToggle:OnChanged(function(Value)
    if Value then
        startAutoFarm()
    else
        stopAutoFarm()
    end
end)

local ModeToggle = Tab:AddToggle("InstantMode", {
    Title = "Retorno Instantâneo",
    Default = config.useInstantReturn
})

ModeToggle:OnChanged(function(Value)
    config.useInstantReturn = Value
end)

local AntiAfkToggle = Tab:AddToggle("AntiAfk", {
    Title = "Anti AFK",
    Default = config.antiAfkEnabled
})

AntiAfkToggle:OnChanged(function(Value)
    config.antiAfkEnabled = Value
    if Value then
        setupAntiAfk()
    else
        stopAntiAfk()
    end
end)

local DelaySlider = Tab:AddSlider("ReturnDelay", {
    Title = "Tempo necessário para a res...",
    Description = "",
    Default = config.returnDelay,
    Min = 1,
    Max = 5,
    Rounding = 1,
    Callback = function(Value)
        config.returnDelay = Value
    end
})

local LaunchSlider = Tab:AddSlider("LaunchWait", {
    Title = "Aguardar lançamento",
    Description = "",
    Default = config.launchWaitTime,
    Min = 0.5,
    Max = 3,
    Rounding = 1,
    Callback = function(Value)
        config.launchWaitTime = Value
    end
})

task.wait(0.5)
Window:SelectTab(Tab)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToggleGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 70, 0, 35)
toggleButton.Position = UDim2.new(1, -80, 0.5, -17)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggleButton.BorderSizePixel = 1
toggleButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
toggleButton.Text = "FECHAR"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = screenGui

local rainbowConnection
local function startRainbowEffect()
    rainbowConnection = RunService.Heartbeat:Connect(function()
        local time = tick()
        local r = math.sin(time * 2) * 0.5 + 0.5
        local g = math.sin(time * 2 + 2) * 0.5 + 0.5
        local b = math.sin(time * 2 + 4) * 0.5 + 0.5
        
        local baseColor = Color3.fromRGB(50, 50, 50)
        local rainbowColor = Color3.new(r, g, b)
        
        toggleButton.BackgroundColor3 = baseColor:lerp(rainbowColor, 0.3)
        toggleButton.BorderColor3 = rainbowColor:lerp(Color3.fromRGB(200, 200, 200), 0.5)
    end)
end

startRainbowEffect()

local windowVisible = true

toggleButton.MouseButton1Click:Connect(function()
    windowVisible = not windowVisible
    if windowVisible then
        Window.Root.Visible = true
        toggleButton.Text = "FECHAR"
    else
        Window.Root.Visible = false
        toggleButton.Text = "ABERTO"
    end
end)

setupAntiAfk()
cacheRemotes()
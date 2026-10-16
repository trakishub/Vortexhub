-- =============================================================================
-- FX CLIENT HUB | ADMIN PANEL (ATUALIZADO)
-- Tag com fundo branco semi-transparente + borda branca + brilho RGB
-- Modo Silencioso
-- Aba Troll com item de pegar jogadores (corrigido)
-- =============================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

--==================== LISTAS DE AUTORIZADOS (PAINEL ADM) ====================
local Donos = { ["Hey_zPUDIM"] = true, ["luke_jokerHk3"] = true }
local Testers = { ["Marcosjjunioioe123"] = true }
local Divulgadores = { ["hoangvanhieuCc_39"] = true, ["Tokitooff29"] = true, ["biadofrostzin_7"] = true }
local Autorizados = {}

local function EstaAutorizado(nome)
    if Donos[nome] or Testers[nome] or Divulgadores[nome] or Autorizados[nome] then
        return true
    end
    return false
end

local playerOriginalSpeed = {}
local jaulasCriadas = {}
local SilentMode = false

local function MostrarBannerAviso(autorNome, textoAviso)
    local screenGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("FxAvisoGui")
    if screenGui then screenGui:Destroy() end

    local newGui = Instance.new("ScreenGui")
    newGui.Name = "FxAvisoGui"
    newGui.IgnoreGuiInset = true
    newGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(0, 420, 0, 75)
    banner.Position = UDim2.new(0.5, -210, 0, -90)
    banner.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    banner.BorderSizePixel = 0
    banner.Parent = newGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = banner

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(170, 45, 255)
    stroke.Thickness = 2
    stroke.Parent = banner

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, 55, 0, 55)
    avatarImg.Position = UDim2.new(0, 10, 0.5, -27.5)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Parent = banner

    local avCorner = Instance.new("UICorner")
    avCorner.CornerRadius = UDim.new(0, 99)
    avCorner.Parent = avatarImg

    pcall(function()
        local targetPlr = Players:FindFirstChild(autorNome)
        if targetPlr then
            local thumb = Players:GetUserThumbnailAsync(targetPlr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            avatarImg.Image = thumb
        end
    end)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -75, 0, 22)
    titleLabel.Position = UDim2.new(0, 75, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🚨 AVISO DE: " .. string.upper(autorNome)
    titleLabel.TextColor3 = Color3.fromRGB(215, 110, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = banner

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -75, 0, 35)
    msgLabel.Position = UDim2.new(0, 75, 0, 30)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = textoAviso
    msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgLabel.Font = Enum.Font.GothamMedium
    msgLabel.TextSize = 12
    msgLabel.TextWrapped = true
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Parent = banner

    TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0, 15)
    }):Play()

    task.delay(6, function()
        if banner and banner.Parent then
            local sai = TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -210, 0, -90)
            })
            sai:Play()
            sai.Completed:Wait()
            newGui:Destroy()
        end
    end)
end

-- ==================== TAG ====================
local function CriarTag(player, tagTexto, corRGB)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    local head = player.Character.Head

    local tagAntiga = head:FindFirstChild("CustomTag")
    if tagAntiga then tagAntiga:Destroy() end

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "CustomTag"
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 145, 0, 34)
    billboardGui.AlwaysOnTop = true
    billboardGui.StudsOffset = Vector3.new(0, 2.6, 0)
    billboardGui.MaxDistance = 130
    billboardGui.Parent = head

    local background = Instance.new("ImageLabel")
    background.Size = UDim2.new(1, 0, 1, 0)
    background.Image = ""
    background.ImageColor3 = Color3.fromRGB(255, 255, 255)
    background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    background.BackgroundTransparency = 0.45
    background.BorderSizePixel = 0
    background.ScaleType = Enum.ScaleType.Crop
    background.Parent = billboardGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0.5, 0)
    uiCorner.Parent = background

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2.2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = background

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = string.upper(tagTexto)
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0.25
    textLabel.TextStrokeColor3 = Color3.fromRGB(30, 20, 40)
    textLabel.Parent = background

    local textGradient = Instance.new("UIGradient")
    textGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 80, 80)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 50)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 120)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 180, 255)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 80, 255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 80, 80))
    })
    textGradient.Parent = textLabel

    task.spawn(function()
        while billboardGui and billboardGui.Parent do
            for i = 0, 1, 0.015 do
                if not textGradient or not textGradient.Parent then break end
                textGradient.Offset = Vector2.new(i, 0)
                task.wait(0.02)
            end
        end
    end)
end

local function RemoverTag(player)
    if player.Character and player.Character:FindFirstChild("Head") then
        local tag = player.Character.Head:FindFirstChild("CustomTag")
        if tag then tag:Destroy() end
    end
end

local function PrenderEmJaula()
    if jaulasCriadas[LocalPlayer.Name] then return end

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pos = root.Position
    local model = Instance.new("Model")
    model.Name = "FxJail_" .. LocalPlayer.Name

    local function CriarGrade(cf, size)
        local p = Instance.new("Part")
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.Material = Enum.Material.Metal
        p.BrickColor = BrickColor.new("Really black")
        p.Transparency = 0.3
        p.Parent = model
    end

    CriarGrade(CFrame.new(pos + Vector3.new(0, -3.5, 0)), Vector3.new(8, 1, 8))
    CriarGrade(CFrame.new(pos + Vector3.new(0, 4.5, 0)), Vector3.new(8, 1, 8))
    CriarGrade(CFrame.new(pos + Vector3.new(4, 0.5, 0)), Vector3.new(1, 7, 8))
    CriarGrade(CFrame.new(pos + Vector3.new(-4, 0.5, 0)), Vector3.new(1, 7, 8))
    CriarGrade(CFrame.new(pos + Vector3.new(0, 0.5, 4)), Vector3.new(8, 7, 1))
    CriarGrade(CFrame.new(pos + Vector3.new(0, 0.5, -4)), Vector3.new(8, 7, 1))

    model.Parent = Workspace
    jaulasCriadas[LocalPlayer.Name] = model
end

local function SoltarDaJaula()
    if jaulasCriadas[LocalPlayer.Name] then
        jaulasCriadas[LocalPlayer.Name]:Destroy()
        jaulasCriadas[LocalPlayer.Name] = nil
    end
end

-- ==================== MONSTRO ====================
local function InvocarMonstro()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    local old = Workspace:FindFirstChild("FxMonster_" .. LocalPlayer.Name)
    if old then old:Destroy() end

    local monster = Instance.new("Model")
    monster.Name = "FxMonster_" .. LocalPlayer.Name

    local body = Instance.new("Part")
    body.Name = "HumanoidRootPart"
    body.Size = Vector3.new(3.2, 4.5, 2.2)
    body.Color = Color3.fromRGB(20, 0, 0)
    body.Material = Enum.Material.Neon
    body.Anchored = false
    body.CanCollide = false
    body.Parent = monster

    local head = Instance.new("Part")
    head.Size = Vector3.new(2.6, 2.6, 2.6)
    head.Color = Color3.fromRGB(40, 0, 0)
    head.Material = Enum.Material.Neon
    head.CanCollide = false
    head.Parent = monster

    local weld = Instance.new("Weld")
    weld.Part0 = body
    weld.Part1 = head
    weld.C0 = CFrame.new(0, 3.4, 0)
    weld.Parent = body

    local function criarOlho(x)
        local eye = Instance.new("Part")
        eye.Size = Vector3.new(0.55, 0.55, 0.3)
        eye.Color = Color3.fromRGB(255, 20, 20)
        eye.Material = Enum.Material.Neon
        eye.CanCollide = false
        eye.Parent = monster
        local w = Instance.new("Weld")
        w.Part0 = head
        w.Part1 = eye
        w.C0 = CFrame.new(x, 0.35, -1.35)
        w.Parent = head
    end
    criarOlho(-0.55)
    criarOlho(0.55)

    monster.PrimaryPart = body
    monster.Parent = Workspace

    body.CFrame = root.CFrame * CFrame.new(0, 1, 16)

    local att = Instance.new("Attachment", body)
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxassetid://243660364"
    particles.Color = ColorSequence.new(Color3.fromRGB(160, 0, 0))
    particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
    particles.Lifetime = NumberRange.new(1.3, 2.2)
    particles.Rate = 70
    particles.Speed = NumberRange.new(4, 9)
    particles.Parent = att

    local music = Instance.new("Sound")
    music.SoundId = "rbxassetid://1837879081"
    music.Volume = 4.5
    music.Looped = true
    music.Parent = body
    music:Play()

    local roar = Instance.new("Sound")
    roar.SoundId = "rbxassetid://138085780"
    roar.Volume = 3.5
    roar.Parent = body
    roar:Play()

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.P = 3000
    bv.Velocity = Vector3.zero
    bv.Parent = body

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then
            conn:Disconnect()
            if monster then monster:Destroy() end
            return
        end
        if not body or not body.Parent then
            conn:Disconnect()
            return
        end

        local direction = (root.Position - body.Position)
        local distance = direction.Magnitude

        if distance > 1 then
            local moveDir = direction.Unit
            bv.Velocity = moveDir * 19
            body.CFrame = CFrame.lookAt(body.Position, Vector3.new(root.Position.X, body.Position.Y, root.Position.Z))
        else
            bv.Velocity = Vector3.zero
        end

        if distance <= 8 then
            humanoid:TakeDamage(22)

            local hit = Instance.new("Sound")
            hit.SoundId = "rbxassetid://9114224572"
            hit.Volume = 2.2
            hit.Parent = root
            hit:Play()
            Debris:AddItem(hit, 2)
        end
    end)

    task.delay(45, function()
        if conn then conn:Disconnect() end
        if monster then monster:Destroy() end
    end)
end

-- ==================== ITEM DE PEGAR JOGADORES (CORRIGIDO) ====================
local function DarItemPegar()
    local character = LocalPlayer.Character
    if not character then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    local antigo = backpack:FindFirstChild("FxGrab") or character:FindFirstChild("FxGrab")
    if antigo then antigo:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "FxGrab"
    tool.RequiresHandle = true
    tool.CanBeDropped = false

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.8, 0.8, 2.5)
    handle.Color = Color3.fromRGB(170, 50, 255)
    handle.Material = Enum.Material.Neon
    handle.Parent = tool

    tool.Parent = backpack

    local holding = nil
    local conn = nil

    tool.Activated:Connect(function()
        -- Se já estiver segurando, solta
        if holding then
            if conn then conn:Disconnect() end
            holding = nil
            conn = nil
            return
        end

        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        if not target then return end

        local model = target:FindFirstAncestorOfClass("Model")
        if not model then return end

        local player = Players:GetPlayerFromCharacter(model)
        if not player or player == LocalPlayer then return end

        local root = model:FindFirstChild("HumanoidRootPart")
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        if not root or not myRoot then return end

        holding = root

        -- Segura a pessoa na frente (método que funciona)
        conn = RunService.Heartbeat:Connect(function()
            if not holding or not holding.Parent or not myRoot or not myRoot.Parent then
                if conn then conn:Disconnect() end
                holding = nil
                return
            end
            holding.CFrame = myRoot.CFrame * CFrame.new(0, 0, -5)
        end)
    end)

    tool.Unequipped:Connect(function()
        if conn then conn:Disconnect() end
        holding = nil
        conn = nil
    end)

    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:EquipTool(tool)
    end
end

local function EnviarComando(comando, alvo, argumentoExtra)
    local canal = TextChatService.TextChannels:FindFirstChild("RBXGeneral") or TextChatService.TextChannels:GetChildren()[1]
    if canal then
        local textoCompleto = ";" .. comando .. " " .. (alvo or "")
        if argumentoExtra and argumentoExtra ~= "" then
            textoCompleto = textoCompleto .. " " .. argumentoExtra
        end
        canal:SendAsync(textoCompleto)
    end
end

local function ProcessarMensagem(msgText, authorName)
    if not msgText or not authorName then return end

    local targetLower = LocalPlayer.Name:lower()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local autorPlayer = Players:FindFirstChild(authorName)
    local msgLower = msgText:lower()

    if msgLower:match("^;aviso%s+") then
        local textoAviso = msgText:sub(8)
        if textoAviso and textoAviso ~= "" then
            MostrarBannerAviso(authorName, textoAviso)
        end
        return
    end

    if msgLower:match("^;bring%s+" .. targetLower) then
        if autorPlayer and autorPlayer.Character and autorPlayer.Character:FindFirstChild("HumanoidRootPart") and root then
            root.CFrame = autorPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 1, 0)
        end
    end

    if msgLower:match("^;tp%s+" .. targetLower) then
        if autorPlayer and autorPlayer.Character and autorPlayer.Character:FindFirstChild("HumanoidRootPart") and root then
            root.CFrame = autorPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(2, 1, 0)
        end
    end

    if msgLower:match("^;jail%s+" .. targetLower) then
        PrenderEmJaula()
    end

    if msgLower:match("^;unjail%s+" .. targetLower) then
        SoltarDaJaula()
    end

    if msgLower:match("^;kick%s+" .. targetLower) then
        local partes = {}
        for palavra in msgText:gmatch("%S+") do table.insert(partes, palavra) end
        local motivo = table.concat(partes, " ", 3)
        LocalPlayer:Kick((motivo ~= "") and motivo or "You got kicked by Fx client Hub")
    end

    if msgLower:match("^;ban%s+" .. targetLower) then
        local partes = {}
        for palavra in msgText:gmatch("%S+") do table.insert(partes, palavra) end
        local motivo = table.concat(partes, " ", 3)
        LocalPlayer:Kick((motivo ~= "") and motivo or "You got banned by Fx Hub")
    end

    if msgLower:match("^;kill%s+" .. targetLower) then
        if character then character:BreakJoints() end
    end

    if msgLower:match("^;killplus%s+" .. targetLower) then
        if character then
            character:BreakJoints()
            if root then
                for i = 1, 10 do
                    local part = Instance.new("Part")
                    part.Size = Vector3.new(10, 10, 10)
                    part.Anchored = false
                    part.CanCollide = false
                    part.Material = Enum.Material.Neon
                    part.BrickColor = BrickColor.Random()
                    part.CFrame = root.CFrame
                    part.Parent = Workspace
                    local bv = Instance.new("BodyVelocity")
                    bv.Velocity = Vector3.new(math.random(-50, 50), math.random(20, 80), math.random(-50, 50))
                    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    bv.Parent = part
                    Debris:AddItem(part, 3)
                end
            end
        end
    end

    if msgLower:match("^;backrooms%s+" .. targetLower) then
        local player = LocalPlayer
        local mapID = 10581711055
        local distantPosition = Vector3.new(4000, 7, 0)
        local teleportPosition = Vector3.new(4029, 9, 24)

        pcall(function()
            local mapa = game:GetObjects("rbxassetid://" .. mapID)[1]
            mapa.Parent = Workspace
            if not mapa.PrimaryPart then
                local part = mapa:FindFirstChildWhichIsA("BasePart")
                if part then mapa.PrimaryPart = part end
            end
            mapa:SetPrimaryPartCFrame(CFrame.new(distantPosition))
            if player.Character then
                player.Character:MoveTo(teleportPosition)
            end
        end)
    end

    if msgLower:match("^;fling%s+" .. targetLower) then
        if root then
            local tween = TweenService:Create(root, TweenInfo.new(1, Enum.EasingStyle.Linear), {CFrame = CFrame.new(0, 100000, 0)})
            tween:Play()
        end
    end

    if msgLower:match("^;freeze%s+" .. targetLower) then
        if humanoid then
            playerOriginalSpeed[targetLower] = humanoid.WalkSpeed
            humanoid.WalkSpeed = 0
        end
    end

    if msgLower:match("^;unfreeze%s+" .. targetLower) then
        if humanoid then
            humanoid.WalkSpeed = playerOriginalSpeed[targetLower] or 16
        end
    end

    if msgLower:match("^;monster%s+" .. targetLower) then
        InvocarMonstro()
    end

    if msgLower:match("^;explode%s+" .. targetLower) then
        if root then
            local explosion = Instance.new("Explosion")
            explosion.Position = root.Position
            explosion.BlastRadius = 20
            explosion.BlastPressure = 500000
            explosion.Parent = Workspace
            if humanoid then humanoid.Health = 0 end
        end
    end

    if msgLower:match("^;burn%s+" .. targetLower) then
        if character and root then
            local fire = Instance.new("Fire")
            fire.Size = 12
            fire.Heat = 15
            fire.Parent = root
            task.delay(8, function()
                if fire then fire:Destroy() end
            end)
            if humanoid then
                task.spawn(function()
                    for i = 1, 10 do
                        task.wait(0.6)
                        if humanoid and humanoid.Parent then
                            humanoid:TakeDamage(8)
                        end
                    end
                end)
            end
        end
    end

    if msgLower:match("^;rocket%s+" .. targetLower) then
        if root then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(0, 250, 0)
            bv.MaxForce = Vector3.new(0, 1e6, 0)
            bv.Parent = root
            Debris:AddItem(bv, 2)
        end
    end

    if msgLower:match("^;spin%s+" .. targetLower) then
        if root then
            local spin = Instance.new("BodyAngularVelocity")
            spin.AngularVelocity = Vector3.new(0, 40, 0)
            spin.MaxTorque = Vector3.new(0, 1e6, 0)
            spin.Parent = root
            Debris:AddItem(spin, 6)
        end
    end

    if msgLower:match("^;sink%s+" .. targetLower) then
        if root then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(0, -80, 0)
            bv.MaxForce = Vector3.new(0, 1e6, 0)
            bv.Parent = root
            Debris:AddItem(bv, 4)
        end
    end
end

-- Escuta de chat
for _, ch in pairs(TextChatService.TextChannels:GetChildren()) do
    if ch:IsA("TextChannel") then
        ch.MessageReceived:Connect(function(msg)
            if msg.Text and msg.TextSource then
                ProcessarMensagem(msg.Text, msg.TextSource.Name)
            end
        end)
    end
end

TextChatService.TextChannels.ChildAdded:Connect(function(ch)
    if ch:IsA("TextChannel") then
        ch.MessageReceived:Connect(function(msg)
            if msg.Text and msg.TextSource then
                ProcessarMensagem(msg.Text, msg.TextSource.Name)
            end
        end)
    end
end)

-- =============================================================================
-- PAINEL ADM
-- =============================================================================
if not EstaAutorizado(LocalPlayer.Name) then
    return
end

local ok, WindUILib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok then return end

local AdminWindow = WindUILib:CreateWindow({
    Title = "Fx client Hub | Admins/Developers",
    Icon = "door-open",
    Author = "by: Vxz",
    Folder = "Fx - Admins",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = true,
})

local TabComandos = AdminWindow:Tab({ Title = "Admin", Icon = "terminal" })
local Section = TabComandos:Section({ Title = "Commands", Icon = "user-cog", Opened = true })

local function getPlayersList()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(t, p.Name)
    end
    return t
end

local TargetName
local Dropdown = Section:Dropdown({
    Title = "Selecionar Jogador",
    Values = getPlayersList(),
    Value = "",
    Callback = function(opt)
        TargetName = opt
    end
})

Players.PlayerAdded:Connect(function()
    Dropdown:SetValues(getPlayersList())
end)
Players.PlayerRemoving:Connect(function()
    Dropdown:SetValues(getPlayersList())
end)

local razaoPunicao = ""
Section:Input({
    Title = "Mensagem de Kick / Ban",
    Placeholder = "Digite o motivo aqui...",
    Callback = function(text)
        razaoPunicao = text
    end
})

Section:Toggle({
    Title = "Modo Silencioso",
    Desc = "Executa os comandos sem aparecer no chat",
    Default = false,
    Callback = function(value)
        SilentMode = value
    end
})

local comandos = {
    "bring", "tp", "kick", "ban", "kill", "killplus", "fling",
    "backrooms", "freeze", "unfreeze", "jail", "unjail",
    "monster", "explode", "burn", "rocket", "spin", "sink", "verifique"
}

for _, cmd in ipairs(comandos) do
    Section:Button({
        Title = cmd:lower(),
        Desc = "Script for ;" .. cmd .. " - Target",
        Callback = function()
            if cmd == "verifique" then
                EnviarComando("Fx_users", "")
                return
            end

            if not TargetName or TargetName == "" then
                warn("Nenhum jogador selecionado!")
                return
            end

            if SilentMode then
                local msg = ";" .. cmd .. " " .. TargetName
                if razaoPunicao and razaoPunicao ~= "" then
                    msg = msg .. " " .. razaoPunicao
                end
                ProcessarMensagem(msg, LocalPlayer.Name)
            else
                EnviarComando(cmd, TargetName, razaoPunicao)
            end
        end
    })
end

-- ABA AVISOS
local TabAvisos = AdminWindow:Tab({ Title = "Avisos", Icon = "megaphone" })
local SecAvisos = TabAvisos:Section({ Title = "Painel de Anúncios Globais", Icon = "bell", Opened = true })

local textoAvisoDigitado = ""
SecAvisos:Input({
    Title = "Texto do Aviso",
    Placeholder = "Escreva o comunicado aqui...",
    Callback = function(text)
        textoAvisoDigitado = text
    end
})

SecAvisos:Button({
    Title = "📢 Enviar Aviso Global",
    Desc = "Mostra sua foto de perfil e o aviso no topo da tela de todos.",
    Callback = function()
        if textoAvisoDigitado and textoAvisoDigitado ~= "" then
            EnviarComando("aviso", textoAvisoDigitado)
        else
            warn("Digite um texto para o aviso!")
        end
    end
})

-- ABA TAGS
local TabTag = AdminWindow:Tab({ Title = "Tags", Icon = "tag" })
local SecTag = TabTag:Section({ Title = "Gerenciar Tags", Icon = "tag", Opened = true })

local tagSelecionada = "👑 Dono Fx"
local corSelecionada = Color3.fromRGB(255, 215, 0)

SecTag:Dropdown({
    Title = "Escolher tipo de Tag",
    Values = { "👑 Dono Fx", "👁️‍🗨️ Tester Fx", "🛡️ Moderador Fx", "🎥 Divulgador Fx", "💻 Dev Fx" },
    Value = "👑 Dono Fx",
    Callback = function(v)
        tagSelecionada = v
        if v == "👑 Dono Fx" then
            corSelecionada = Color3.fromRGB(255, 215, 0)
        elseif v == "👁️‍🗨️ Tester Fx" then
            corSelecionada = Color3.fromRGB(100, 200, 255)
        elseif v == "🛡️ Moderador Fx" then
            corSelecionada = Color3.fromRGB(0, 255, 128)
        elseif v == "🎥 Divulgador Fx" then
            corSelecionada = Color3.fromRGB(255, 100, 180)
        elseif v == "💻 Dev Fx" then
            corSelecionada = Color3.fromRGB(180, 100, 255)
        end
    end
})

SecTag:Button({
    Title = "Adicionar Tag",
    Desc = "Adiciona a tag selecionada acima da sua cabeça",
    Callback = function()
        CriarTag(LocalPlayer, tagSelecionada, corSelecionada)
    end
})

SecTag:Button({
    Title = "Remover Tag",
    Desc = "Remove sua tag atual",
    Callback = function()
        RemoverTag(LocalPlayer)
    end
})

-- ==================== ABA TROLL ====================
local TabTroll = AdminWindow:Tab({ Title = "Troll", Icon = "smile" })
local SecTroll = TabTroll:Section({ Title = "Ferramentas de Troll", Icon = "hand", Opened = true })

SecTroll:Button({
    Title = "🎯 Pegar Jogadores",
    Desc = "Clica na pessoa pra segurar, clica de novo pra soltar",
    Callback = function()
        DarItemPegar()
    end
})

local sound = Instance.new("Sound")
sound.SoundId = "rbxassetid://8486683243"
sound.Volume = 0.5
sound.PlayOnRemove = true
sound.Parent = Workspace
sound:Destroy()

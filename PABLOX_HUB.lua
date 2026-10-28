--==================================================
-- PABLOX HUB • PC + MOBILE
-- STATUS + ANTI-FAKEOUT + FAKEOUT + ANTI-FLING + AUTO-FUGA
-- RECUPERAR VOID + TELEPORTE NPC (+ ATAQUE + ESQUIVA + RESPAWN + REJOIN)
-- TP JOGADOR (TECLA) + AUTOFARM (MOBILE / PC) + ANTI-STUN
-- DASH ASSIST + AIM ASSIST (PAUSA NO SHIFT LOCK) + AUTO-RESET
-- AUTO-BLOCK (DUMMY + JOGADOR MARCADO)
-- INVISÍVEL (MANUAL + AUTO) + OTIMIZAR (REDE + QUADROS ESTÁVEIS)
--==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
if not Player then return end

local PlayerGui = Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

-- IMAGENS
local BG_IMAGE = "rbxassetid://129346114110422"      -- fundo da Hub
local BUTTON_IMAGE = "rbxassetid://84297539835438"   -- botão redondo

-- TRANSPARÊNCIA (0 = sólido, 1 = invisível) — ajuste aqui se quiser
local PANEL_ALPHA = 0.55  -- painel principal
local CARD_ALPHA = 0.4    -- cartões, menu lateral e pílulas
local IMAGE_ALPHA = 0.08  -- imagem de fundo (menor = foto mais clara e visível)

--==================================================
-- LIMPA SOMENTE A HUB ANTIGA
--==================================================

local Old = PlayerGui:FindFirstChild("PABLOX_HUB")
if Old then
    Old:Destroy()
end

--==================================================
-- CONEXÕES / LIMPEZA
--==================================================

local Connections = {}
local Alive = true

local function Track(connection)
    table.insert(Connections, connection)
    return connection
end

local State = {
    Anti = false,
    Teleport = false,
    Dash = false,
    Aim = false,
    Fakeout = false,
    AntiFling = false,
    PlayerTP = false,
    Dodge = false,
    VoidRec = false,
    AutoRec = false,
    AutoReset = false,
    FarmMobile = false,
    FarmPC = false,
    Farm = false,
    AntiStun = false,
    Escape = false,      -- Auto-Fuga ligada
    AutoBlock = false,   -- Auto-Block ligado
    Blocking = false,    -- segurando o Block agora
    Escaping = false,    -- fugindo / voltando atacando agora
    FakeRunning = false,
    RecRunning = false,
    AntiRunning = false,
    GraceUntil = 0,
    DodgePause = 0,
}

-- Ganchos entre os módulos
local Hooks = {
    FlingBlocked = 0,
    StunFixed = 0,
    EscapeCount = 0,
    AimPaused = false,
}

-- Controle compartilhado da escolha de tecla (PC)
local KeyBusy = {Active = false, LastEnd = 0}

local function Cleanup()
    pcall(function()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root and (State.Teleport or State.AntiRunning or State.Escaping) then
            Root.Anchored = false
        end
    end)

    pcall(function()
        if Hooks.FlingRestore then
            Hooks.FlingRestore()
        end
    end)

    pcall(function()
        if Hooks.VoidRestore then
            Hooks.VoidRestore()
        end
    end)

    Alive = false
    State.Anti = false
    State.Teleport = false
    State.Dash = false
    State.Aim = false
    State.Fakeout = false
    State.AntiFling = false
    State.PlayerTP = false
    State.Dodge = false
    State.VoidRec = false
    State.AutoRec = false
    State.AutoReset = false
    State.FarmMobile = false
    State.FarmPC = false
    State.Farm = false
    State.AntiStun = false
    State.Escape = false
    State.Escaping = false
    State.FakeRunning = false
    State.RecRunning = false
    State.AntiRunning = false

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)
end

--==================================================
-- CONTROLE ONLINE (WORKER CLOUDFLARE)
--==================================================
local CONTROL_URL = "https://pablox-hub-control.pruan3733.workers.dev"
local ControlStatus = "connecting"
local Gui
local function ControlRequest(path, method, payload)
    local req = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (syn and type(syn.request) == "function" and syn.request)
        or (http and type(http.request) == "function" and http.request)
    if not req then return nil end
    local args = {
        Url = CONTROL_URL .. path,
        Method = method or "GET",
        Headers = { ["Content-Type"] = "application/json" }
    }
    if payload then args.Body = HttpService:JSONEncode(payload) end
    local ok, response = pcall(req, args)
    if not ok or type(response) ~= "table" then return nil end
    local code = tonumber(response.StatusCode or response.Status)
    if not code or code < 200 or code >= 300 then return nil end
    local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
    if decoded and type(data) == "table" then return data end
    return nil
end

local function StopFromControl()
    if not Alive then return end
    Cleanup()
    if Gui and Gui.Parent then Gui:Destroy() end
end

--==================================================
-- CRIA A GUI
--==================================================

Gui = Instance.new("ScreenGui")
Gui.Name = "PABLOX_HUB"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 100
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Enabled = true
Gui.Parent = PlayerGui

Track(Gui.Destroying:Connect(Cleanup))

--==================================================
-- BOTÃO FLUTUANTE (REDONDO / ARRASTÁVEL)
--==================================================

local OpenButton = Instance.new("ImageButton")
OpenButton.Name = "OpenButton"
OpenButton.Parent = Gui
OpenButton.AnchorPoint = Vector2.new(0.5, 0.5)
OpenButton.Size = UDim2.fromOffset(56, 56)
OpenButton.Position = UDim2.fromOffset(40, 300)
OpenButton.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
OpenButton.Image = BUTTON_IMAGE
OpenButton.ScaleType = Enum.ScaleType.Crop
OpenButton.AutoButtonColor = false
OpenButton.Visible = true
OpenButton.Active = true
OpenButton.ZIndex = 20

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenButton

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(75, 75, 85)
OpenStroke.Thickness = 2
OpenStroke.Parent = OpenButton

--==================================================
-- PAINEL
--==================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = Gui
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromOffset(420, 400)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Main.BackgroundTransparency = PANEL_ALPHA
Main.BorderSizePixel = 0
Main.Visible = false
Main.ZIndex = 10
Main.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(48, 48, 58)
MainStroke.Thickness = 1
MainStroke.Parent = Main

local Background = Instance.new("ImageLabel")
Background.Name = "Background"
Background.Parent = Main
Background.Size = UDim2.fromScale(1, 1)
Background.BackgroundTransparency = 1
Background.Image = BG_IMAGE
Background.ImageTransparency = IMAGE_ALPHA
Background.ScaleType = Enum.ScaleType.Crop
Background.Active = false
Background.Interactable = false
Background.ZIndex = 10

local BackgroundCorner = Instance.new("UICorner")
BackgroundCorner.CornerRadius = UDim.new(0, 18)
BackgroundCorner.Parent = Background

--==================================================
-- HEADER
--==================================================

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = Main
Header.Size = UDim2.new(1, 0, 0, 58)
Header.BackgroundTransparency = 1
Header.Active = true
Header.ZIndex = 12

local Title = Instance.new("TextLabel")
Title.Parent = Header
Title.Position = UDim2.new(0, 16, 0, 8)
Title.Size = UDim2.new(1, -65, 0, 24)
Title.BackgroundTransparency = 1
Title.Text = "PABLOX HUB"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextStrokeTransparency = 0.6
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 13

local OnlineBadge = Instance.new("TextLabel")
OnlineBadge.Name = "OnlineStatus"
OnlineBadge.Parent = Header
OnlineBadge.Position = UDim2.fromOffset(155, 8)
OnlineBadge.Size = UDim2.fromOffset(115, 24)
OnlineBadge.BackgroundTransparency = 1
OnlineBadge.Font = Enum.Font.GothamBold
OnlineBadge.TextSize = 11
OnlineBadge.TextXAlignment = Enum.TextXAlignment.Left
OnlineBadge.Text = "● CONECTANDO"
OnlineBadge.TextColor3 = Color3.fromRGB(180, 180, 180)
OnlineBadge.ZIndex = 13

local function SetOnlineBadge(status)
    ControlStatus = status
    if not OnlineBadge.Parent then return end
    if status == "online" then
        OnlineBadge.Text = "● ONLINE"
        OnlineBadge.TextColor3 = Color3.fromRGB(70, 220, 115)
    elseif status == "maintenance" then
        OnlineBadge.Text = "● MANUTENÇÃO"
        OnlineBadge.TextColor3 = Color3.fromRGB(255, 185, 70)
    elseif status == "disabled" then
        OnlineBadge.Text = "● DESATIVADO"
        OnlineBadge.TextColor3 = Color3.fromRGB(240, 90, 90)
    else
        OnlineBadge.Text = "● SEM REDE"
        OnlineBadge.TextColor3 = Color3.fromRGB(175, 175, 175)
    end
end

-- Consulta inicial e heartbeat periódico. O indicador só fica ONLINE
-- quando a Cloudflare confirma o status do serviço.
task.spawn(function()
    while Alive do
        local data = ControlRequest("/api/heartbeat", "POST", {
            userId = tostring(Player.UserId),
            username = Player.Name,
            displayName = Player.DisplayName
        })
        if not data or not data.status then
            data = ControlRequest("/api/status", "GET")
        end
        if data and type(data.status) == "string" then
            SetOnlineBadge(data.status)
            if data.status == "maintenance" or data.status == "disabled" then
                StopFromControl()
                break
            end
        else
            SetOnlineBadge("offline")
        end
        task.wait(5)
    end
end)

local Subtitle = Instance.new("TextLabel")
Subtitle.Parent = Header
Subtitle.Position = UDim2.new(0, 16, 0, 32)
Subtitle.Size = UDim2.new(1, -65, 0, 16)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Status • Anti • Fakeout • Fuga • Void • NPC • TP • Farm • Dash • Aim • Block"
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 10
Subtitle.TextColor3 = Color3.fromRGB(190, 190, 200)
Subtitle.TextStrokeTransparency = 0.6
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.TextTruncate = Enum.TextTruncate.AtEnd
Subtitle.ZIndex = 13

local Close = Instance.new("TextButton")
Close.Parent = Header
Close.AnchorPoint = Vector2.new(1, 0.5)
Close.Position = UDim2.new(1, -10, 0.5, 0)
Close.Size = UDim2.fromOffset(38, 38)
Close.BackgroundColor3 = Color3.fromRGB(30, 30, 37)
Close.BackgroundTransparency = 0.1
Close.BorderSizePixel = 0
Close.Text = "×"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 24
Close.TextColor3 = Color3.fromRGB(230, 230, 235)
Close.ZIndex = 14

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = Close

--==================================================
-- CORPO
--==================================================

local Content = Instance.new("Frame")
Content.Parent = Main
Content.Position = UDim2.new(0, 10, 0, 62)
Content.Size = UDim2.new(1, -20, 1, -72)
Content.BackgroundTransparency = 1
Content.ZIndex = 12
Content.ClipsDescendants = true

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Parent = Content
Sidebar.Size = UDim2.new(0, 90, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(17, 17, 22)
Sidebar.BackgroundTransparency = CARD_ALPHA
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 0
Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
Sidebar.CanvasSize = UDim2.new()
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Active = true
Sidebar.ZIndex = 13

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 9)
SidebarCorner.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.Parent = Sidebar
SidebarPadding.PaddingTop = UDim.new(0, 8)
SidebarPadding.PaddingBottom = UDim.new(0, 8)
SidebarPadding.PaddingLeft = UDim.new(0, 6)
SidebarPadding.PaddingRight = UDim.new(0, 6)

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Parent = Sidebar
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PagesHolder = Instance.new("Frame")
PagesHolder.Parent = Content
PagesHolder.Position = UDim2.new(0, 98, 0, 0)
PagesHolder.Size = UDim2.new(1, -98, 1, 0)
PagesHolder.BackgroundTransparency = 1
PagesHolder.ZIndex = 13
PagesHolder.ClipsDescendants = true

local Pages = {}
local Tabs = {}

local function CreatePage(Name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = Name
    Page.Parent = PagesHolder
    Page.Size = UDim2.fromScale(1, 1)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 4
    Page.ScrollingDirection = Enum.ScrollingDirection.Y
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Visible = false
    Page.Active = true
    Page.ZIndex = 14
    Page.ClipsDescendants = true

    local Padding = Instance.new("UIPadding")
    Padding.Parent = Page
    Padding.PaddingTop = UDim.new(0, 4)
    Padding.PaddingLeft = UDim.new(0, 4)
    Padding.PaddingRight = UDim.new(0, 8)
    Padding.PaddingBottom = UDim.new(0, 12)

    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Page
    Layout.Padding = UDim.new(0, 10)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder

    Pages[Name] = Page
    return Page
end

local function CreateTab(Name, Text, Order)
    local Tab = Instance.new("TextButton")
    Tab.Name = Name
    Tab.Parent = Sidebar
    Tab.LayoutOrder = Order
    Tab.Size = UDim2.new(1, 0, 0, 40)
    Tab.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
    Tab.BackgroundTransparency = 0.15
    Tab.BorderSizePixel = 0
    Tab.AutoButtonColor = false
    Tab.Text = Text
    Tab.TextColor3 = Color3.fromRGB(190, 190, 200)
    Tab.Font = Enum.Font.GothamMedium
    Tab.TextSize = 11
    Tab.TextWrapped = true
    Tab.ZIndex = 14

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 7)
    Corner.Parent = Tab

    Tabs[Name] = Tab
    return Tab
end

CreatePage("Status")
CreatePage("AntiFakeout")
CreatePage("Fakeout")
CreatePage("Invisible")
CreatePage("Escape")
CreatePage("VoidRecover")
CreatePage("NPCTeleport")
CreatePage("PlayerTP")
CreatePage("FarmMobile")
CreatePage("FarmPC")
CreatePage("DashAssist")
CreatePage("AimAssist")
CreatePage("AutoBlock")
CreatePage("Optimize")

CreateTab("Status", "STATUS", 1)
CreateTab("AntiFakeout", "ANTI-FAKEOUT", 2)
CreateTab("Fakeout", "FAKEOUT", 3)
CreateTab("Invisible", "INVISÍVEL", 4)
CreateTab("Escape", "AUTO-FUGA", 5)
CreateTab("VoidRecover", "RECUPERAR VOID", 6)
CreateTab("NPCTeleport", "TELEPORTE NPC", 7)
CreateTab("PlayerTP", "TP JOGADOR", 8)
CreateTab("FarmMobile", "AUTOFARM MOBILE", 9)
CreateTab("FarmPC", "AUTOFARM PC", 10)
CreateTab("DashAssist", "DASH ASSIST", 11)
CreateTab("AimAssist", "AIM ASSIST", 12)
CreateTab("AutoBlock", "AUTO-BLOCK", 13)
CreateTab("Optimize", "OTIMIZAR", 14)

-- Status: menos margem dos lados (mais largo)
do
    local StatusPadding = Pages.Status:FindFirstChildOfClass("UIPadding")

    if StatusPadding then
        StatusPadding.PaddingLeft = UDim.new(0, 0)
        StatusPadding.PaddingRight = UDim.new(0, 6)
    end
end

-- Card com altura automática (nada fica cortado)
local function Card(Page, TitleText, Description)
    local Frame = Instance.new("Frame")
    Frame.Parent = Page
    Frame.Size = UDim2.new(1, -4, 0, 0)
    Frame.AutomaticSize = Enum.AutomaticSize.Y
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    Frame.BackgroundTransparency = CARD_ALPHA
    Frame.BorderSizePixel = 0
    Frame.ZIndex = 15

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Frame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(43, 43, 52)
    Stroke.Parent = Frame

    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 10)
    Pad.PaddingBottom = UDim.new(0, 10)
    Pad.PaddingLeft = UDim.new(0, 12)
    Pad.PaddingRight = UDim.new(0, 12)
    Pad.Parent = Frame

    local List = Instance.new("UIListLayout")
    List.Padding = UDim.new(0, 6)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Parent = Frame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Parent = Frame
    TitleLabel.LayoutOrder = 1
    TitleLabel.Size = UDim2.new(1, 0, 0, 18)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = TitleText
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 12
    TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    TitleLabel.TextStrokeTransparency = 0.7
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 16

    local Desc = Instance.new("TextLabel")
    Desc.Parent = Frame
    Desc.LayoutOrder = 2
    Desc.Size = UDim2.new(1, 0, 0, 0)
    Desc.AutomaticSize = Enum.AutomaticSize.Y
    Desc.BackgroundTransparency = 1
    Desc.Text = Description
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 11
    Desc.TextWrapped = true
    Desc.TextColor3 = Color3.fromRGB(175, 175, 185)
    Desc.TextStrokeTransparency = 0.7
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.TextYAlignment = Enum.TextYAlignment.Top
    Desc.ZIndex = 16

    return Frame, TitleLabel, Desc
end

local function Button(Parent, Text, Order)
    local B = Instance.new("TextButton")
    B.Parent = Parent
    B.LayoutOrder = Order or 10
    B.Size = UDim2.new(1, 0, 0, 38)
    B.BackgroundColor3 = Color3.fromRGB(31, 31, 38)
    B.BackgroundTransparency = 0.1
    B.BorderSizePixel = 0
    B.AutoButtonColor = false
    B.Text = Text
    B.Font = Enum.Font.GothamBold
    B.TextSize = 11
    B.TextWrapped = true
    B.TextColor3 = Color3.fromRGB(230, 230, 235)
    B.ZIndex = 17
    B.Active = true

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = B

    return B
end

-- Texto pequeno de legenda dentro de um card
local function Caption(Parent, Text, Order)
    local L = Instance.new("TextLabel")
    L.Parent = Parent
    L.LayoutOrder = Order
    L.Size = UDim2.new(1, 0, 0, 14)
    L.BackgroundTransparency = 1
    L.Text = Text
    L.Font = Enum.Font.GothamBold
    L.TextSize = 10
    L.TextColor3 = Color3.fromRGB(175, 175, 185)
    L.TextStrokeTransparency = 0.7
    L.TextXAlignment = Enum.TextXAlignment.Left
    L.TextTruncate = Enum.TextTruncate.AtEnd
    L.ZIndex = 16
    return L
end

-- Linha horizontal para botões lado a lado
local function MakeRow(Parent, Order)
    local R = Instance.new("Frame")
    R.Parent = Parent
    R.LayoutOrder = Order
    R.Size = UDim2.new(1, 0, 0, 38)
    R.BackgroundTransparency = 1
    R.ZIndex = 16

    local L = Instance.new("UIListLayout")
    L.FillDirection = Enum.FillDirection.Horizontal
    L.Padding = UDim.new(0, 6)
    L.SortOrder = Enum.SortOrder.LayoutOrder
    L.Parent = R

    return R
end

--==================================================
-- FUNÇÕES AUXILIARES DO JOGO
--==================================================

local OFF_COLOR = Color3.fromRGB(31, 31, 38)
local ON_COLOR = Color3.fromRGB(42, 115, 70)
local SELECTED_COLOR = Color3.fromRGB(0, 85, 125)
local ROW_COLOR = Color3.fromRGB(25, 25, 31)
local WARN_COLOR = Color3.fromRGB(120, 45, 45)
local LOCK_COLOR = Color3.fromRGB(60, 52, 30)

local GREEN = Color3.fromRGB(100, 220, 130)
local RED = Color3.fromRGB(235, 90, 90)
local YELLOW = Color3.fromRGB(240, 200, 90)
local MUTED_TEXT = Color3.fromRGB(170, 170, 180)

local function GetHRP()
    local Character = Player.Character
    return Character and Character:FindFirstChild("HumanoidRootPart")
end

-- Raiz de qualquer jogador vivo
local function GetPlayerRoot(Target)
    if not Target or Target.Parent ~= Players then
        return nil
    end

    local Character = Target.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")

    if not Humanoid or Humanoid.Health <= 0 or not Root then
        return nil
    end

    return Root
end

local function GetNPCTorso()
    local Folder = workspace:FindFirstChild("Folder")
    local Enemy = Folder and Folder:FindFirstChild("enemyforyose")
    return Enemy and Enemy:FindFirstChild("Torso")
end

local function GetPlatform()
    local Map = workspace:FindFirstChild("Map")
    local Platform = Map and Map:FindFirstChild("platform")

    if Platform and Platform:IsA("BasePart") then
        return Platform
    end

    return nil
end

-- Altura da superfície da plataforma
local function GetPlatformTopY()
    local Platform = GetPlatform()

    if not Platform then
        return nil
    end

    return Platform.Position.Y + Platform.Size.Y / 2
end

-- Janela em que os teleportes do próprio Hub não contam como ataque
local function Grace(Seconds)
    State.GraceUntil = math.max(State.GraceUntil, os.clock() + Seconds)
end

local function InGrace()
    return os.clock() < State.GraceUntil
end

-- Leva o personagem para a plataforma (ou, sem plataforma, para o ponto de reserva)
local function ReturnToPlatform(Fallback)
    local HRP = GetHRP()

    if not HRP then
        return false
    end

    local Platform = GetPlatform()

    if Platform then
        local Height = Platform.Size.Y / 2 + 4

        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero
        HRP.CFrame = Platform.CFrame * CFrame.new(0, Height, 0)
        Grace(0.8)

        return true
    end

    if Fallback then
        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero
        HRP.CFrame = CFrame.new(Fallback + Vector3.new(0, 3, 0))
        Grace(0.8)

        return true
    end

    return false
end

-- Mensagem curta de erro
local function ShortText(Message)
    local Clean = string.gsub(tostring(Message), "^.-:%d+:%s*", "")
    local Length = utf8.len(Clean)

    if Length and Length > 36 then
        Clean = string.sub(Clean, 1, utf8.offset(Clean, 36) - 1) .. "…"
    end

    return Clean
end

-- Falhas de execução (aparecem na aba STATUS e como aviso na tela)
local Failures = {}
local FailNotified = {}
local RefreshHub
local NpcInfoLabel

local function SetFailure(Name, Message)
    if Failures[Name] == Message then
        return
    end

    Failures[Name] = Message

    local Now = os.clock()

    if Hooks.Notify and (not FailNotified[Name] or Now - FailNotified[Name] > 8) then
        FailNotified[Name] = Now
        Hooks.Notify("✖ " .. string.upper(Name), ShortText(Message), RED)
    end

    if RefreshHub then
        RefreshHub()
    end
end

local function ClearFailure(Name)
    if Failures[Name] == nil then
        return
    end

    Failures[Name] = nil

    if RefreshHub then
        RefreshHub()
    end
end

-- Seção compacta (título + texto à direita), usada no Status
local function Section(Page, TitleText, Order)
    local Frame = Instance.new("Frame")
    Frame.Parent = Page
    Frame.LayoutOrder = Order
    Frame.Size = UDim2.new(1, 0, 0, 0)
    Frame.AutomaticSize = Enum.AutomaticSize.Y
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    Frame.BackgroundTransparency = CARD_ALPHA
    Frame.BorderSizePixel = 0
    Frame.ZIndex = 15

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Frame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(43, 43, 52)
    Stroke.Parent = Frame

    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop = UDim.new(0, 9)
    Pad.PaddingBottom = UDim.new(0, 9)
    Pad.PaddingLeft = UDim.new(0, 10)
    Pad.PaddingRight = UDim.new(0, 10)
    Pad.Parent = Frame

    local List = Instance.new("UIListLayout")
    List.Padding = UDim.new(0, 8)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Parent = Frame

    local Head = Instance.new("Frame")
    Head.Parent = Frame
    Head.LayoutOrder = 1
    Head.Size = UDim2.new(1, 0, 0, 16)
    Head.BackgroundTransparency = 1
    Head.ZIndex = 16

    local T = Instance.new("TextLabel")
    T.Parent = Head
    T.Size = UDim2.new(0.4, 0, 1, 0)
    T.BackgroundTransparency = 1
    T.Text = TitleText
    T.Font = Enum.Font.GothamBold
    T.TextSize = 12
    T.TextColor3 = Color3.fromRGB(240, 240, 245)
    T.TextStrokeTransparency = 0.7
    T.TextXAlignment = Enum.TextXAlignment.Left
    T.ZIndex = 17

    local R = Instance.new("TextLabel")
    R.Parent = Head
    R.AnchorPoint = Vector2.new(1, 0)
    R.Position = UDim2.new(1, 0, 0, 0)
    R.Size = UDim2.new(0.6, 0, 1, 0)
    R.BackgroundTransparency = 1
    R.Text = ""
    R.Font = Enum.Font.GothamBold
    R.TextSize = 11
    R.TextColor3 = MUTED_TEXT
    R.TextXAlignment = Enum.TextXAlignment.Right
    R.ZIndex = 17

    return Frame, R
end

--==================================================
-- VOID SHIELD
-- Impede que você morra no void (FallenPartsDestroyHeight) enquanto
-- uma função precisa te levar para fora do mapa.
--==================================================

local VoidShield = {Owners = {}, Original = nil}

function VoidShield.Add(Name)
    if next(VoidShield.Owners) == nil then
        VoidShield.Original = workspace.FallenPartsDestroyHeight
    end

    VoidShield.Owners[Name] = true

    pcall(function()
        workspace.FallenPartsDestroyHeight = -1000000
    end)
end

function VoidShield.Remove(Name)
    VoidShield.Owners[Name] = nil

    if next(VoidShield.Owners) == nil and VoidShield.Original ~= nil then
        local Saved = VoidShield.Original
        VoidShield.Original = nil

        pcall(function()
            workspace.FallenPartsDestroyHeight = Saved
        end)
    end
end

function VoidShield.Restore()
    table.clear(VoidShield.Owners)

    if VoidShield.Original ~= nil then
        local Saved = VoidShield.Original
        VoidShield.Original = nil

        pcall(function()
            workspace.FallenPartsDestroyHeight = Saved
        end)
    end
end

Hooks.VoidRestore = VoidShield.Restore

--==================================================
-- COMBATE: POSICIONAMENTO ATRÁS DO ALVO
--==================================================

local Combat = {}

-- CFrame atrás do alvo (só gira de lado, sem inclinar), olhando para ele
function Combat.BehindCFrame(TargetRoot, Behind, Lead)
    local Velocity = TargetRoot.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude

    if Speed ~= Speed or Speed > 150 then
        Velocity = Vector3.zero
    end

    local Pos = TargetRoot.Position + Velocity * (Lead or 0)
    local Look = TargetRoot.CFrame.LookVector
    local Flat = Vector3.new(Look.X, 0, Look.Z)

    if Flat.Magnitude < 0.05 then
        local My = GetHRP()

        if My then
            Flat = Vector3.new(Pos.X - My.Position.X, 0, Pos.Z - My.Position.Z)
        end

        if Flat.Magnitude < 0.05 then
            Flat = Vector3.new(0, 0, -1)
        end
    end

    Flat = Flat.Unit

    local At = Vector3.new(Pos.X - Flat.X * Behind, Pos.Y, Pos.Z - Flat.Z * Behind)

    return CFrame.lookAt(At, Vector3.new(Pos.X, At.Y, Pos.Z))
end

-- Leva você para trás do alvo e para a velocidade
function Combat.Place(TargetRoot, Behind)
    local My = GetHRP()

    if not My or not TargetRoot or not TargetRoot.Parent then
        return false
    end

    My.CFrame = Combat.BehindCFrame(TargetRoot, Behind, 0.05)
    My.AssemblyLinearVelocity = Vector3.zero

    return true
end

--==================================================
-- BOTÕES DO JOGO (ATAQUE / BLOCK / DASH)
-- Acha os botões do jogo (por ação, por nome ou calibrados por você)
-- e aperta sem esconder o HUD e sem equipar ferramenta.
--==================================================

local GameInput = {
    Names = {Attack = "ATAQUE", Block = "BLOCK", Dash = "DASH"},
    Calib = {},
    Cache = {},
    Calibrating = nil,
}

local VIM = nil

pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

local KEYWORDS = {
    Attack = {"m1", "attack", "atk", "punch", "ataque", "soco", "fist", "melee", "combat", "golpe"},
    Block = {"block", "guard", "defend", "defesa", "bloque", "parry"},
    Dash = {"dash", "sprint", "evade", "esquiv"},
}

local function Say(TitleText, Text, Color)
    if Hooks.Notify then
        Hooks.Notify(TitleText, Text, Color)
    end
end

local function Matches(Text, Kind)
    Text = string.lower(tostring(Text or ""))

    if Text == "" then
        return false
    end

    for _, Word in ipairs(KEYWORDS[Kind]) do
        if #Word <= 2 then
            if string.find(Text, "%f[%w]" .. Word .. "%f[%W]") then
                return true
            end
        elseif string.find(Text, Word, 1, true) then
            return true
        end
    end

    return false
end

local function IsLive(Btn)
    return Btn ~= nil
        and Btn.Parent ~= nil
        and Btn:IsDescendantOf(PlayerGui)
        and not Btn:IsDescendantOf(Gui)
end

-- Visível de verdade: ele e todos os pais
local function IsShown(Btn)
    local Obj = Btn

    while Obj and Obj ~= PlayerGui do
        if Obj:IsA("GuiObject") and not Obj.Visible then
            return false
        end

        if Obj:IsA("ScreenGui") and not Obj.Enabled then
            return false
        end

        Obj = Obj.Parent
    end

    return Btn.AbsoluteSize.X > 0 and Btn.AbsoluteSize.Y > 0
end

-- Centro do botão em coordenadas de tela (as do VirtualInputManager)
local function ScreenCenter(Btn)
    local Pos = Btn.AbsolutePosition + Btn.AbsoluteSize / 2
    local Holder = Btn:FindFirstAncestorWhichIsA("ScreenGui")

    if Holder and not Holder.IgnoreGuiInset then
        Pos += GuiService:GetGuiInset()
    end

    return Pos
end

local function SinksInput(Obj)
    if Obj:IsA("GuiButton") or Obj:IsA("TextBox") then
        return true
    end

    return Obj.Active == true
end

-- O Hub está por cima do botão? (então o toque virtual cairia nele)
local function IsCovered(Btn)
    local P = ScreenCenter(Btn)
    local Inset = GuiService:GetGuiInset()

    local Ok, Objects = pcall(function()
        return PlayerGui:GetGuiObjectsAtPosition(P.X - Inset.X, P.Y - Inset.Y)
    end)

    if not Ok then
        return false
    end

    for _, Obj in ipairs(Objects) do
        if Obj == Btn or Obj:IsDescendantOf(Btn) then
            return false
        end

        if Obj:IsDescendantOf(Gui) and SinksInput(Obj) then
            return true
        end
    end

    return false
end

-- Ponto da tela onde um clique chega no jogo (sem cair em botão ou painel)
local SafeCache = {Point = nil, At = 0}

local function SafePoint()
    local Now = os.clock()

    if SafeCache.Point and Now - SafeCache.At < 0.6 then
        return SafeCache.Point
    end

    local Cam = workspace.CurrentCamera

    if not Cam then
        return nil
    end

    local View = Cam.ViewportSize
    local Inset = GuiService:GetGuiInset()
    local Chosen = Vector2.new(View.X / 2, View.Y / 2)
    local Found = false

    for _, Mul in ipairs({0, 0.12, 0.22, 0.32}) do
        for Index = 0, 7 do
            local Angle = Index * (math.pi / 4)

            local P = Vector2.new(
                View.X / 2 + math.cos(Angle) * View.X * Mul,
                View.Y / 2 + math.sin(Angle) * View.Y * Mul
            )

            local Ok, Objects = pcall(function()
                return PlayerGui:GetGuiObjectsAtPosition(P.X - Inset.X, P.Y - Inset.Y)
            end)

            local Blocked = false

            if Ok then
                for _, Obj in ipairs(Objects) do
                    if SinksInput(Obj) then
                        Blocked = true
                        break
                    end
                end
            end

            if not Blocked then
                Chosen = P
                Found = true
                break
            end

            if Mul == 0 then
                break
            end
        end

        if Found then
            break
        end
    end

    SafeCache.Point = Chosen
    SafeCache.At = Now

    return Chosen
end

local function VirtualMouse(P, Hold)
    if not VIM or not P then
        return false
    end

    local Ok = pcall(function()
        VIM:SendMouseButtonEvent(P.X, P.Y, 0, true, game, 0)
    end)

    if not Ok then
        return false
    end

    task.wait(Hold)

    pcall(function()
        VIM:SendMouseButtonEvent(P.X, P.Y, 0, false, game, 0)
    end)

    return true
end

local function VirtualTouch(P, Hold)
    if not VIM or not P then
        return false
    end

    local Ok = pcall(function()
        VIM:SendTouchEvent(7701, 0, P.X, P.Y)
    end)

    if not Ok then
        return false
    end

    task.wait(Hold)

    pcall(function()
        VIM:SendTouchEvent(7701, 2, P.X, P.Y)
    end)

    return true
end

local function SignalPress(Btn)
    local Fired = false
    local Events = {"MouseButton1Down", "Activated", "MouseButton1Click", "MouseButton1Up"}

    if typeof(firesignal) == "function" then
        for _, Name in ipairs(Events) do
            local Ok = pcall(firesignal, Btn[Name])
            Fired = Fired or Ok
        end
    end

    if not Fired and typeof(getconnections) == "function" then
        for _, Name in ipairs(Events) do
            local Ok, List = pcall(getconnections, Btn[Name])

            if Ok and typeof(List) == "table" then
                for _, Conn in ipairs(List) do
                    local FireFn = Conn.Fire

                    if typeof(FireFn) == "function" then
                        pcall(FireFn, Conn)
                        Fired = true
                    end
                end
            end
        end
    end

    if Fired then
        return true
    end

    return false, "sinal indisponível neste executor"
end

-- Aperta um botão do jogo
function GameInput.PressButton(Btn, Method, Hold)
    Hold = Hold or 0.03
    Method = Method or "AUTO"

    if not IsLive(Btn) then
        return false, "botão sumiu"
    end

    if not IsShown(Btn) then
        return false, "botão escondido"
    end

    local Covered = IsCovered(Btn)

    if Method == "AUTO" then
        Method = Covered and "SINAL" or "TOQUE"
    end

    if Method == "TOQUE" then
        if Covered then
            return false, "o painel do Hub cobre o botão"
        end

        if VirtualTouch(ScreenCenter(Btn), Hold) then
            return true
        end

        Method = "CLIQUE"
    end

    if Method == "CLIQUE" then
        if Covered then
            return false, "o painel do Hub cobre o botão"
        end

        if VirtualMouse(ScreenCenter(Btn), Hold) then
            return true
        end

        Method = "SINAL"
    end

    if Method == "SINAL" then
        return SignalPress(Btn)
    end

    return false, "método inválido"
end

--------------------------------------------------
-- ACHAR OS BOTÕES
--------------------------------------------------

local function FindViaCAS(Kind)
    local Ok, All = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)

    if not Ok or typeof(All) ~= "table" then
        return nil
    end

    local Fallback, FallbackName

    for Name, Info in pairs(All) do
        local Btn

        pcall(function()
            Btn = ContextActionService:GetButton(Name)
        end)

        if Btn and IsLive(Btn) then
            if Matches(Name, Kind) then
                return Btn, "ação " .. tostring(Name)
            end

            if Kind == "Attack"
                and not Fallback
                and typeof(Info) == "table"
                and typeof(Info.inputTypes) == "table" then

                for _, InputType in ipairs(Info.inputTypes) do
                    if InputType == Enum.UserInputType.MouseButton1 then
                        Fallback = Btn
                        FallbackName = Name
                    end
                end
            end
        end
    end

    if Fallback then
        return Fallback, "ação " .. tostring(FallbackName) .. " (M1)"
    end

    return nil
end

local function ScanGui(Kind)
    for _, Obj in ipairs(PlayerGui:GetDescendants()) do
        if Obj:IsA("GuiButton") and not Obj:IsDescendantOf(Gui) and IsShown(Obj) then
            local Text = Obj.Name

            if Obj:IsA("TextButton") then
                Text ..= " " .. Obj.Text
            end

            if Obj.Parent then
                Text ..= " " .. Obj.Parent.Name
            end

            if Matches(Text, Kind) then
                return Obj, "botão " .. Obj.Name
            end
        end
    end

    return nil
end

-- Reencontra um botão calibrado que foi recriado pelo jogo
local function Refind(Cal)
    local Cam = workspace.CurrentCamera
    local View = Cam and Cam.ViewportSize or Gui.AbsoluteSize
    local Best
    local BestDistance = 0.12

    for _, Obj in ipairs(PlayerGui:GetDescendants()) do
        if Obj:IsA("GuiButton")
            and Obj.Name == Cal.Name
            and Obj.ClassName == Cal.Class
            and not Obj:IsDescendantOf(Gui)
            and IsShown(Obj) then

            local Center = Obj.AbsolutePosition + Obj.AbsoluteSize / 2
            local Fx = Center.X / View.X
            local Fy = Center.Y / View.Y
            local Distance = math.sqrt((Fx - Cal.Fx) ^ 2 + (Fy - Cal.Fy) ^ 2)

            if Distance < BestDistance then
                Best = Obj
                BestDistance = Distance
            end
        end
    end

    return Best
end

function GameInput.Find(Kind)
    local Now = os.clock()
    local Cached = GameInput.Cache[Kind]

    if Cached then
        if Cached.Btn then
            if IsLive(Cached.Btn) and Now - Cached.At < 1.5 then
                return Cached.Btn, Cached.Source
            end
        elseif Now - Cached.At < 2 then
            return nil
        end
    end

    local Btn, Source
    local Cal = GameInput.Calib[Kind]

    if Cal then
        if IsLive(Cal.Ref) then
            Btn, Source = Cal.Ref, "calibrado"
        else
            local Again = Refind(Cal)

            if Again then
                Cal.Ref = Again
                Btn, Source = Again, "calibrado"
            end
        end
    end

    if not Btn then
        Btn, Source = FindViaCAS(Kind)
    end

    if not Btn then
        Btn, Source = ScanGui(Kind)
    end

    GameInput.Cache[Kind] = {Btn = Btn, Source = Source, At = Now}

    return Btn, Source
end

-- Ação do jogo ligada ao clique do mouse (M1)
function GameInput.M1Action()
    local Ok, All = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)

    if not Ok or typeof(All) ~= "table" then
        return nil
    end

    for Name, Info in pairs(All) do
        if typeof(Info) == "table" and typeof(Info.inputTypes) == "table" then
            for _, InputType in ipairs(Info.inputTypes) do
                if InputType == Enum.UserInputType.MouseButton1 then
                    return tostring(Name)
                end
            end
        end
    end

    return nil
end

--------------------------------------------------
-- ATAQUE
--------------------------------------------------

-- PC: M1 = clique do mouse
function GameInput.ClickM1(Method)
    if Method ~= "SINAL" then
        if VIM then
            local P = SafePoint()

            if P and VirtualMouse(P, 0.02) then
                return true
            end
        end

        if typeof(mouse1click) == "function" then
            local Ok = pcall(mouse1click)

            if Ok then
                return true
            end
        end
    end

    local Btn = GameInput.Find("Attack")

    if Btn then
        return GameInput.PressButton(Btn, "SINAL", 0.03)
    end

    return false, "sem clique virtual e sem botão de ataque"
end

-- Mobile: botão de ataque do jogo
function GameInput.Attack(Mode, Method)
    if Mode == "PC" then
        return GameInput.ClickM1(Method)
    end

    local Btn = GameInput.Find("Attack")

    if not Btn then
        return false, "botão de ataque não encontrado (calibre)"
    end

    return GameInput.PressButton(Btn, Method or "AUTO", 0.03)
end

-- Escolhe sozinho conforme o aparelho
function GameInput.AttackAuto()
    local Mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    return GameInput.Attack(Mobile and "MOBILE" or "PC", "AUTO")
end

-- Aperta Block ou Dash (ou Ataque)
function GameInput.Press(Kind, Method)
    local Btn = GameInput.Find(Kind)

    if not Btn then
        return false, "botão não encontrado (calibre)"
    end

    return GameInput.PressButton(Btn, Method or "AUTO", 0.04)
end

function GameInput.Test(Kind, IsPC, Method)
    if Kind == "Attack" then
        return GameInput.Attack(IsPC and "PC" or "MOBILE", Method or "AUTO")
    end

    return GameInput.Press(Kind, Method)
end

--------------------------------------------------
-- TEXTO DE ESTADO + CALIBRAÇÃO
--------------------------------------------------

function GameInput.Describe(Kind, IsPC)
    local Btn, Source = GameInput.Find(Kind)
    local Name = GameInput.Names[Kind]

    if Btn then
        local Shown = IsShown(Btn)

        return "● " .. Name .. ": " .. Btn.Name .. " (" .. tostring(Source) .. ")"
            .. (Shown and "" or " • escondido"),
            Shown and GREEN or YELLOW
    end

    if Kind == "Attack" and IsPC then
        local M1 = GameInput.M1Action()

        return "● ATAQUE: M1 do mouse" .. (M1 and (" • ação " .. M1) or ""), GREEN
    end

    return "● " .. Name .. ": não encontrado • calibre", RED
end

function GameInput.ClearCalibration(Kind)
    GameInput.Calib[Kind] = nil
    GameInput.Cache[Kind] = nil
end

-- Toque no botão do jogo e o Hub aprende qual é
function GameInput.Calibrate(Kind, OnDone)
    if GameInput.Calibrating then
        Say("⚠ CALIBRAR", "Já tem uma calibração em andamento.", YELLOW)
        return
    end

    GameInput.Calibrating = Kind

    local WasOpen = Main.Visible
    Main.Visible = false

    local Name = GameInput.Names[Kind]

    Say("🎯 CALIBRAR " .. Name, "Toque agora no botão de " .. Name .. " do jogo. Você tem 10 s.", YELLOW)

    local Done = false
    local Conn

    local function Finish()
        if Done then
            return
        end

        Done = true
        GameInput.Calibrating = nil

        if Conn then
            Conn:Disconnect()
        end

        if WasOpen and Alive then
            Main.Visible = true
        end

        if OnDone then
            OnDone()
        end
    end

    Conn = UserInputService.InputBegan:Connect(function(Input)
        if Done then
            return
        end

        local Type = Input.UserInputType

        if Type ~= Enum.UserInputType.Touch and Type ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local Ok, Objects = pcall(function()
            return PlayerGui:GetGuiObjectsAtPosition(Input.Position.X, Input.Position.Y)
        end)

        if not Ok then
            return
        end

        local Found

        for _, Obj in ipairs(Objects) do
            if not Obj:IsDescendantOf(Gui) then
                local Walk = Obj

                while Walk and Walk ~= PlayerGui do
                    if Walk:IsA("GuiButton") then
                        Found = Walk
                        break
                    end

                    Walk = Walk.Parent
                end

                if Found then
                    break
                end
            end
        end

        if not Found then
            Say("⚠ CALIBRAR", "Nenhum botão ali. Toque no botão do jogo.", YELLOW)
            return
        end

        local Cam = workspace.CurrentCamera
        local View = Cam and Cam.ViewportSize or Gui.AbsoluteSize
        local Center = Found.AbsolutePosition + Found.AbsoluteSize / 2

        GameInput.Calib[Kind] = {
            Ref = Found,
            Name = Found.Name,
            Class = Found.ClassName,
            Fx = Center.X / View.X,
            Fy = Center.Y / View.Y,
        }

        GameInput.Cache[Kind] = nil

        Say("✓ " .. Name .. " CALIBRADO", "Botão: " .. Found.Name, GREEN)
        Finish()
    end)

    task.delay(10, function()
        if not Done then
            Say("⚠ CALIBRAR", "Tempo esgotado.", YELLOW)
            Finish()
        end
    end)
end

--==================================================
-- LISTA DE JOGADORES (COMPONENTE REUTILIZÁVEL)
-- Multiselect (padrão) ou escolha única (Single) • busca • avatar • distância
--==================================================

local PlayerLists = {}

local function CreatePlayerList(Page, TitleText, Set, Order, Single, OnChange)
    local ListCard, _, Desc = Card(
        Page,
        TitleText,
        Single and "toque em um jogador para escolher o alvo"
            or "0 marcados • toque nos nomes para marcar"
    )
    ListCard.LayoutOrder = Order

    local Obj = {Rows = {}}

    -- Busca
    local SearchBox = Instance.new("TextBox")
    SearchBox.Parent = ListCard
    SearchBox.LayoutOrder = 3
    SearchBox.Size = UDim2.new(1, 0, 0, 34)
    SearchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
    SearchBox.BackgroundTransparency = 0.15
    SearchBox.BorderSizePixel = 0
    SearchBox.PlaceholderText = "🔍 Buscar jogador..."
    SearchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(235, 235, 240)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 12
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.ZIndex = 17

    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 8)
    SearchCorner.Parent = SearchBox

    local SearchPad = Instance.new("UIPadding")
    SearchPad.PaddingLeft = UDim.new(0, 10)
    SearchPad.PaddingRight = UDim.new(0, 10)
    SearchPad.Parent = SearchBox

    -- Botões TODOS / LIMPAR (só na lista de marcar vários)
    local ButtonsRow = MakeRow(ListCard, 4)
    ButtonsRow.Size = UDim2.new(1, 0, 0, 34)
    ButtonsRow.Visible = not Single

    local AllButton = Button(ButtonsRow, "MARCAR TODOS", 1)
    AllButton.Size = UDim2.new(0.5, -3, 1, 0)

    local ClearButton = Button(ButtonsRow, "LIMPAR", 2)
    ClearButton.Size = UDim2.new(0.5, -3, 1, 0)

    -- Linhas
    local Holder = Instance.new("Frame")
    Holder.Parent = ListCard
    Holder.LayoutOrder = 5
    Holder.Size = UDim2.new(1, 0, 0, 0)
    Holder.AutomaticSize = Enum.AutomaticSize.Y
    Holder.BackgroundTransparency = 1
    Holder.ZIndex = 16

    local HolderLayout = Instance.new("UIListLayout")
    HolderLayout.Padding = UDim.new(0, 5)
    HolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
    HolderLayout.Parent = Holder

    local Empty = Instance.new("TextLabel")
    Empty.Parent = ListCard
    Empty.LayoutOrder = 6
    Empty.Size = UDim2.new(1, 0, 0, 28)
    Empty.BackgroundTransparency = 1
    Empty.Text = "Nenhum outro jogador no servidor"
    Empty.Font = Enum.Font.Gotham
    Empty.TextSize = 11
    Empty.TextColor3 = Color3.fromRGB(175, 175, 185)
    Empty.ZIndex = 16

    local function UpdateCount()
        if Single then
            local Name

            for Chosen in pairs(Set) do
                Name = Chosen.DisplayName
            end

            Desc.Text = Name
                and ("alvo: " .. Name .. " • toque de novo para tirar")
                or "toque em um jogador para escolher o alvo"

            return
        end

        local N = 0

        for _ in pairs(Set) do
            N += 1
        end

        Desc.Text = N
            .. (N == 1 and " marcado" or " marcados")
            .. " • toque nos nomes para marcar"
    end

    local function Style(Entry)
        local Selected = Set[Entry.Player] == true

        Entry.Row.BackgroundColor3 = Selected and SELECTED_COLOR or ROW_COLOR
        Entry.Check.Text = Selected and "✓" or ""
        Entry.Check.BackgroundColor3 = Selected
            and Color3.fromRGB(0, 170, 255)
            or Color3.fromRGB(40, 40, 48)
    end

    local function ApplyFilter()
        local Query = string.lower(SearchBox.Text)
        local Shown = 0

        for _, Entry in pairs(Obj.Rows) do
            local P = Entry.Player

            local Match = Query == ""
                or string.find(string.lower(P.Name), Query, 1, true) ~= nil
                or string.find(string.lower(P.DisplayName), Query, 1, true) ~= nil

            Entry.Row.Visible = Match

            if Match then
                Shown += 1
            end
        end

        Empty.Visible = Shown == 0
        Empty.Text = next(Obj.Rows) == nil
            and "Nenhum outro jogador no servidor"
            or "Nenhum jogador encontrado"
    end

    -- Ordem alfabética estável (a lista não "pula" enquanto você toca)
    local function Reorder()
        local Sorted = {}

        for _, Entry in pairs(Obj.Rows) do
            table.insert(Sorted, Entry)
        end

        table.sort(Sorted, function(A, B)
            return string.lower(A.Player.DisplayName)
                < string.lower(B.Player.DisplayName)
        end)

        for Index, Entry in ipairs(Sorted) do
            Entry.Row.LayoutOrder = Index
        end
    end

    function Obj.Add(Target)
        if Target == Player or Obj.Rows[Target] then
            return
        end

        local Row = Instance.new("TextButton")
        Row.Parent = Holder
        Row.Size = UDim2.new(1, 0, 0, 46)
        Row.BackgroundColor3 = ROW_COLOR
        Row.BackgroundTransparency = 0.15
        Row.BorderSizePixel = 0
        Row.AutoButtonColor = false
        Row.Text = ""
        Row.ZIndex = 17

        local RowCorner = Instance.new("UICorner")
        RowCorner.CornerRadius = UDim.new(0, 8)
        RowCorner.Parent = Row

        local Avatar = Instance.new("ImageLabel")
        Avatar.Parent = Row
        Avatar.AnchorPoint = Vector2.new(0, 0.5)
        Avatar.Position = UDim2.new(0, 6, 0.5, 0)
        Avatar.Size = UDim2.fromOffset(34, 34)
        Avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        Avatar.BorderSizePixel = 0
        Avatar.Image = "rbxthumb://type=AvatarHeadShot&id="
            .. Target.UserId .. "&w=60&h=60"
        Avatar.ZIndex = 18

        local AvatarCorner = Instance.new("UICorner")
        AvatarCorner.CornerRadius = UDim.new(1, 0)
        AvatarCorner.Parent = Avatar

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Parent = Row
        NameLabel.Position = UDim2.new(0, 48, 0, 6)
        NameLabel.Size = UDim2.new(1, -86, 0, 18)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = Target.DisplayName
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.TextSize = 12
        NameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        NameLabel.ZIndex = 18

        local Sub = Instance.new("TextLabel")
        Sub.Parent = Row
        Sub.Position = UDim2.new(0, 48, 0, 25)
        Sub.Size = UDim2.new(1, -86, 0, 14)
        Sub.BackgroundTransparency = 1
        Sub.Text = "@" .. Target.Name
        Sub.Font = Enum.Font.Gotham
        Sub.TextSize = 10
        Sub.TextColor3 = Color3.fromRGB(175, 175, 185)
        Sub.TextXAlignment = Enum.TextXAlignment.Left
        Sub.TextTruncate = Enum.TextTruncate.AtEnd
        Sub.ZIndex = 18

        local Check = Instance.new("TextLabel")
        Check.Parent = Row
        Check.AnchorPoint = Vector2.new(1, 0.5)
        Check.Position = UDim2.new(1, -8, 0.5, 0)
        Check.Size = UDim2.fromOffset(24, 24)
        Check.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        Check.BorderSizePixel = 0
        Check.Text = ""
        Check.Font = Enum.Font.GothamBold
        Check.TextSize = 14
        Check.TextColor3 = Color3.fromRGB(255, 255, 255)
        Check.ZIndex = 18

        local CheckCorner = Instance.new("UICorner")
        CheckCorner.CornerRadius = UDim.new(0, 6)
        CheckCorner.Parent = Check

        local Entry = {
            Player = Target,
            Row = Row,
            Sub = Sub,
            Check = Check,
        }

        Obj.Rows[Target] = Entry

        Row.Activated:Connect(function()
            if Single then
                if Set[Target] then
                    Set[Target] = nil
                else
                    table.clear(Set)
                    Set[Target] = true
                end

                for _, Other in pairs(Obj.Rows) do
                    Style(Other)
                end
            else
                if Set[Target] then
                    Set[Target] = nil
                else
                    Set[Target] = true
                end

                Style(Entry)
            end

            UpdateCount()

            if OnChange then
                OnChange()
            end
        end)

        Style(Entry)
        Reorder()
        ApplyFilter()
        UpdateCount()
    end

    function Obj.Remove(Target)
        local Entry = Obj.Rows[Target]

        if Entry then
            Entry.Row:Destroy()
            Obj.Rows[Target] = nil
        end

        Set[Target] = nil

        ApplyFilter()
        UpdateCount()

        if OnChange then
            OnChange()
        end
    end

    function Obj.UpdateDistances(MyPosition)
        for _, Entry in pairs(Obj.Rows) do
            if Entry.Row.Visible then
                local Root = GetPlayerRoot(Entry.Player)
                local Text = "@" .. Entry.Player.Name

                if not Root then
                    Text ..= " • sem personagem"
                elseif MyPosition then
                    Text ..= " • "
                        .. math.floor((Root.Position - MyPosition).Magnitude + 0.5)
                        .. " studs"
                end

                Entry.Sub.Text = Text
            end
        end
    end

    Track(SearchBox:GetPropertyChangedSignal("Text"):Connect(ApplyFilter))

    AllButton.Activated:Connect(function()
        for _, Entry in pairs(Obj.Rows) do
            if Entry.Row.Visible then
                Set[Entry.Player] = true
                Style(Entry)
            end
        end

        UpdateCount()
    end)

    ClearButton.Activated:Connect(function()
        table.clear(Set)

        for _, Entry in pairs(Obj.Rows) do
            Style(Entry)
        end

        UpdateCount()
    end)

    ApplyFilter()
    table.insert(PlayerLists, Obj)

    return Obj
end

--==================================================
-- STATUS (FPS • PING • MÓDULOS) — COMPACTO E LARGO
--==================================================

do
    local Page = Pages.Status

    local StatsRow = Instance.new("Frame")
    StatsRow.Parent = Page
    StatsRow.LayoutOrder = 1
    StatsRow.Size = UDim2.new(1, 0, 0, 64)
    StatsRow.BackgroundTransparency = 1
    StatsRow.ZIndex = 15

    local RowLayout = Instance.new("UIListLayout")
    RowLayout.FillDirection = Enum.FillDirection.Horizontal
    RowLayout.Padding = UDim.new(0, 8)
    RowLayout.Parent = StatsRow

    local function StatBox(TitleText)
        local Box = Instance.new("Frame")
        Box.Parent = StatsRow
        Box.Size = UDim2.new(0.5, -4, 1, 0)
        Box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        Box.BackgroundTransparency = CARD_ALPHA
        Box.BorderSizePixel = 0
        Box.ZIndex = 15

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 10)
        Corner.Parent = Box

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(43, 43, 52)
        Stroke.Parent = Box

        local T = Instance.new("TextLabel")
        T.Parent = Box
        T.Position = UDim2.new(0, 0, 0, 7)
        T.Size = UDim2.new(1, 0, 0, 14)
        T.BackgroundTransparency = 1
        T.Text = TitleText
        T.Font = Enum.Font.GothamBold
        T.TextSize = 10
        T.TextColor3 = Color3.fromRGB(175, 175, 185)
        T.ZIndex = 16

        local V = Instance.new("TextLabel")
        V.Parent = Box
        V.Position = UDim2.new(0, 0, 0, 22)
        V.Size = UDim2.new(1, 0, 0, 34)
        V.BackgroundTransparency = 1
        V.Text = "--"
        V.Font = Enum.Font.GothamBold
        V.TextSize = 24
        V.TextColor3 = Color3.fromRGB(245, 245, 250)
        V.TextStrokeTransparency = 0.7
        V.ZIndex = 16

        return V
    end

    local FpsValue = StatBox("FPS")
    local MsValue = StatBox("PING")

    local HubCard, StateRight = Section(Page, "HUB", 2)

    local Grid = Instance.new("Frame")
    Grid.Parent = HubCard
    Grid.LayoutOrder = 2
    Grid.Size = UDim2.new(1, 0, 0, 0)
    Grid.AutomaticSize = Enum.AutomaticSize.Y
    Grid.BackgroundTransparency = 1
    Grid.ZIndex = 16

    local GridLayout = Instance.new("UIGridLayout")
    GridLayout.CellSize = UDim2.new(0.5, -3, 0, 30)
    GridLayout.CellPadding = UDim2.fromOffset(6, 6)
    GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    GridLayout.Parent = Grid

    local Chips = {}

    local function MakeChip(Key, Order, NameText)
        local Frame = Instance.new("Frame")
        Frame.Parent = Grid
        Frame.LayoutOrder = Order
        Frame.BackgroundColor3 = ROW_COLOR
        Frame.BackgroundTransparency = CARD_ALPHA
        Frame.BorderSizePixel = 0
        Frame.ZIndex = 16

        local ChipCorner = Instance.new("UICorner")
        ChipCorner.CornerRadius = UDim.new(0, 8)
        ChipCorner.Parent = Frame

        local Dot = Instance.new("Frame")
        Dot.Parent = Frame
        Dot.AnchorPoint = Vector2.new(0, 0.5)
        Dot.Position = UDim2.new(0, 9, 0.5, 0)
        Dot.Size = UDim2.fromOffset(8, 8)
        Dot.BackgroundColor3 = MUTED_TEXT
        Dot.BorderSizePixel = 0
        Dot.ZIndex = 17

        local DotCorner = Instance.new("UICorner")
        DotCorner.CornerRadius = UDim.new(1, 0)
        DotCorner.Parent = Dot

        local NameLabel = Instance.new("TextLabel")
        NameLabel.Parent = Frame
        NameLabel.Position = UDim2.new(0, 23, 0, 0)
        NameLabel.Size = UDim2.new(1, -23, 1, 0)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = NameText
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.TextSize = 10
        NameLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.ZIndex = 17

        local Tag = Instance.new("TextLabel")
        Tag.Parent = Frame
        Tag.Size = UDim2.new(1, -8, 1, 0)
        Tag.BackgroundTransparency = 1
        Tag.Text = ""
        Tag.Font = Enum.Font.GothamBold
        Tag.TextSize = 10
        Tag.TextColor3 = MUTED_TEXT
        Tag.TextXAlignment = Enum.TextXAlignment.Right
        Tag.ZIndex = 17

        Chips[Key] = {Dot = Dot, Tag = Tag}
    end

    MakeChip("Anti", 1, "ANTI")
    MakeChip("Fake", 2, "FAKE")
    MakeChip("Fling", 3, "FLING")
    MakeChip("Escape", 4, "FUGA")
    MakeChip("Void", 5, "VOID")
    MakeChip("AutoVoid", 6, "AUTO-VOID")
    MakeChip("NPC", 7, "NPC")
    MakeChip("TP", 8, "TP")
    MakeChip("Dodge", 9, "ESQUIVA")
    MakeChip("Farm", 10, "FARM")
    MakeChip("Stun", 11, "ANTI-STUN")
    MakeChip("Assist", 12, "ASSIST")
    MakeChip("Reset", 13, "RESET")
    MakeChip("Block", 14, "BLOCK")

    local function SetChip(Key, DotColor, TagText, TagColor)
        local Chip = Chips[Key]

        Chip.Dot.BackgroundColor3 = DotColor
        Chip.Tag.Text = TagText
        Chip.Tag.TextColor3 = TagColor or DotColor
    end

    local FailLabel = Instance.new("TextLabel")
    FailLabel.Parent = HubCard
    FailLabel.LayoutOrder = 3
    FailLabel.Size = UDim2.new(1, 0, 0, 0)
    FailLabel.AutomaticSize = Enum.AutomaticSize.Y
    FailLabel.BackgroundTransparency = 1
    FailLabel.Text = ""
    FailLabel.Visible = false
    FailLabel.Font = Enum.Font.Gotham
    FailLabel.TextSize = 10
    FailLabel.TextWrapped = true
    FailLabel.TextColor3 = RED
    FailLabel.TextStrokeTransparency = 0.7
    FailLabel.TextXAlignment = Enum.TextXAlignment.Left
    FailLabel.TextYAlignment = Enum.TextYAlignment.Top
    FailLabel.ZIndex = 16

    RefreshHub = function()
        local NpcFound = GetNPCTorso() ~= nil
        local NpcMissing = State.Teleport and not NpcFound

        local Lines = {}

        for Name, Message in pairs(Failures) do
            table.insert(Lines, "✖ " .. Name .. ": " .. ShortText(Message))
        end

        if NpcMissing then
            table.insert(Lines, "✖ NPC ausente")
        end

        table.sort(Lines)

        FailLabel.Text = table.concat(Lines, "\n")
        FailLabel.Visible = #Lines > 0

        if #Lines > 0 then
            StateRight.Text = "● FALHA"
            StateRight.TextColor3 = RED
        else
            StateRight.Text = "● TUDO OK"
            StateRight.TextColor3 = GREEN
        end

        -- ANTI (beta)
        local AntiFail = Failures["Anti-Fakeout"] ~= nil

        SetChip(
            "Anti",
            AntiFail and RED or (State.Anti and GREEN or MUTED_TEXT),
            AntiFail and "ERRO" or "BETA",
            AntiFail and RED or YELLOW
        )

        -- FAKE (beta)
        local FakeFail = Failures["Fakeout"] ~= nil

        SetChip(
            "Fake",
            FakeFail and RED or (State.Fakeout and GREEN or MUTED_TEXT),
            FakeFail and "ERRO" or "BETA",
            FakeFail and RED or YELLOW
        )

        -- FLING
        local FlingFail = Failures["Anti-Fling"] ~= nil
        local FlingText = "OFF"

        if State.AntiFling then
            FlingText = "ON"

            if Hooks.FlingBlocked > 0 then
                FlingText = "ON · " .. Hooks.FlingBlocked
            end
        end

        SetChip(
            "Fling",
            FlingFail and RED or (State.AntiFling and GREEN or MUTED_TEXT),
            FlingFail and "ERRO" or FlingText
        )

        -- FUGA
        local EscapeFail = Failures["Auto-Fuga"] ~= nil
        local EscapeText = "OFF"

        if State.Escaping then
            EscapeText = "FUGINDO"
        elseif State.Escape then
            EscapeText = Hooks.EscapeCount > 0 and ("ON · " .. Hooks.EscapeCount) or "ON"
        end

        SetChip(
            "Escape",
            EscapeFail and RED or (State.Escaping and YELLOW or (State.Escape and GREEN or MUTED_TEXT)),
            EscapeFail and "ERRO" or EscapeText
        )

        -- VOID e AUTO-VOID
        local VoidFail = Failures["Recuperar Void"] ~= nil

        SetChip(
            "Void",
            VoidFail and RED or (State.VoidRec and GREEN or MUTED_TEXT),
            VoidFail and "ERRO" or (State.VoidRec and "ON" or "OFF")
        )

        SetChip(
            "AutoVoid",
            VoidFail and RED or (State.AutoRec and GREEN or MUTED_TEXT),
            VoidFail and "ERRO" or (State.AutoRec and "ON" or "OFF")
        )

        -- NPC
        if Failures["Teleporte NPC"] ~= nil then
            SetChip("NPC", RED, "ERRO")
        elseif State.Teleport and NpcFound then
            SetChip("NPC", GREEN, "PRESO")
        elseif NpcFound then
            SetChip("NPC", GREEN, "OK")
        elseif State.Teleport then
            SetChip("NPC", RED, "AUSENTE")
        else
            SetChip("NPC", MUTED_TEXT, "AUSENTE")
        end

        -- TP JOGADOR
        SetChip(
            "TP",
            State.PlayerTP and GREEN or MUTED_TEXT,
            State.PlayerTP and "ON" or "OFF"
        )

        -- ESQUIVA
        SetChip(
            "Dodge",
            State.Dodge and GREEN or MUTED_TEXT,
            State.Dodge and "ON" or "OFF"
        )

        -- AUTOFARM
        local FarmFail = Failures["Autofarm"] ~= nil
        local FarmText = "OFF"

        if State.FarmMobile then
            FarmText = "ON · MOB"
        elseif State.FarmPC then
            FarmText = "ON · PC"
        end

        SetChip(
            "Farm",
            FarmFail and RED or (State.Farm and GREEN or MUTED_TEXT),
            FarmFail and "ERRO" or FarmText
        )

        -- ANTI-STUN
        local StunFail = Failures["Anti-Stun"] ~= nil

        SetChip(
            "Stun",
            StunFail and RED or (State.AntiStun and GREEN or MUTED_TEXT),
            StunFail and "ERRO" or (State.AntiStun and "ON" or "OFF")
        )

        -- ASSIST (dash / aim)
        local AssistFail = Failures["Dash/Aim Assist"] ~= nil
        local AssistOn = State.Dash or State.Aim

        if AssistFail then
            SetChip("Assist", RED, "ERRO")
        elseif State.Aim and Hooks.AimPaused then
            SetChip("Assist", YELLOW, "PAUSA")
        else
            SetChip(
                "Assist",
                AssistOn and GREEN or MUTED_TEXT,
                AssistOn and "ON" or "OFF"
            )
        end

        -- RESET
        local ResetFail = Failures["Auto-Reset"] ~= nil

        if ResetFail then
            SetChip("Reset", RED, "ERRO")
        elseif State.AutoReset and Hooks.ResetWarn then
            SetChip("Reset", YELLOW, "TRAVADO")
        elseif State.AutoReset then
            SetChip("Reset", GREEN, "ON")
        else
            SetChip("Reset", MUTED_TEXT, "OFF")
        end

        -- BLOCK (trancado)
        local BlockFail = Failures["Auto-Block"] ~= nil

        SetChip(
            "Block",
            BlockFail and RED or (State.Blocking and YELLOW or (State.AutoBlock and GREEN or MUTED_TEXT)),
            BlockFail and "ERRO" or (State.Blocking and "BLOCK" or (State.AutoBlock and "ON" or "OFF"))
        )

        if NpcInfoLabel then
            NpcInfoLabel.Text = NpcFound
                and "● NPC encontrado"
                or "● NPC não encontrado"

            NpcInfoLabel.TextColor3 = NpcFound and GREEN or RED
        end
    end

    local function GetPing()
        local Ok, Value = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)

        if Ok and typeof(Value) == "number" then
            return math.floor(Value + 0.5)
        end

        local Ok2, Value2 = pcall(function()
            return Player:GetNetworkPing() * 2000
        end)

        if Ok2 and typeof(Value2) == "number" then
            return math.floor(Value2 + 0.5)
        end

        return nil
    end

    local Frames = 0
    local Accum = 0

    Track(RunService.RenderStepped:Connect(function(dt)
        if not Alive then
            return
        end

        Frames += 1
        Accum += dt

        if Accum < 0.5 then
            return
        end

        local Fps = math.floor(Frames / Accum + 0.5)
        Frames = 0
        Accum = 0

        FpsValue.Text = tostring(Fps)
        FpsValue.TextColor3 =
            Fps >= 50 and GREEN
            or Fps >= 30 and YELLOW
            or RED

        local Ping = GetPing()

        if Ping then
            MsValue.Text = tostring(Ping)
            MsValue.TextColor3 =
                Ping <= 80 and GREEN
                or Ping <= 150 and YELLOW
                or RED
        else
            MsValue.Text = "--"
            MsValue.TextColor3 = Color3.fromRGB(245, 245, 250)
        end

        RefreshHub()
    end))
end

--==================================================
-- ANTI-FAKEOUT (BETA)
-- Detecta teleporte brusco (salto grande num frame), leva ao NPC
-- por 1.5 s e depois volta para a plataforma.
--==================================================

do
    local Page = Pages.AntiFakeout

    local ProtectionRunning = false
    local LastProtection = 0
    local LastPos = nil
    local LastRoot = nil

    local HOLD_TIME = 1.5
    local MIN_STUDS = 150
    local MAX_STUDS = 400
    local STEP_STUDS = 50
    local COOLDOWN = 1
    local Threshold = 150

    local RESPONSE_OPTIONS = {0, 25, 50, 100, 150}
    local ResponseIndex = 3
    local ResponseMS = RESPONSE_OPTIONS[ResponseIndex]

    local Activation = Card(
        Page,
        "ANTI-FAKEOUT",
        "BETA • Detecta teleporte brusco (salto de " .. MIN_STUDS .. "+ studs num frame), leva você ao NPC por 1.5 s e depois à plataforma. Se falhar, o Auto-Recuperar assume."
    )
    Activation.LayoutOrder = 1

    local AntiToggle = Button(Activation, "ANTI-FAKEOUT • OFF", 3)

    local DistCard = Card(
        Page,
        "DISTÂNCIA DE GATILHO",
        "Salto mínimo por frame para ativar (150 a 400 studs). Menor = mais sensível."
    )
    DistCard.LayoutOrder = 2

    local DistRow = MakeRow(DistCard, 3)

    local DistMinus = Button(DistRow, "−", 1)
    DistMinus.Size = UDim2.fromOffset(46, 38)

    local DistLabel = Instance.new("TextLabel")
    DistLabel.Parent = DistRow
    DistLabel.LayoutOrder = 2
    DistLabel.Size = UDim2.new(1, -(46 * 2 + 12), 1, 0)
    DistLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
    DistLabel.BackgroundTransparency = 0.15
    DistLabel.BorderSizePixel = 0
    DistLabel.Text = Threshold .. " studs"
    DistLabel.Font = Enum.Font.GothamBold
    DistLabel.TextSize = 13
    DistLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
    DistLabel.ZIndex = 17

    local DistCorner = Instance.new("UICorner")
    DistCorner.CornerRadius = UDim.new(0, 8)
    DistCorner.Parent = DistLabel

    local DistPlus = Button(DistRow, "+", 3)
    DistPlus.Size = UDim2.fromOffset(46, 38)

    local Response = Card(Page, "TEMPO DE RESPOSTA", "Delay antes da ação.")
    Response.LayoutOrder = 3

    local ResponseButton = Button(
        Response,
        "RESPOSTA • " .. ResponseMS .. "ms",
        3
    )

    local InfoCard, _, Info = Card(Page, "ESTADO", "● Desligado")
    InfoCard.LayoutOrder = 4
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local function SetInfo(Text, Color)
        Info.Text = Text
        Info.TextColor3 = Color
    end

    local LastJumpText = nil

    local function RestingInfo()
        if State.Anti then
            SetInfo(LastJumpText or "● Vigiando", GREEN)
        else
            SetInfo("● Desligado", MUTED_TEXT)
        end
    end

    local function SetThreshold(Value)
        Threshold = math.clamp(Value, MIN_STUDS, MAX_STUDS)
        DistLabel.Text = Threshold .. " studs"
    end

    DistMinus.Activated:Connect(function()
        SetThreshold(Threshold - STEP_STUDS)
    end)

    DistPlus.Activated:Connect(function()
        SetThreshold(Threshold + STEP_STUDS)
    end)

    ResponseButton.Activated:Connect(function()
        ResponseIndex = (ResponseIndex % #RESPONSE_OPTIONS) + 1
        ResponseMS = RESPONSE_OPTIONS[ResponseIndex]
        ResponseButton.Text = "RESPOSTA • " .. ResponseMS .. "ms"
    end)

    AntiToggle.Activated:Connect(function()
        State.Anti = not State.Anti

        if State.Anti then
            AntiToggle.Text = "ANTI-FAKEOUT • ON"
            AntiToggle.BackgroundColor3 = ON_COLOR
        else
            AntiToggle.Text = "ANTI-FAKEOUT • OFF"
            AntiToggle.BackgroundColor3 = OFF_COLOR
            ClearFailure("Anti-Fakeout")
        end

        LastPos = nil
        LastRoot = nil

        if not ProtectionRunning then
            RestingInfo()
        end

        if RefreshHub then
            RefreshHub()
        end
    end)

    local function ProtectionBody(From)
        local HRP = GetHRP()

        if not HRP then
            return
        end

        local Torso = GetNPCTorso()

        if not Torso then
            ReturnToPlatform(From)
            return
        end

        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero
        HRP.CFrame = Torso.CFrame
        HRP.Anchored = true

        if ResponseMS > 0 then
            task.wait(ResponseMS / 1000)
        end

        local StartTime = os.clock()

        while Alive and State.Anti and os.clock() - StartTime < HOLD_TIME do
            HRP = GetHRP()
            Torso = GetNPCTorso()

            if not HRP or not Torso then
                break
            end

            HRP.CFrame = Torso.CFrame
            HRP.AssemblyLinearVelocity = Vector3.zero

            RunService.Heartbeat:Wait()
        end

        HRP = GetHRP()

        if HRP then
            HRP.Anchored = false
        end

        ReturnToPlatform(From)
    end

    local function RunProtection(From, Jump)
        if ProtectionRunning then
            return
        end

        ProtectionRunning = true
        State.AntiRunning = true

        SetInfo("● Fakeout detectado • " .. math.floor(Jump + 0.5) .. " studs", YELLOW)

        local Ok, Err = pcall(ProtectionBody, From)

        pcall(function()
            local HRP = GetHRP()

            if HRP then
                HRP.Anchored = false
            end
        end)

        ProtectionRunning = false
        State.AntiRunning = false
        LastProtection = os.clock()
        LastPos = nil
        Grace(0.8)

        if Ok then
            ClearFailure("Anti-Fakeout")
            LastJumpText = "● Última: " .. math.floor(Jump + 0.5) .. " studs"
        else
            SetFailure("Anti-Fakeout", tostring(Err))

            if Hooks.Recover then
                task.spawn(Hooks.Recover, true)
            end
        end

        RestingInfo()
    end

    Track(RunService.Heartbeat:Connect(function()
        if not Alive then
            return
        end

        local HRP = GetPlayerRoot(Player)

        if not State.Anti or not HRP then
            LastPos = nil
            LastRoot = nil
            return
        end

        if HRP ~= LastRoot then
            LastRoot = HRP
            LastPos = HRP.Position
            return
        end

        local Pos = HRP.Position

        local Busy = ProtectionRunning
            or State.FakeRunning
            or State.RecRunning
            or State.Teleport
            or State.Escaping
            or InGrace()

        if Busy then
            LastPos = Pos
            return
        end

        local Prev = LastPos
        LastPos = Pos

        if not Prev then
            return
        end

        local Jump = (Pos - Prev).Magnitude

        if Jump ~= Jump then
            return
        end

        if Jump >= Threshold and os.clock() - LastProtection >= COOLDOWN then
            task.spawn(RunProtection, Prev, Jump)
        end
    end))

    Track(Player.CharacterAdded:Connect(function()
        LastPos = nil
        LastRoot = nil
        Grace(1.5)
    end))
end

--==================================================
-- TELEPORTE PARA O NPC + ATAQUE + REJOIN
-- Segue o NPC a qualquer lugar (inclusive fora do mapa, no fakeout dele)
-- sem morrer no void, e ataca com o M1 enquanto está preso.
--==================================================

do
    local Page = Pages.NPCTeleport
    local HoldConns = {}

    local FORCE_LEVELS = {
        {Name = "NORMAL", Multi = false, Anchor = false},
        {Name = "FORTE", Multi = true, Anchor = false},
        {Name = "MÁXIMA", Multi = true, Anchor = true},
    }

    local ForceIndex = 2

    local POSITIONS = {
        {Name = "DENTRO", Behind = nil},
        {Name = "ATRÁS 2.2", Behind = 2.2},
        {Name = "ATRÁS 4", Behind = 4},
    }

    local PosIndex = 1
    local AttackOn = true
    local AttackGen = 0
    local AttackFails = 0

    local Card1 = Card(
        Page,
        "TELEPORTAR PARA O NPC",
        "Teleporta e prende você no NPC, mesmo depois de morrer ou resetar. Segue o NPC até fora do mapa (fakeout dele) sem você morrer no void. Ao desativar, volta para a plataforma."
    )
    Card1.LayoutOrder = 1

    local Toggle = Button(Card1, "TELEPORTE • OFF", 3)

    local CardAtk = Card(
        Page,
        "ATAQUE NO NPC",
        "Enquanto está preso, ataca sozinho com o M1 (clique do mouse no PC, botão de ataque do jogo no mobile). Continua atacando quando o NPC sai do mapa. Se não atacar, calibre o botão na aba AUTOFARM."
    )
    CardAtk.LayoutOrder = 2

    local AtkToggle = Button(CardAtk, "ATAQUE AUTOMÁTICO • ON", 3)
    AtkToggle.BackgroundColor3 = ON_COLOR

    local PosButton = Button(CardAtk, "POSIÇÃO • " .. POSITIONS[PosIndex].Name, 4)

    local CardForce = Card(
        Page,
        "FORÇA DA PRISÃO",
        "NORMAL: suave. FORTE: reforçada a cada frame. MÁXIMA: também trava o personagem no lugar."
    )
    CardForce.LayoutOrder = 3

    local ForceButton = Button(
        CardForce,
        "FORÇA • " .. FORCE_LEVELS[ForceIndex].Name,
        3
    )

    local Card2, _, Info = Card(Page, "ESTADO DO NPC", "Verificando...")
    Card2.LayoutOrder = 4
    Info.Font = Enum.Font.GothamBold
    NpcInfoLabel = Info

    --------------------------------------------------
    -- REJOIN RÁPIDO (MESMO SERVIDOR)
    --------------------------------------------------

    local Card3 = Card(
        Page,
        "REJOIN RÁPIDO",
        "Sai e volta para o mesmo servidor. Se você for o único jogador, o servidor fecha e o Roblox te leva para um novo. Servidor cheio ou privado pode falhar. Toque duas vezes para confirmar."
    )
    Card3.LayoutOrder = 7

    local RejoinButton = Button(Card3, "REJOIN • MESMO SERVIDOR", 3)
    local RejoinInfo = Caption(Card3, "", 4)

    local RejoinBusy = false
    local Armed = false
    local ConfirmToken = 0

    local function ResetRejoinButton()
        RejoinButton.Text = "REJOIN • MESMO SERVIDOR"
        RejoinButton.BackgroundColor3 = OFF_COLOR
    end

    local function SetRejoinInfo(Text, Color)
        RejoinInfo.Text = Text
        RejoinInfo.TextColor3 = Color
    end

    local function DoRejoin()
        RejoinBusy = true
        RejoinButton.Text = "ENTRANDO..."
        RejoinButton.BackgroundColor3 = SELECTED_COLOR
        SetRejoinInfo("● Reentrando no servidor...", YELLOW)

        local Ok, Err = pcall(function()
            if #Players:GetPlayers() <= 1 then
                TeleportService:Teleport(game.PlaceId, Player)
            else
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    game.JobId,
                    Player
                )
            end
        end)

        if not Ok then
            RejoinBusy = false
            ResetRejoinButton()
            SetRejoinInfo("● Falhou: " .. tostring(Err), RED)
            return
        end

        task.delay(12, function()
            if Alive and RejoinBusy then
                RejoinBusy = false
                ResetRejoinButton()
                SetRejoinInfo("● Não conectou. Tente de novo.", RED)
            end
        end)
    end

    Track(TeleportService.TeleportInitFailed:Connect(function(Who, Result, Message)
        if Who ~= Player or not Alive then
            return
        end

        RejoinBusy = false
        Armed = false
        ResetRejoinButton()
        SetRejoinInfo("● Falhou: " .. tostring(Message or Result), RED)
    end))

    RejoinButton.Activated:Connect(function()
        if RejoinBusy then
            return
        end

        if not Armed then
            Armed = true
            ConfirmToken += 1
            local My = ConfirmToken

            RejoinButton.Text = "TOQUE DE NOVO PARA CONFIRMAR"
            RejoinButton.BackgroundColor3 = WARN_COLOR
            SetRejoinInfo("", MUTED_TEXT)

            task.delay(3, function()
                if Alive and Armed and My == ConfirmToken and not RejoinBusy then
                    Armed = false
                    ResetRejoinButton()
                end
            end)

            return
        end

        Armed = false
        DoRejoin()
    end)

    --------------------------------------------------
    -- TELEPORTE NPC (PRENDE MESMO DEPOIS DE MORRER / RESETAR)
    --------------------------------------------------

    local function Hold()
        if not State.Teleport or State.Escaping then
            return
        end

        local Character = Player.Character
        local HRP = Character and Character:FindFirstChild("HumanoidRootPart")
        local Torso = GetNPCTorso()

        if not HRP or not Torso then
            return
        end

        local Where = POSITIONS[PosIndex]

        if Where.Behind then
            HRP.CFrame = Combat.BehindCFrame(Torso, Where.Behind, 0.04)
        else
            HRP.CFrame = Torso.CFrame
        end

        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero

        if FORCE_LEVELS[ForceIndex].Anchor and not HRP.Anchored then
            HRP.Anchored = true
        end
    end

    local function SafeHold()
        local Ok, Err = pcall(Hold)

        if not Ok then
            SetFailure("Teleporte NPC", tostring(Err))
        end
    end

    local function Release()
        for _, Conn in ipairs(HoldConns) do
            pcall(function()
                Conn:Disconnect()
            end)
        end

        table.clear(HoldConns)
    end

    local function StartAttackLoop()
        AttackGen += 1
        local My = AttackGen

        task.spawn(function()
            while Alive and My == AttackGen and State.Teleport do
                task.wait(0.07)

                if AttackOn
                    and State.Teleport
                    and not State.Escaping
                    and not State.Blocking
                    and GetNPCTorso()
                    and GetPlayerRoot(Player) then

                    local Called, Ok, Why = pcall(GameInput.AttackAuto)

                    if Called and Ok then
                        if AttackFails >= 5 then
                            ClearFailure("Teleporte NPC")
                        end

                        AttackFails = 0
                    else
                        AttackFails += 1

                        if AttackFails == 5 then
                            SetFailure(
                                "Teleporte NPC",
                                "ataque: " .. tostring(Called and Why or Ok)
                            )
                        end
                    end
                end
            end
        end)
    end

    local function Stop(GoBack)
        State.Teleport = false
        AttackGen += 1
        Release()

        pcall(function()
            local HRP = GetHRP()

            if HRP then
                HRP.Anchored = false
            end
        end)

        VoidShield.Remove("npc")

        Toggle.Text = "TELEPORTE • OFF"
        Toggle.BackgroundColor3 = OFF_COLOR

        if GoBack then
            ReturnToPlatform()
        end

        Grace(0.8)
        ClearFailure("Teleporte NPC")

        task.delay(0.6, function()
            if not Alive or State.Teleport or State.AntiRunning then
                return
            end

            local HRP = GetHRP()

            if HRP and HRP.Anchored then
                HRP.Anchored = false

                Say(
                    "⚠ TELEPORTE NPC",
                    "O personagem continuava travado depois de desligar. Solto.",
                    YELLOW
                )
            end
        end)
    end

    local function Start()
        if State.Farm then
            Toggle.Text = "DESLIGUE O AUTOFARM"
            Say("⚠ CONFLITO", "Desligue o Autofarm antes de ligar o Teleporte NPC.", YELLOW)

            task.delay(1.5, function()
                if Alive and not State.Teleport then
                    Toggle.Text = "TELEPORTE • OFF"
                end
            end)

            return
        end

        if not GetNPCTorso() then
            Toggle.Text = "NPC NÃO ENCONTRADO"

            task.delay(1.5, function()
                if Alive and not State.Teleport then
                    Toggle.Text = "TELEPORTE • OFF"
                end
            end)

            if RefreshHub then
                RefreshHub()
            end

            return
        end

        State.Teleport = true
        AttackFails = 0
        Grace(0.8)

        -- Protege do void enquanto segue o NPC para fora do mapa
        VoidShield.Add("npc")

        Toggle.Text = "TELEPORTE • ON"
        Toggle.BackgroundColor3 = ON_COLOR

        Release()

        HoldConns[1] = RunService.Heartbeat:Connect(SafeHold)

        HoldConns[2] = RunService.Stepped:Connect(function()
            if FORCE_LEVELS[ForceIndex].Multi then
                SafeHold()
            end
        end)

        HoldConns[3] = RunService.RenderStepped:Connect(function()
            if FORCE_LEVELS[ForceIndex].Multi then
                SafeHold()
            end
        end)

        for _, Conn in ipairs(HoldConns) do
            Track(Conn)
        end

        StartAttackLoop()

        if RefreshHub then
            RefreshHub()
        end
    end

    Toggle.Activated:Connect(function()
        if State.Teleport then
            Stop(true)
        else
            Start()
        end
    end)

    AtkToggle.Activated:Connect(function()
        AttackOn = not AttackOn

        AtkToggle.Text = AttackOn and "ATAQUE AUTOMÁTICO • ON" or "ATAQUE AUTOMÁTICO • OFF"
        AtkToggle.BackgroundColor3 = AttackOn and ON_COLOR or OFF_COLOR
    end)

    PosButton.Activated:Connect(function()
        PosIndex = (PosIndex % #POSITIONS) + 1
        PosButton.Text = "POSIÇÃO • " .. POSITIONS[PosIndex].Name
    end)

    ForceButton.Activated:Connect(function()
        ForceIndex = (ForceIndex % #FORCE_LEVELS) + 1
        ForceButton.Text = "FORÇA • " .. FORCE_LEVELS[ForceIndex].Name

        if not FORCE_LEVELS[ForceIndex].Anchor then
            pcall(function()
                local HRP = GetHRP()

                if HRP then
                    HRP.Anchored = false
                end
            end)
        end
    end)

    -- Morreu enquanto preso: avisa (o personagem novo volta ao NPC sozinho)
    local function WatchDeath(Character)
        local Humanoid = Character:WaitForChild("Humanoid", 5)

        if not Humanoid then
            return
        end

        Track(Humanoid.Died:Connect(function()
            if State.Teleport and Alive then
                Say(
                    "☠ TELEPORTE NPC",
                    "Você morreu preso ao NPC. Vai renascer e voltar.",
                    YELLOW
                )
            end
        end))
    end

    Track(Player.CharacterAdded:Connect(function(Character)
        if State.Teleport then
            Grace(1.5)
        end

        WatchDeath(Character)
    end))

    if Player.Character then
        task.spawn(WatchDeath, Player.Character)
    end
end

--==================================================
-- DASH ASSIST + AIM ASSIST (FUNÇÕES)
-- O Aim Assist pausa sozinho enquanto o Shift Lock estiver ativo.
--==================================================

do
    local DashPage = Pages.DashAssist
    local AimPage = Pages.AimAssist

    local DashTargets = {}
    local AimTargets = {}

    local StrengthPct = 18
    local AimRange = 200
    local Prediction = 0.25
    local MaxDistance = 80
    local UpdateRate = 1 / 30
    local LastUpdate = 0
    local FAILURE_NAME = "Dash/Aim Assist"
    local PauseOnShift = true

    -- Shift Lock ativo? (câmera travada no centro / personagem seguindo a câmera)
    local function IsShiftLock()
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            return true
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid
            and not Humanoid.AutoRotate
            and math.abs(Humanoid.CameraOffset.X) > 0.4 then
            return true
        end

        return false
    end

    --------------------------------------------------
    -- DASH: INTERFACE
    --------------------------------------------------

    local DashCard = Card(
        DashPage,
        "DASH ASSIST",
        "Durante o dash, curva a direção para o jogador marcado mais próximo. Só age em velocidade alta."
    )
    DashCard.LayoutOrder = 1

    local DashToggle = Button(DashCard, "DASH ASSIST • OFF", 3)

    Caption(DashCard, "INTENSIDADE", 4)

    local StepRow = MakeRow(DashCard, 5)

    local Minus = Button(StepRow, "−", 1)
    Minus.Size = UDim2.fromOffset(46, 38)

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Parent = StepRow
    ValueLabel.LayoutOrder = 2
    ValueLabel.Size = UDim2.new(1, -(46 * 2 + 12), 1, 0)
    ValueLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
    ValueLabel.BackgroundTransparency = 0.15
    ValueLabel.BorderSizePixel = 0
    ValueLabel.Text = StrengthPct .. "%"
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextSize = 13
    ValueLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
    ValueLabel.ZIndex = 17

    local ValueCorner = Instance.new("UICorner")
    ValueCorner.CornerRadius = UDim.new(0, 8)
    ValueCorner.Parent = ValueLabel

    local Plus = Button(StepRow, "+", 3)
    Plus.Size = UDim2.fromOffset(46, 38)

    local function SetStrength(Value)
        StrengthPct = math.clamp(Value, 10, 40)
        ValueLabel.Text = StrengthPct .. "%"
    end

    Minus.Activated:Connect(function()
        SetStrength(StrengthPct - 2)
    end)

    Plus.Activated:Connect(function()
        SetStrength(StrengthPct + 2)
    end)

    CreatePlayerList(DashPage, "JOGADORES — DASH ASSIST", DashTargets, 2)

    --------------------------------------------------
    -- AIM: INTERFACE
    --------------------------------------------------

    local AimCard = Card(
        AimPage,
        "AIM ASSIST",
        "Vira o personagem para o alvo prevendo o movimento dele. Sem ninguém marcado, usa o jogador mais próximo. Pausa sozinho enquanto o Shift Lock estiver ativo e volta quando ele desligar."
    )
    AimCard.LayoutOrder = 1

    local AimToggle = Button(AimCard, "AIM ASSIST • OFF", 3)
    local ShiftToggle = Button(AimCard, "PAUSAR NO SHIFT LOCK • ON", 4)
    ShiftToggle.BackgroundColor3 = ON_COLOR

    local ShiftInfo = Caption(AimCard, "", 5)

    Caption(AimCard, "ALCANCE", 6)

    local RangeRow = MakeRow(AimCard, 7)
    local RangeButtons = {}

    for Index, Range in ipairs({100, 200, 300, 600}) do
        local B = Button(RangeRow, tostring(Range), Index)
        B.Size = UDim2.new(0.25, -5, 1, 0)
        B.BackgroundColor3 = Range == AimRange and SELECTED_COLOR or OFF_COLOR
        RangeButtons[Range] = B

        B.Activated:Connect(function()
            AimRange = Range

            for Value, Item in pairs(RangeButtons) do
                Item.BackgroundColor3 = Value == AimRange
                    and SELECTED_COLOR
                    or OFF_COLOR
            end
        end)
    end

    CreatePlayerList(AimPage, "JOGADORES — AIM ASSIST", AimTargets, 2)

    --------------------------------------------------
    -- TOGGLES
    --------------------------------------------------

    local function AfterToggle()
        if not State.Dash and not State.Aim then
            ClearFailure(FAILURE_NAME)
        end

        if RefreshHub then
            RefreshHub()
        end
    end

    DashToggle.Activated:Connect(function()
        State.Dash = not State.Dash
        DashToggle.Text = State.Dash and "DASH ASSIST • ON" or "DASH ASSIST • OFF"
        DashToggle.BackgroundColor3 = State.Dash and ON_COLOR or OFF_COLOR
        AfterToggle()
    end)

    AimToggle.Activated:Connect(function()
        State.Aim = not State.Aim
        AimToggle.Text = State.Aim and "AIM ASSIST • ON" or "AIM ASSIST • OFF"
        AimToggle.BackgroundColor3 = State.Aim and ON_COLOR or OFF_COLOR
        AfterToggle()
    end)

    ShiftToggle.Activated:Connect(function()
        PauseOnShift = not PauseOnShift

        ShiftToggle.Text = PauseOnShift
            and "PAUSAR NO SHIFT LOCK • ON"
            or "PAUSAR NO SHIFT LOCK • OFF"

        ShiftToggle.BackgroundColor3 = PauseOnShift and ON_COLOR or OFF_COLOR
    end)

    -- Atualiza o aviso do Shift Lock
    local ShiftAcc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive then
            return
        end

        ShiftAcc += dt

        if ShiftAcc < 0.25 then
            return
        end

        ShiftAcc = 0

        local Shift = IsShiftLock()
        Hooks.AimPaused = PauseOnShift and Shift

        if not PauseOnShift then
            ShiftInfo.Text = "● Shift Lock ignorado"
            ShiftInfo.TextColor3 = MUTED_TEXT
        elseif Shift then
            ShiftInfo.Text = "● Shift Lock ATIVO • Aim pausado"
            ShiftInfo.TextColor3 = YELLOW
        else
            ShiftInfo.Text = "● Shift Lock desligado • Aim livre"
            ShiftInfo.TextColor3 = GREEN
        end
    end))

    --------------------------------------------------
    -- LÓGICA
    --------------------------------------------------

    local function ClosestFromSet(Set, MyRoot)
        local Closest
        local Shortest = math.huge

        for Target in pairs(Set) do
            local Root = GetPlayerRoot(Target)

            if Root then
                local Distance = (Root.Position - MyRoot.Position).Magnitude

                if Distance < Shortest then
                    Shortest = Distance
                    Closest = Root
                end
            end
        end

        return Closest
    end

    local function ClosestAnyPlayer(MyRoot)
        local Closest
        local Shortest = MaxDistance

        for _, Other in ipairs(Players:GetPlayers()) do
            if Other ~= Player then
                local Root = GetPlayerRoot(Other)

                if Root then
                    local Distance = (Root.Position - MyRoot.Position).Magnitude

                    if Distance < Shortest then
                        Shortest = Distance
                        Closest = Root
                    end
                end
            end
        end

        return Closest
    end

    local function Step()
        local MyRoot = GetPlayerRoot(Player)

        if not MyRoot then
            return
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if not Humanoid then
            return
        end

        -- DASH
        if State.Dash then
            local Target = ClosestFromSet(DashTargets, MyRoot)

            if Target then
                local Velocity = MyRoot.AssemblyLinearVelocity
                local Horizontal = Vector3.new(Velocity.X, 0, Velocity.Z)
                local Speed = Horizontal.Magnitude

                if Speed > 45 then
                    local Offset = Vector3.new(
                        Target.Position.X - MyRoot.Position.X,
                        0,
                        Target.Position.Z - MyRoot.Position.Z
                    )

                    if Offset.Magnitude > 0.001 then
                        local Direction = Offset.Unit

                        if Horizontal.Magnitude > 0.001 then
                            Direction = Horizontal.Unit:Lerp(
                                Direction,
                                StrengthPct / 100
                            )
                        end

                        if Direction.Magnitude > 0.001 then
                            Direction = Direction.Unit

                            MyRoot.AssemblyLinearVelocity = Vector3.new(
                                Direction.X * Speed,
                                Velocity.Y,
                                Direction.Z * Speed
                            )
                        end
                    end
                end
            end
        end

        -- AIM: pausa enquanto o Shift Lock estiver ativo
        local ShiftOn = PauseOnShift and IsShiftLock()
        Hooks.AimPaused = ShiftOn

        if State.Aim and not ShiftOn and Humanoid.MoveDirection.Magnitude <= 0.99 then
            local Target = ClosestFromSet(AimTargets, MyRoot)

            if not Target then
                Target = ClosestAnyPlayer(MyRoot)
            end

            if Target then
                local Distance = (Target.Position - MyRoot.Position).Magnitude

                if Distance <= AimRange then
                    local Velocity = Target.AssemblyLinearVelocity

                    local Predicted = Vector3.new(
                        Target.Position.X + Velocity.X * Prediction,
                        Target.Position.Y,
                        Target.Position.Z + Velocity.Z * Prediction
                    )

                    local LookPosition = Vector3.new(
                        Predicted.X,
                        MyRoot.Position.Y,
                        Predicted.Z
                    )

                    if (LookPosition - MyRoot.Position).Magnitude > 0.001 then
                        MyRoot.CFrame = CFrame.lookAt(
                            MyRoot.Position,
                            LookPosition
                        )
                    end
                end
            end
        end
    end

    Track(RunService.RenderStepped:Connect(function()
        if not Alive or (not State.Dash and not State.Aim) then
            return
        end

        local Now = os.clock()

        if Now - LastUpdate < UpdateRate then
            return
        end

        LastUpdate = Now

        local Ok, Err = pcall(Step)

        if not Ok then
            SetFailure(FAILURE_NAME, tostring(Err))
        else
            ClearFailure(FAILURE_NAME)
        end
    end))
end

--==================================================
-- LISTAS DE JOGADORES: ENTRADA / SAÍDA / DISTÂNCIA
--==================================================

do
    for _, Other in ipairs(Players:GetPlayers()) do
        for _, List in ipairs(PlayerLists) do
            List.Add(Other)
        end
    end

    Track(Players.PlayerAdded:Connect(function(Other)
        for _, List in ipairs(PlayerLists) do
            List.Add(Other)
        end
    end))

    Track(Players.PlayerRemoving:Connect(function(Other)
        for _, List in ipairs(PlayerLists) do
            List.Remove(Other)
        end
    end))

    local Acc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive or not Main.Visible then
            return
        end

        Acc += dt

        if Acc < 0.5 then
            return
        end

        Acc = 0

        local HRP = GetHRP()
        local Position = HRP and HRP.Position

        for _, List in ipairs(PlayerLists) do
            List.UpdateDistances(Position)
        end
    end))
end

--==================================================
-- TROCA DE PÁGINA
--==================================================

local function SelectPage(Name)
    for PageName, Page in pairs(Pages) do
        Page.Visible = PageName == Name
    end

    for TabName, Tab in pairs(Tabs) do
        if TabName == Name then
            Tab.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
            Tab.TextColor3 = Color3.fromRGB(245, 245, 250)
        else
            Tab.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
            Tab.TextColor3 = Color3.fromRGB(190, 190, 200)
        end
    end
end

for Name, Tab in pairs(Tabs) do
    Tab.Activated:Connect(function()
        SelectPage(Name)
    end)
end

SelectPage("Status")

--==================================================
-- POSIÇÃO / ARRASTAR (PC + MOBILE)
--==================================================

local MainState = {Center = nil}
local OpenState = {Center = nil}
local FakeState = {Center = nil}
local RecState = {Center = nil}
local TPState = {Center = nil}

local function ScreenSize()
    return Gui.AbsoluteSize
end

local function ClampCenter(Center, Size, Margin)
    local V = ScreenSize()
    local Half = Size / 2

    return Vector2.new(
        math.clamp(
            Center.X,
            math.min(Half.X + Margin, V.X / 2),
            math.max(V.X - Half.X - Margin, V.X / 2)
        ),
        math.clamp(
            Center.Y,
            math.min(Half.Y + Margin, V.Y / 2),
            math.max(V.Y - Half.Y - Margin, V.Y / 2)
        )
    )
end

local function MakeDraggable(Handle, Target, StateTable, OnClick)
    local Dragging = false
    local Moved = false
    local ActiveInput
    local StartPoint
    local StartCenter

    Track(Handle.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1
            and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if Dragging then
            return
        end

        Dragging = true
        Moved = false
        ActiveInput = Input
        StartPoint = Vector2.new(Input.Position.X, Input.Position.Y)
        StartCenter = StateTable.Center
            or (Target.AbsolutePosition + Target.AbsoluteSize * Target.AnchorPoint)
    end))

    Track(UserInputService.InputChanged:Connect(function(Input)
        if not Dragging or not ActiveInput then
            return
        end

        local IsMove =
            (ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
                and Input.UserInputType == Enum.UserInputType.MouseMovement)
            or (ActiveInput.UserInputType == Enum.UserInputType.Touch
                and Input == ActiveInput)

        if not IsMove then
            return
        end

        local Delta =
            Vector2.new(Input.Position.X, Input.Position.Y) - StartPoint

        if not Moved and Delta.Magnitude < 8 then
            return
        end

        Moved = true

        local Center = ClampCenter(
            StartCenter + Delta,
            Target.AbsoluteSize,
            6
        )

        StateTable.Center = Center
        Target.Position = UDim2.fromOffset(Center.X, Center.Y)
    end))

    Track(UserInputService.InputEnded:Connect(function(Input)
        if not Dragging or not ActiveInput then
            return
        end

        local Ended =
            (ActiveInput.UserInputType == Enum.UserInputType.MouseButton1
                and Input.UserInputType == Enum.UserInputType.MouseButton1)
            or (ActiveInput.UserInputType == Enum.UserInputType.Touch
                and Input == ActiveInput)

        if not Ended then
            return
        end

        Dragging = false
        ActiveInput = nil

        if not Moved and OnClick then
            OnClick()
        end
    end))
end

MakeDraggable(Header, Main, MainState)

MakeDraggable(OpenButton, OpenButton, OpenState, function()
    Main.Visible = not Main.Visible
end)

Close.Activated:Connect(function()
    Main.Visible = false
end)

--==================================================
-- NOTIFICAÇÃO (AVISO NORMAL • 5 SEGUNDOS • SEM BOTÃO)
--==================================================

local Notifier = {}

do
    local TOP = 64
    local SIDE = 12
    local SHOW_TIME = 5
    local Token = 0
    local Shown = false
    local ToastWidth = 220

    local Toast = Instance.new("Frame")
    Toast.Name = "NotifyToast"
    Toast.Parent = Gui
    Toast.AnchorPoint = Vector2.new(1, 0)
    Toast.Size = UDim2.new(0, ToastWidth, 0, 0)
    Toast.AutomaticSize = Enum.AutomaticSize.Y
    Toast.Position = UDim2.fromOffset(600, TOP)
    Toast.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    Toast.BackgroundTransparency = 0.12
    Toast.BorderSizePixel = 0
    Toast.ClipsDescendants = true
    Toast.Visible = false
    Toast.Active = false
    Toast.Interactable = false
    Toast.ZIndex = 30

    local ToastCorner = Instance.new("UICorner")
    ToastCorner.CornerRadius = UDim.new(0, 14)
    ToastCorner.Parent = Toast

    local ToastStroke = Instance.new("UIStroke")
    ToastStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    ToastStroke.Color = YELLOW
    ToastStroke.Thickness = 1.5
    ToastStroke.Parent = Toast

    local ToastImage = Instance.new("ImageLabel")
    ToastImage.Parent = Toast
    ToastImage.Size = UDim2.fromScale(1, 1)
    ToastImage.BackgroundTransparency = 1
    ToastImage.Image = BG_IMAGE
    ToastImage.ImageTransparency = 0.8
    ToastImage.ScaleType = Enum.ScaleType.Crop
    ToastImage.Active = false
    ToastImage.Interactable = false
    ToastImage.ZIndex = 30

    local ToastBody = Instance.new("Frame")
    ToastBody.Parent = Toast
    ToastBody.Size = UDim2.new(1, 0, 0, 0)
    ToastBody.AutomaticSize = Enum.AutomaticSize.Y
    ToastBody.BackgroundTransparency = 1
    ToastBody.ZIndex = 31

    local ToastPad = Instance.new("UIPadding")
    ToastPad.PaddingTop = UDim.new(0, 9)
    ToastPad.PaddingBottom = UDim.new(0, 9)
    ToastPad.PaddingLeft = UDim.new(0, 12)
    ToastPad.PaddingRight = UDim.new(0, 12)
    ToastPad.Parent = ToastBody

    local ToastLayout = Instance.new("UIListLayout")
    ToastLayout.Padding = UDim.new(0, 3)
    ToastLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ToastLayout.Parent = ToastBody

    local ToastTitle = Instance.new("TextLabel")
    ToastTitle.Parent = ToastBody
    ToastTitle.LayoutOrder = 1
    ToastTitle.Size = UDim2.new(1, 0, 0, 15)
    ToastTitle.BackgroundTransparency = 1
    ToastTitle.Text = ""
    ToastTitle.Font = Enum.Font.GothamBold
    ToastTitle.TextSize = 12
    ToastTitle.TextColor3 = YELLOW
    ToastTitle.TextXAlignment = Enum.TextXAlignment.Left
    ToastTitle.ZIndex = 32

    local ToastText = Instance.new("TextLabel")
    ToastText.Parent = ToastBody
    ToastText.LayoutOrder = 2
    ToastText.Size = UDim2.new(1, 0, 0, 0)
    ToastText.AutomaticSize = Enum.AutomaticSize.Y
    ToastText.BackgroundTransparency = 1
    ToastText.Text = ""
    ToastText.Font = Enum.Font.Gotham
    ToastText.TextSize = 11
    ToastText.TextWrapped = true
    ToastText.TextColor3 = Color3.fromRGB(195, 195, 205)
    ToastText.TextXAlignment = Enum.TextXAlignment.Left
    ToastText.TextYAlignment = Enum.TextYAlignment.Top
    ToastText.ZIndex = 32

    local function ShownPosition()
        local V = ScreenSize()
        return UDim2.fromOffset(V.X - SIDE, TOP)
    end

    local function HiddenPosition()
        local V = ScreenSize()
        return UDim2.fromOffset(V.X + ToastWidth + 24, TOP)
    end

    function Notifier.Reposition()
        local V = ScreenSize()

        if V.X < 10 or V.Y < 10 then
            return
        end

        ToastWidth = math.clamp(V.X - 24, 150, 230)
        Toast.Size = UDim2.new(0, ToastWidth, 0, 0)

        if Shown then
            Toast.Position = ShownPosition()
        end
    end

    function Notifier.Show(TitleText, Text, Color)
        if not Alive then
            return
        end

        Token += 1
        local My = Token

        ToastTitle.Text = TitleText
        ToastTitle.TextColor3 = Color or YELLOW
        ToastStroke.Color = Color or YELLOW
        ToastText.Text = Text

        Notifier.Reposition()

        if not Shown then
            Toast.Position = HiddenPosition()
            Toast.Visible = true
            Shown = true
        end

        TweenService:Create(
            Toast,
            TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = ShownPosition()}
        ):Play()

        task.delay(SHOW_TIME, function()
            if not Alive or My ~= Token then
                return
            end

            local Out = TweenService:Create(
                Toast,
                TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                {Position = HiddenPosition()}
            )

            Out.Completed:Connect(function()
                if Alive and My == Token then
                    Toast.Visible = false
                    Shown = false
                end
            end)

            Out:Play()
        end)
    end
end

-- Gancho usado pelos módulos que ficam antes do Notifier no arquivo
Hooks.Notify = function(TitleText, Text, Color)
    if Alive then
        Notifier.Show(TitleText, Text, Color)
    end
end

--==================================================
-- FAKEOUT • BOTÃO REDONDO (MOBILE) + TECLA (PC)
--==================================================

local FakeButton

do
    local Page = Pages.Fakeout

    local FakeRunning = false
    local FakeKey = Enum.KeyCode.F
    local Capturing = false
    local ShowButton = UserInputService.TouchEnabled

    local FAKE_POINT = Vector3.new(0, -5000, 0)

    local TIME_OPTIONS = {1, 1.5, 2}
    local TimeIndex = 1
    local FallTime = TIME_OPTIONS[TimeIndex]
    local StealthFake = false

    local BUTTON_SIZE = 58
    local IDLE_COLOR = Color3.fromRGB(18, 18, 23)

    FakeButton = Instance.new("TextButton")
    FakeButton.Name = "FakeoutButton"
    FakeButton.Parent = Gui
    FakeButton.AnchorPoint = Vector2.new(0.5, 0.5)
    FakeButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
    FakeButton.Position = UDim2.fromOffset(100, 100)
    FakeButton.BackgroundColor3 = IDLE_COLOR
    FakeButton.BorderSizePixel = 0
    FakeButton.AutoButtonColor = false
    FakeButton.Text = "FAKE\nOUT"
    FakeButton.Font = Enum.Font.GothamBold
    FakeButton.TextSize = 11
    FakeButton.TextColor3 = Color3.fromRGB(245, 245, 250)
    FakeButton.Visible = false
    FakeButton.Active = true
    FakeButton.ZIndex = 20

    local FakeCorner = Instance.new("UICorner")
    FakeCorner.CornerRadius = UDim.new(1, 0)
    FakeCorner.Parent = FakeButton

    local FakeStroke = Instance.new("UIStroke")
    FakeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FakeStroke.Color = Color3.fromRGB(0, 170, 255)
    FakeStroke.Thickness = 2
    FakeStroke.Parent = FakeButton

    local Card1 = Card(
        Page,
        "FAKEOUT",
        "BETA • Teleporta você para fora do mapa (X 0, Y -5000, Z 0), fica lá pelo tempo escolhido e volta para o mesmo lugar onde estava. Você não morre no void. Ligado, aparece o botão redondo na tela (mobile) e a tecla escolhida funciona (PC)."
    )
    Card1.LayoutOrder = 1

    local FakeToggle = Button(Card1, "FAKEOUT • OFF", 3)

    local Card2 = Card(
        Page,
        "TECLA (PC)",
        "Toque no botão e aperte qualquer tecla. Esc cancela."
    )
    Card2.LayoutOrder = 2

    local KeyButton = Button(Card2, "TECLA • " .. FakeKey.Name, 3)

    local Card3 = Card(
        Page,
        "BOTÃO NA TELA",
        "Botão redondo e arrastável. Aparece quando o Fakeout está ligado e some quando desliga."
    )
    Card3.LayoutOrder = 3

    local ShowToggle = Button(
        Card3,
        ShowButton and "BOTÃO NA TELA • ON" or "BOTÃO NA TELA • OFF",
        3
    )
    ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

    local Card4 = Card(
        Page,
        "TEMPO FORA DO MAPA",
        "Quanto tempo fica fora do mapa antes de voltar."
    )
    Card4.LayoutOrder = 4

    local TimeButton = Button(Card4, "TEMPO • " .. FallTime .. "s", 3)
    local StyleButton = Button(Card4, "ESTILO FAKEOUT • FIXO", 4)

    local Card5, _, Info = Card(Page, "ESTADO", "● Desligado")
    Card5.LayoutOrder = 5
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local function SetInfo(Text, Color)
        Info.Text = Text
        Info.TextColor3 = Color
    end

    local function RestingInfo()
        if State.Fakeout then
            SetInfo("● Pronto (beta)", GREEN)
        else
            SetInfo("● Desligado", MUTED_TEXT)
        end
    end

    local function RefreshButton()
        if State.Fakeout and ShowButton then
            if not FakeState.Center then
                local V = ScreenSize()

                FakeState.Center = ClampCenter(
                    Vector2.new(V.X - 50, V.Y / 2 + 90),
                    Vector2.new(BUTTON_SIZE, BUTTON_SIZE),
                    6
                )

                FakeButton.Position = UDim2.fromOffset(
                    FakeState.Center.X,
                    FakeState.Center.Y
                )
            end

            FakeButton.Visible = true
        else
            FakeButton.Visible = false
        end
    end

    local function DoFakeout()
        if FakeRunning or not Alive or not State.Fakeout then
            return
        end

        local Blocker

        if State.Teleport then
            Blocker = "Desligue o Teleporte NPC primeiro"
        elseif State.Farm then
            Blocker = "Desligue o Autofarm primeiro"
        elseif State.Escaping then
            Blocker = "Aguarde a fuga terminar"
        end

        if Blocker then
            SetInfo("● " .. Blocker, RED)
            Say("⚠ CONFLITO", Blocker .. ".", YELLOW)

            task.delay(2, function()
                if Alive and not FakeRunning then
                    RestingInfo()
                end
            end)

            return
        end

        if State.RecRunning then
            return
        end

        local HRP = GetHRP()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if not HRP or not Humanoid or Humanoid.Health <= 0 then
            return
        end

        FakeRunning = true
        State.FakeRunning = true
        FakeButton.BackgroundColor3 = ON_COLOR
        FakeButton.Text = "..."
        SetInfo("● Executando...", YELLOW)

        local Original = HRP.CFrame
        local Duration = FallTime

        VoidShield.Add("fakeout")

        local Ok, Err = pcall(function()
            HRP.AssemblyLinearVelocity = Vector3.zero

            if StealthFake then
                -- FURTIVO: pula para um ponto aleatório diferente a cada frame,
                -- então um autofarm/loop-tp que lê a sua posição nunca acerta onde você está
                local Start = os.clock()

                while Alive and os.clock() - Start < Duration do
                    HRP = GetHRP() or HRP

                    local Angle = math.random() * math.pi * 2
                    local Dist = math.random(3000, 60000)

                    HRP.AssemblyLinearVelocity = Vector3.zero
                    HRP.CFrame = CFrame.new(
                        math.cos(Angle) * Dist,
                        math.random(-6000, 3000),
                        math.sin(Angle) * Dist
                    )

                    RunService.Heartbeat:Wait()
                end
            else
                HRP.CFrame = CFrame.new(FAKE_POINT)

                task.wait(Duration)
            end
        end)

        pcall(function()
            if HRP.Parent and Humanoid.Health > 0 then
                HRP.AssemblyLinearVelocity = Vector3.zero
                HRP.AssemblyAngularVelocity = Vector3.zero
                HRP.CFrame = Original
            end
        end)

        VoidShield.Remove("fakeout")
        Grace(0.8)

        if Ok then
            ClearFailure("Fakeout")
            FakeButton.Text = "FAKE\nOUT"
        else
            SetFailure("Fakeout", tostring(Err))
            FakeButton.Text = "ERRO"

            task.delay(1.5, function()
                if Alive and not FakeRunning then
                    FakeButton.Text = "FAKE\nOUT"
                end
            end)
        end

        FakeButton.BackgroundColor3 = IDLE_COLOR
        RestingInfo()

        task.wait(0.5)
        FakeRunning = false
        State.FakeRunning = false
    end

    MakeDraggable(FakeButton, FakeButton, FakeState, function()
        task.spawn(DoFakeout)
    end)

    FakeToggle.Activated:Connect(function()
        State.Fakeout = not State.Fakeout

        FakeToggle.Text = State.Fakeout and "FAKEOUT • ON" or "FAKEOUT • OFF"
        FakeToggle.BackgroundColor3 = State.Fakeout and ON_COLOR or OFF_COLOR

        if not State.Fakeout then
            ClearFailure("Fakeout")
        end

        if not FakeRunning then
            RestingInfo()
        end

        RefreshButton()

        if State.Fakeout then
            Notifier.Show(
                "⚠ FAKEOUT • BETA",
                "Ainda não está funcionando direito e pode falhar.",
                YELLOW
            )
        end

        if RefreshHub then
            RefreshHub()
        end
    end)

    KeyButton.Activated:Connect(function()
        Capturing = not Capturing
        KeyBusy.Active = Capturing

        KeyButton.Text = Capturing
            and "PRESSIONE UMA TECLA..."
            or ("TECLA • " .. FakeKey.Name)

        KeyButton.BackgroundColor3 = Capturing and SELECTED_COLOR or OFF_COLOR
    end)

    ShowToggle.Activated:Connect(function()
        ShowButton = not ShowButton

        ShowToggle.Text = ShowButton
            and "BOTÃO NA TELA • ON"
            or "BOTÃO NA TELA • OFF"

        ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

        RefreshButton()
    end)

    StyleButton.Activated:Connect(function()
        StealthFake = not StealthFake
        StyleButton.Text = "ESTILO FAKEOUT • " .. (StealthFake and "FURTIVO" or "FIXO")
    end)

    TimeButton.Activated:Connect(function()
        TimeIndex = (TimeIndex % #TIME_OPTIONS) + 1
        FallTime = TIME_OPTIONS[TimeIndex]
        TimeButton.Text = "TEMPO • " .. FallTime .. "s"
    end)

    Track(UserInputService.InputBegan:Connect(function(Input)
        if not Alive then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if Capturing then
            Capturing = false
            KeyBusy.Active = false
            KeyBusy.LastEnd = os.clock()

            if Input.KeyCode ~= Enum.KeyCode.Escape
                and Input.KeyCode ~= Enum.KeyCode.Unknown then
                FakeKey = Input.KeyCode
            end

            KeyButton.Text = "TECLA • " .. FakeKey.Name
            KeyButton.BackgroundColor3 = OFF_COLOR

            return
        end

        if KeyBusy.Active or os.clock() - KeyBusy.LastEnd < 0.3 then
            return
        end

        if State.Fakeout
            and Input.KeyCode == FakeKey
            and not UserInputService:GetFocusedTextBox() then

            task.spawn(DoFakeout)
        end
    end))
end

--==================================================
-- ANTI-FLING (NA ABA FAKEOUT)
--==================================================

do
    local Page = Pages.Fakeout

    local LEVELS = {
        {Name = "NORMAL", Linear = 800, Angular = 120},
        {Name = "FORTE", Linear = 500, Angular = 80},
        {Name = "MÁXIMO", Linear = 300, Angular = 50},
    }

    local LevelIndex = 2
    local Level = LEVELS[LevelIndex]

    local RESTORE_DIST = 12
    local LOCK_TIME = 0.6
    local NOTIFY_GAP = 6

    local LastSafe = nil
    local FlungUntil = 0
    local LastNotify = 0
    local Blocked = 0
    local OthersParts = {}
    local Changed = setmetatable({}, {__mode = "k"})
    local ListAcc = 0

    local FlingCard = Card(
        Page,
        "ANTI-FLING",
        "Impede que outros jogadores (ou scripts) te arremessem para fora do mapa. Ligado, você não colide fisicamente com o corpo dos outros jogadores."
    )
    FlingCard.LayoutOrder = 6

    local FlingToggle = Button(FlingCard, "ANTI-FLING • OFF", 3)

    local LevelCard = Card(
        Page,
        "NÍVEL DO ANTI-FLING",
        "NORMAL: 800 studs/s. FORTE: 500. MÁXIMO: 300 (mais sensível, mas pode cortar um golpe forte)."
    )
    LevelCard.LayoutOrder = 7

    local LevelButton = Button(LevelCard, "", 3)

    local InfoCard, _, Info = Card(Page, "ESTADO DO ANTI-FLING", "● Desligado")
    InfoCard.LayoutOrder = 8
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local function RefreshInfo()
        if not State.AntiFling then
            Info.Text = "● Desligado"
            Info.TextColor3 = MUTED_TEXT
        else
            Info.Text = "● Protegendo • " .. Blocked
                .. (Blocked == 1 and " bloqueio" or " bloqueios")
            Info.TextColor3 = GREEN
        end
    end

    local function RefreshLevelText()
        LevelButton.Text = "NÍVEL • " .. Level.Name .. " (" .. Level.Linear .. " studs/s)"
    end

    RefreshLevelText()

    local function RefreshParts()
        table.clear(OthersParts)

        for _, Other in ipairs(Players:GetPlayers()) do
            if Other ~= Player and Other.Character then
                for _, Part in ipairs(Other.Character:GetDescendants()) do
                    if Part:IsA("BasePart") then
                        table.insert(OthersParts, Part)
                    end
                end
            end
        end
    end

    local function ApplyNoCollide()
        for Index = 1, #OthersParts do
            local Part = OthersParts[Index]

            if Part.Parent and Part.CanCollide then
                Part.CanCollide = false
                Changed[Part] = true
            end
        end
    end

    local function RestoreCollisions()
        for Part in pairs(Changed) do
            if Part.Parent then
                Part.CanCollide = true
            end

            Changed[Part] = nil
        end
    end

    Hooks.FlingRestore = RestoreCollisions

    local function Guard()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local HRP = Character and Character:FindFirstChild("HumanoidRootPart")

        if not Humanoid or not HRP or Humanoid.Health <= 0 then
            LastSafe = nil
            return
        end

        local Busy = State.FakeRunning
            or State.RecRunning
            or State.AntiRunning
            or State.Teleport
            or State.Farm
            or State.Escaping
            or InGrace()

        if Busy then
            LastSafe = HRP.CFrame
            return
        end

        local Velocity = HRP.AssemblyLinearVelocity

        local Fling = Vector3.new(Velocity.X, math.max(Velocity.Y, 0), Velocity.Z).Magnitude
        local Spin = HRP.AssemblyAngularVelocity.Magnitude
        local Now = os.clock()

        if Fling ~= Fling
            or Spin ~= Spin
            or Fling > Level.Linear
            or Spin > Level.Angular then

            HRP.AssemblyLinearVelocity = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
            FlungUntil = Now + LOCK_TIME

            Blocked += 1
            Hooks.FlingBlocked = Blocked

            if LastSafe and (HRP.Position - LastSafe.Position).Magnitude > RESTORE_DIST then
                HRP.CFrame = LastSafe
            end

            pcall(function()
                local HState = Humanoid:GetState()

                if HState == Enum.HumanoidStateType.FallingDown
                    or HState == Enum.HumanoidStateType.Ragdoll
                    or HState == Enum.HumanoidStateType.Physics then

                    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)

            RefreshInfo()

            if Now - LastNotify >= NOTIFY_GAP then
                LastNotify = Now

                Notifier.Show(
                    "🛡 ANTI-FLING",
                    "Arremesso bloqueado.",
                    GREEN
                )
            end
        elseif Now >= FlungUntil then
            LastSafe = HRP.CFrame
        end
    end

    local function SafeRun(Fn)
        local Ok, Err = pcall(Fn)

        if not Ok then
            SetFailure("Anti-Fling", tostring(Err))
        end
    end

    Track(RunService.Stepped:Connect(function()
        if not Alive or not State.AntiFling then
            return
        end

        SafeRun(function()
            ApplyNoCollide()
            Guard()
        end)
    end))

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive or not State.AntiFling then
            return
        end

        ListAcc += dt

        if ListAcc >= 0.5 then
            ListAcc = 0
            SafeRun(RefreshParts)
        end

        SafeRun(Guard)
    end))

    FlingToggle.Activated:Connect(function()
        State.AntiFling = not State.AntiFling

        FlingToggle.Text = State.AntiFling and "ANTI-FLING • ON" or "ANTI-FLING • OFF"
        FlingToggle.BackgroundColor3 = State.AntiFling and ON_COLOR or OFF_COLOR

        if State.AntiFling then
            LastSafe = nil
            ListAcc = 0
            SafeRun(RefreshParts)
        else
            RestoreCollisions()
            table.clear(OthersParts)
            ClearFailure("Anti-Fling")
        end

        RefreshInfo()

        if RefreshHub then
            RefreshHub()
        end
    end)

    LevelButton.Activated:Connect(function()
        LevelIndex = (LevelIndex % #LEVELS) + 1
        Level = LEVELS[LevelIndex]
        RefreshLevelText()
    end)
end

--==================================================
-- TP JOGADOR (ABA TP JOGADOR)
-- Escolha o jogador na lista; a tecla (PC) ou o botão redondo (mobile)
-- te leva para trás dele.
--==================================================

local TPButton

do
    local Page = Pages.PlayerTP

    local Selected = {}
    local TPKey = Enum.KeyCode.T
    local Capturing = false
    local ShowButton = UserInputService.TouchEnabled

    local BEHIND_OPTIONS = {2, 3, 5}
    local BehindIndex = 2
    local Behind = BEHIND_OPTIONS[BehindIndex]
    local MAX_BELOW = 100
    local BUTTON_SIZE = 58
    local IDLE_COLOR = Color3.fromRGB(18, 18, 23)

    TPButton = Instance.new("TextButton")
    TPButton.Name = "PlayerTPButton"
    TPButton.Parent = Gui
    TPButton.AnchorPoint = Vector2.new(0.5, 0.5)
    TPButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
    TPButton.Position = UDim2.fromOffset(100, 260)
    TPButton.BackgroundColor3 = IDLE_COLOR
    TPButton.BorderSizePixel = 0
    TPButton.AutoButtonColor = false
    TPButton.Text = "TP"
    TPButton.Font = Enum.Font.GothamBold
    TPButton.TextSize = 14
    TPButton.TextColor3 = Color3.fromRGB(245, 245, 250)
    TPButton.Visible = false
    TPButton.Active = true
    TPButton.ZIndex = 20

    local TPCorner = Instance.new("UICorner")
    TPCorner.CornerRadius = UDim.new(1, 0)
    TPCorner.Parent = TPButton

    local TPStroke = Instance.new("UIStroke")
    TPStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    TPStroke.Color = YELLOW
    TPStroke.Thickness = 2
    TPStroke.Parent = TPButton

    local TPCard = Card(
        Page,
        "TELEPORTE ATRÁS DO JOGADOR",
        "Escolha um jogador na lista. Depois aperte a tecla escolhida (PC) ou o botão redondo na tela (mobile) para ir para trás dele."
    )
    TPCard.LayoutOrder = 1

    local TPToggle = Button(TPCard, "TP ATRÁS • OFF", 3)
    local GoNow = Button(TPCard, "IR AGORA PARA O ALVO", 4)
    local BehindButton = Button(TPCard, "DISTÂNCIA ATRÁS • " .. Behind .. " studs", 5)

    local KeyCard = Card(
        Page,
        "TECLA (PC)",
        "Toque no botão e aperte qualquer tecla. Esc cancela."
    )
    KeyCard.LayoutOrder = 2

    local KeyButton = Button(KeyCard, "TECLA • " .. TPKey.Name, 3)

    local ScreenCard = Card(
        Page,
        "BOTÃO NA TELA",
        "Botão redondo e arrastável. Aparece quando o TP ATRÁS está ligado e some quando desliga."
    )
    ScreenCard.LayoutOrder = 3

    local ShowToggle = Button(
        ScreenCard,
        ShowButton and "BOTÃO NA TELA • ON" or "BOTÃO NA TELA • OFF",
        3
    )
    ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

    local InfoCard, _, Info = Card(Page, "ESTADO", "● Desligado")
    InfoCard.LayoutOrder = 4
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local function SelectedPlayer()
        for Chosen in pairs(Selected) do
            return Chosen
        end

        return nil
    end

    local function SetInfo(Text, Color)
        Info.Text = Text
        Info.TextColor3 = Color
    end

    local FlashToken = 0

    local function RestingInfo()
        local Chosen = SelectedPlayer()

        if not State.PlayerTP then
            SetInfo("● Desligado", MUTED_TEXT)
        elseif Chosen then
            SetInfo("● Pronto • alvo: " .. Chosen.DisplayName, GREEN)
        else
            SetInfo("● Escolha um jogador na lista", YELLOW)
        end
    end

    local function Flash(Text, Color)
        FlashToken += 1
        local My = FlashToken

        SetInfo(Text, Color)

        task.delay(2.5, function()
            if Alive and My == FlashToken then
                RestingInfo()
            end
        end)
    end

    local function RefreshButton()
        if State.PlayerTP and ShowButton then
            if not TPState.Center then
                local V = ScreenSize()

                TPState.Center = ClampCenter(
                    Vector2.new(V.X - 120, V.Y / 2 + 90),
                    Vector2.new(BUTTON_SIZE, BUTTON_SIZE),
                    6
                )

                TPButton.Position = UDim2.fromOffset(
                    TPState.Center.X,
                    TPState.Center.Y
                )
            end

            TPButton.Visible = true
        else
            TPButton.Visible = false
        end
    end

    local function GoToSelected()
        if not Alive then
            return
        end

        if not State.PlayerTP then
            Flash("● Ligue o TP ATRÁS primeiro", YELLOW)
            return
        end

        local Target = SelectedPlayer()

        if not Target then
            Flash("● Escolha um jogador na lista", YELLOW)
            return
        end

        if State.Teleport then
            Flash("● Desligue o Teleporte NPC primeiro", RED) Say("⚠ CONFLITO", "Desligue o Teleporte NPC primeiro.", YELLOW)
            return
        end

        if State.Farm then
            Flash("● Desligue o Autofarm primeiro", RED) Say("⚠ CONFLITO", "Desligue o Autofarm primeiro.", YELLOW)
            return
        end

        if State.FakeRunning or State.RecRunning or State.AntiRunning or State.Escaping then
            Flash("● Aguarde a outra função terminar", RED) Say("⚠ CONFLITO", "Aguarde a outra função terminar.", YELLOW)
            return
        end

        local MyRoot = GetPlayerRoot(Player)

        if not MyRoot then
            Flash("● Você está sem personagem", RED)
            return
        end

        local TargetRoot = GetPlayerRoot(Target)

        if not TargetRoot then
            Flash("● " .. Target.DisplayName .. " sem personagem", RED)
            return
        end

        local TopY = GetPlatformTopY()
        if TopY and TargetRoot.Position.Y < TopY - MAX_BELOW then
            Flash("● " .. Target.DisplayName .. " está fora do mapa", RED)
            return
        end

        -- Salto grande: Anti-Fakeout / Auto-Reset / Esquiva não podem reagir
        Grace(1.2)
        State.DodgePause = os.clock() + 3

        MyRoot.AssemblyLinearVelocity = Vector3.zero
        MyRoot.AssemblyAngularVelocity = Vector3.zero
        MyRoot.CFrame = Combat.BehindCFrame(TargetRoot, Behind, 0.05)

        Flash("● Atrás de " .. Target.DisplayName, GREEN)
    end

    -- Lista de escolha única: o jogador marcado é o alvo da tecla / botão
    local List = CreatePlayerList(
        Page,
        "ESCOLHA O JOGADOR",
        Selected,
        5,
        true,
        function()
            FlashToken += 1
            RestingInfo()
        end
    )

    for _, Other in ipairs(Players:GetPlayers()) do
        List.Add(Other)
    end

    MakeDraggable(TPButton, TPButton, TPState, function()
        task.spawn(GoToSelected)
    end)

    TPToggle.Activated:Connect(function()
        State.PlayerTP = not State.PlayerTP

        TPToggle.Text = State.PlayerTP and "TP ATRÁS • ON" or "TP ATRÁS • OFF"
        TPToggle.BackgroundColor3 = State.PlayerTP and ON_COLOR or OFF_COLOR

        FlashToken += 1
        RestingInfo()
        RefreshButton()

        if RefreshHub then
            RefreshHub()
        end
    end)

    GoNow.Activated:Connect(function()
        task.spawn(GoToSelected)
    end)

    BehindButton.Activated:Connect(function()
        BehindIndex = (BehindIndex % #BEHIND_OPTIONS) + 1
        Behind = BEHIND_OPTIONS[BehindIndex]
        BehindButton.Text = "DISTÂNCIA ATRÁS • " .. Behind .. " studs"
    end)

    KeyButton.Activated:Connect(function()
        Capturing = not Capturing
        KeyBusy.Active = Capturing

        KeyButton.Text = Capturing
            and "PRESSIONE UMA TECLA..."
            or ("TECLA • " .. TPKey.Name)

        KeyButton.BackgroundColor3 = Capturing and SELECTED_COLOR or OFF_COLOR
    end)

    ShowToggle.Activated:Connect(function()
        ShowButton = not ShowButton

        ShowToggle.Text = ShowButton
            and "BOTÃO NA TELA • ON"
            or "BOTÃO NA TELA • OFF"

        ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

        RefreshButton()
    end)

    Track(UserInputService.InputBegan:Connect(function(Input)
        if not Alive then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if Capturing then
            Capturing = false
            KeyBusy.Active = false
            KeyBusy.LastEnd = os.clock()

            if Input.KeyCode ~= Enum.KeyCode.Escape
                and Input.KeyCode ~= Enum.KeyCode.Unknown then
                TPKey = Input.KeyCode
            end

            KeyButton.Text = "TECLA • " .. TPKey.Name
            KeyButton.BackgroundColor3 = OFF_COLOR

            return
        end

        if KeyBusy.Active or os.clock() - KeyBusy.LastEnd < 0.3 then
            return
        end

        if State.PlayerTP
            and Input.KeyCode == TPKey
            and not UserInputService:GetFocusedTextBox() then

            task.spawn(GoToSelected)
        end
    end))

    RestingInfo()
end

--==================================================
-- AUTO-ESQUIVA (NA ABA TELEPORTE NPC)
-- Jogador chegou perto: recua na hora.
--==================================================

do
    local Page = Pages.NPCTeleport

    local DODGE_DISTANCE = 8
    local BACK_DISTANCE = 5
    local INTERVAL = 0.25
    local LastDodge = 0

    local DodgeCard = Card(
        Page,
        "AUTO-ESQUIVA",
        "Quando um jogador chega a menos de 8 studs, você recua 5 studs na hora (no máximo a cada 0,25 s), na direção contrária a ele. Não age durante o Teleporte NPC, Autofarm, Fakeout, Fuga, Recuperar nem Anti-Fakeout."
    )
    DodgeCard.LayoutOrder = 5

    local DodgeToggle = Button(DodgeCard, "AUTO-ESQUIVA • OFF", 3)

    DodgeToggle.Activated:Connect(function()
        State.Dodge = not State.Dodge

        DodgeToggle.Text = State.Dodge and "AUTO-ESQUIVA • ON" or "AUTO-ESQUIVA • OFF"
        DodgeToggle.BackgroundColor3 = State.Dodge and ON_COLOR or OFF_COLOR

        LastDodge = 0

        if RefreshHub then
            RefreshHub()
        end
    end)

    Track(RunService.Heartbeat:Connect(function()
        if not Alive or not State.Dodge then
            return
        end

        if State.Teleport
            or State.Farm
            or State.FakeRunning
            or State.RecRunning
            or State.AntiRunning
            or State.Escaping
            or InGrace() then
            return
        end

        local Now = os.clock()

        if Now < State.DodgePause or Now - LastDodge < INTERVAL then
            return
        end

        local MyRoot = GetPlayerRoot(Player)

        if not MyRoot then
            return
        end

        local Nearest
        local NearestDistance = DODGE_DISTANCE

        for _, Other in ipairs(Players:GetPlayers()) do
            if Other ~= Player then
                local Root = GetPlayerRoot(Other)

                if Root then
                    local Distance = (MyRoot.Position - Root.Position).Magnitude

                    if Distance < NearestDistance then
                        NearestDistance = Distance
                        Nearest = Root
                    end
                end
            end
        end

        if not Nearest then
            return
        end

        local Away = Vector3.new(
            MyRoot.Position.X - Nearest.Position.X,
            0,
            MyRoot.Position.Z - Nearest.Position.Z
        )

        if Away.Magnitude < 0.05 then
            local Back = -MyRoot.CFrame.LookVector
            Away = Vector3.new(Back.X, 0, Back.Z)
        end

        if Away.Magnitude < 0.001 then
            return
        end

        LastDodge = Now

        local Ok, Err = pcall(function()
            MyRoot.CFrame = MyRoot.CFrame + Away.Unit * BACK_DISTANCE
        end)

        if not Ok then
            SetFailure("Auto-Esquiva", tostring(Err))
        end
    end))
end

--==================================================
-- RESPAWN NO SPAWN (NA ABA TELEPORTE NPC)
--==================================================

do
    local Page = Pages.NPCTeleport
    local WAIT_RESPAWN = 12

    local RespCard = Card(
        Page,
        "RESPAWN NO SPAWN",
        "Toque para resetar o personagem. Ao renascer, você é levado para cima do SpawnLocation do mapa. Com o Teleporte NPC ligado não funciona (ele te prenderia de volta)."
    )
    RespCard.LayoutOrder = 6

    local RespButton = Button(RespCard, "RESETAR E IR AO SPAWN", 3)
    local RespInfo = Caption(RespCard, "", 4)

    local Busy = false
    local FlashToken = 0

    local function SetInfo(Text, Color)
        RespInfo.Text = Text
        RespInfo.TextColor3 = Color
    end

    local function Flash(Text, Color)
        FlashToken += 1
        local My = FlashToken

        SetInfo(Text, Color)

        task.delay(3, function()
            if Alive and My == FlashToken and not Busy then
                SetInfo("", MUTED_TEXT)
            end
        end)
    end

    local function ResetLook()
        RespButton.Text = "RESETAR E IR AO SPAWN"
        RespButton.BackgroundColor3 = OFF_COLOR
    end

    local function DoRespawn()
        if Busy or not Alive then
            return
        end

        if State.Teleport then
            Flash("● Desligue o Teleporte NPC primeiro", RED) Say("⚠ CONFLITO", "Desligue o Teleporte NPC primeiro.", YELLOW)
            return
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if not Humanoid or Humanoid.Health <= 0 then
            Flash("● Sem personagem vivo", RED)
            return
        end

        Busy = true
        RespButton.Text = "RESETANDO..."
        RespButton.BackgroundColor3 = SELECTED_COLOR
        SetInfo("● Resetando...", YELLOW)
        Grace(1)

        local NewCharacter = nil

        local Conn = Player.CharacterAdded:Connect(function(Created)
            NewCharacter = Created
        end)

        local Ok, Err = pcall(function()
            Humanoid.Health = 0
        end)

        if not Ok then
            Conn:Disconnect()
            Busy = false
            ResetLook()
            SetFailure("Respawn", tostring(Err))
            SetInfo("● Falhou ao resetar", RED)
            return
        end

        local Start = os.clock()

        while Alive and not NewCharacter and os.clock() - Start < WAIT_RESPAWN do
            local Elapsed = os.clock() - Start

            Grace(0.6)

            if Elapsed > 1 and Humanoid.Parent and Humanoid.Health > 0 then
                pcall(function()
                    Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
                end)
            end

            if Elapsed > 2 and Character.Parent and Humanoid.Health > 0 then
                pcall(function()
                    Character:BreakJoints()
                end)
            end

            task.wait(0.1)
        end

        Conn:Disconnect()

        if not Alive then
            return
        end

        if not NewCharacter then
            Busy = false
            ResetLook()
            SetFailure("Respawn", "não renasceu")
            SetInfo("● Não renasceu", RED)
            return
        end

        local Root = NewCharacter:WaitForChild("HumanoidRootPart", 10)
        local SpawnPoint = workspace:FindFirstChildWhichIsA("SpawnLocation", true)

        Grace(2)

        if Root and SpawnPoint then
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
            Root.CFrame = SpawnPoint.CFrame * CFrame.new(0, SpawnPoint.Size.Y / 2 + 3, 0)
            ClearFailure("Respawn")
            SetInfo("● No spawn", GREEN)
        elseif Root then
            ClearFailure("Respawn")
            SetInfo("● Sem SpawnLocation no mapa", YELLOW)
        else
            SetFailure("Respawn", "sem corpo")
            SetInfo("● Personagem sem corpo", RED)
        end

        Busy = false
        ResetLook()

        task.delay(3, function()
            if Alive and not Busy then
                SetInfo("", MUTED_TEXT)
            end
        end)
    end

    RespButton.Activated:Connect(function()
        task.spawn(DoRespawn)
    end)
end

--==================================================
-- RECUPERAR VOID (MANUAL + AUTOMÁTICO) + PISO SEGURO
--
-- • Manual: botão redondo na tela (mobile) / tecla (PC).
-- • Automático: se você cair abaixo da plataforma, volta sozinho.
-- • Piso Seguro: enquanto o Hub te teleporta (NPC, Fakeout, Fuga,
--   Autofarm), nunca deixa você ficar abaixo da altura onde o
--   servidor destrói peças (FallenPartsDestroyHeight + margem).
--==================================================

local RecoverButton

do
    local Page = Pages.VoidRecover

    local RecKey = Enum.KeyCode.R
    local Capturing = false
    local ShowButton = UserInputService.TouchEnabled

    local DROP_OPTIONS = {40, 80, 150}
    local DropIndex = 2
    local Drop = DROP_OPTIONS[DropIndex]

    local FLOOR_MARGIN = 40
    local GuardOn = true
    local GuardHits = 0

    local BUTTON_SIZE = 58
    local IDLE_COLOR = Color3.fromRGB(18, 18, 23)

    local Running = false
    local LastSafePos = nil
    local LastRun = 0
    local Recovered = 0
    local FlashToken = 0

    --------------------------------------------------
    -- BOTÃO REDONDO
    --------------------------------------------------

    RecoverButton = Instance.new("TextButton")
    RecoverButton.Name = "RecoverButton"
    RecoverButton.Parent = Gui
    RecoverButton.AnchorPoint = Vector2.new(0.5, 0.5)
    RecoverButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
    RecoverButton.Position = UDim2.fromOffset(100, 420)
    RecoverButton.BackgroundColor3 = IDLE_COLOR
    RecoverButton.BorderSizePixel = 0
    RecoverButton.AutoButtonColor = false
    RecoverButton.Text = "VOLTAR"
    RecoverButton.Font = Enum.Font.GothamBold
    RecoverButton.TextSize = 11
    RecoverButton.TextColor3 = Color3.fromRGB(245, 245, 250)
    RecoverButton.Visible = false
    RecoverButton.Active = true
    RecoverButton.ZIndex = 20

    local RecCorner = Instance.new("UICorner")
    RecCorner.CornerRadius = UDim.new(1, 0)
    RecCorner.Parent = RecoverButton

    local RecStroke = Instance.new("UIStroke")
    RecStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    RecStroke.Color = GREEN
    RecStroke.Thickness = 2
    RecStroke.Parent = RecoverButton

    --------------------------------------------------
    -- INTERFACE
    --------------------------------------------------

    local ManualCard = Card(
        Page,
        "RECUPERAR VOID • MANUAL",
        "Te leva de volta para cima da plataforma (ou do último lugar seguro). Ligado, aparece o botão redondo (mobile) e a tecla escolhida funciona (PC)."
    )
    ManualCard.LayoutOrder = 1

    local ManualToggle = Button(ManualCard, "MANUAL • OFF", 3)
    local RecNow = Button(ManualCard, "VOLTAR AGORA", 4)

    local KeyCard = Card(Page, "TECLA (PC)", "Toque no botão e aperte qualquer tecla. Esc cancela.")
    KeyCard.LayoutOrder = 2

    local KeyButton = Button(KeyCard, "TECLA • " .. RecKey.Name, 3)

    local ScreenCard = Card(
        Page,
        "BOTÃO NA TELA",
        "Botão redondo e arrastável. Aparece quando o modo manual está ligado."
    )
    ScreenCard.LayoutOrder = 3

    local ShowToggle = Button(
        ScreenCard,
        ShowButton and "BOTÃO NA TELA • ON" or "BOTÃO NA TELA • OFF",
        3
    )
    ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

    local AutoCard = Card(
        Page,
        "AUTO-RECUPERAR",
        "Vigia sua altura. Se você cair abaixo do limite escolhido (contado a partir da plataforma), volta sozinho. Também assume quando o Anti-Fakeout falha. Não age durante Teleporte NPC, Autofarm, Fakeout ou Fuga."
    )
    AutoCard.LayoutOrder = 4

    local AutoToggle = Button(AutoCard, "AUTO-RECUPERAR • OFF", 3)
    local DropButton = Button(AutoCard, "LIMITE ABAIXO DA PLATAFORMA • " .. Drop .. " studs", 4)

    local GuardCard = Card(
        Page,
        "PISO SEGURO (ANTI-MORTE NO VOID)",
        "O servidor destrói peças abaixo da sua FallenPartsDestroyHeight, e mudar isso só no seu cliente nem sempre funciona. Com o Piso Seguro ligado, durante Teleporte NPC / Fakeout / Fuga / Autofarm o Hub impede que você fique abaixo dessa altura + 40 studs. Desligado, só o escudo local é usado (pode morrer se o servidor não aceitar)."
    )
    GuardCard.LayoutOrder = 5

    local GuardToggle = Button(GuardCard, "PISO SEGURO • ON", 3)
    GuardToggle.BackgroundColor3 = ON_COLOR
    local GuardInfo = Caption(GuardCard, "", 4)

    local InfoCard, _, Info = Card(Page, "ESTADO", "● Desligado")
    InfoCard.LayoutOrder = 7
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local function SetInfo(Text, Color)
        Info.Text = Text
        Info.TextColor3 = Color
    end

    local function RestingInfo()
        if State.AutoRec or State.VoidRec then
            SetInfo(
                "● Vigiando • " .. Recovered
                    .. (Recovered == 1 and " recuperação" or " recuperações"),
                GREEN
            )
        else
            SetInfo("● Desligado", MUTED_TEXT)
        end
    end

    local function Flash(Text, Color)
        FlashToken += 1
        local My = FlashToken

        SetInfo(Text, Color)

        task.delay(2.5, function()
            if Alive and My == FlashToken and not Running then
                RestingInfo()
            end
        end)
    end

    local function RefreshButton()
        if State.VoidRec and ShowButton then
            if not RecState.Center then
                local V = ScreenSize()

                RecState.Center = ClampCenter(
                    Vector2.new(V.X - 50, V.Y / 2 + 170),
                    Vector2.new(BUTTON_SIZE, BUTTON_SIZE),
                    6
                )

                RecoverButton.Position = UDim2.fromOffset(
                    RecState.Center.X,
                    RecState.Center.Y
                )
            end

            RecoverButton.Visible = true
        else
            RecoverButton.Visible = false
        end
    end

    --------------------------------------------------
    -- ALTURA DO VOID / PISO
    --------------------------------------------------

    local function RealHeight()
        local H = VoidShield.Original

        if H == nil then
            H = workspace.FallenPartsDestroyHeight
        end

        -- Valor já alterado por escudo antigo: volta ao padrão do Roblox
        if H < -5000 then
            H = -500
        end

        return H
    end

    local function GoSafe()
        local Went = ReturnToPlatform(LastSafePos)

        if Went then
            return true
        end

        local Spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        local HRP = GetHRP()

        if Spawn and HRP then
            HRP.AssemblyLinearVelocity = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
            HRP.CFrame = Spawn.CFrame * CFrame.new(0, Spawn.Size.Y / 2 + 3, 0)
            Grace(0.8)
            return true
        end

        return false
    end

    --------------------------------------------------
    -- RECUPERAR
    --------------------------------------------------

    local function DoRecover(Reason, Manual)
        if Running or not Alive then
            return
        end

        if State.FakeRunning or State.Escaping or State.AntiRunning then
            if Manual then
                Flash("● Aguarde a outra função terminar", RED) Say("⚠ CONFLITO", "Aguarde a outra função terminar.", YELLOW)
            end

            return
        end

        if State.Teleport or State.Farm then
            if Manual then
                Flash("● Desligue o Teleporte NPC / Autofarm primeiro", RED) Say("⚠ CONFLITO", "Desligue o Teleporte NPC / Autofarm primeiro.", YELLOW)
            end

            return
        end

        if not GetPlayerRoot(Player) then
            if Manual then
                Flash("● Você está sem personagem", RED)
            end

            return
        end

        Running = true
        State.RecRunning = true
        LastRun = os.clock()
        RecoverButton.Text = "..."
        RecoverButton.BackgroundColor3 = ON_COLOR
        SetInfo("● Recuperando • " .. tostring(Reason), YELLOW)

        VoidShield.Add("recover")
        Grace(1.5)

        local Went = false

        local Ok, Err = pcall(function()
            for _ = 1, 3 do
                local HRP = GetHRP()

                if not HRP then
                    break
                end

                HRP.Anchored = false
                Went = GoSafe() or Went

                task.wait(0.12)
            end
        end)

        VoidShield.Remove("recover")
        Grace(1)

        if Ok and Went then
            Recovered += 1
            ClearFailure("Recuperar Void")
        elseif Ok then
            SetFailure("Recuperar Void", "sem plataforma nem spawn")
        else
            SetFailure("Recuperar Void", tostring(Err))
        end

        RecoverButton.Text = "VOLTAR"
        RecoverButton.BackgroundColor3 = IDLE_COLOR

        task.wait(0.4)

        Running = false
        State.RecRunning = false
        RestingInfo()
    end

    -- Gancho usado pelo Anti-Fakeout quando ele falha
    Hooks.Recover = function()
        if State.AutoRec and Alive then
            task.spawn(DoRecover, "Anti-Fakeout falhou", false)
        end
    end

    --------------------------------------------------
    -- VIGIA AUTOMÁTICO
    --------------------------------------------------

    Track(RunService.Heartbeat:Connect(function()
        if not Alive then
            return
        end

        local HRP = GetPlayerRoot(Player)

        if not HRP then
            LastSafePos = nil
            return
        end

        local Busy = State.FakeRunning
            or State.RecRunning
            or State.AntiRunning
            or State.Teleport
            or State.Escaping
            or State.Farm
            or InGrace()

        local Pos = HRP.Position
        local TopY = GetPlatformTopY()
        local Limit

        if TopY then
            Limit = TopY - Drop
        else
            Limit = RealHeight() + 80
        end

        if Pos.Y >= Limit + 10 and not Busy then
            LastSafePos = Pos
        end

        if State.AutoRec
            and not Busy
            and Pos.Y < Limit
            and os.clock() - LastRun > 2 then

            task.spawn(DoRecover, "caiu " .. math.floor(Limit - Pos.Y + 0.5) .. " studs", false)
        end
    end))

    --------------------------------------------------
    -- PISO SEGURO
    --------------------------------------------------

    local function GuardStep()
        if not Alive or not GuardOn then
            return
        end

        if not (State.Teleport or State.FakeRunning or State.Escaping or State.Farm) then
            return
        end

        local HRP = GetPlayerRoot(Player)

        if not HRP then
            return
        end

        local Floor = RealHeight() + FLOOR_MARGIN
        local P = HRP.Position

        if P.Y < Floor then
            local Rot = HRP.CFrame - HRP.CFrame.Position

            HRP.CFrame = CFrame.new(P.X, Floor, P.Z) * Rot
            HRP.AssemblyLinearVelocity = Vector3.zero
            GuardHits += 1
        end
    end

    Track(RunService.Stepped:Connect(function()
        local Ok, Err = pcall(GuardStep)

        if not Ok then
            SetFailure("Recuperar Void", tostring(Err))
        end
    end))

    -- Depois dos outros Heartbeat (Teleporte NPC etc.) para ser o último a mexer
    Track(RunService.Heartbeat:Connect(function()
        if not GuardOn then
            return
        end

        task.defer(function()
            pcall(GuardStep)
        end)
    end))

    local GuardAcc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive then
            return
        end

        GuardAcc += dt

        if GuardAcc < 0.5 then
            return
        end

        GuardAcc = 0

        if GuardOn then
            GuardInfo.Text = "● Piso: Y ≥ " .. math.floor(RealHeight() + FLOOR_MARGIN)
                .. " • " .. GuardHits .. " correções"
            GuardInfo.TextColor3 = GREEN
        else
            GuardInfo.Text = "● Piso seguro desligado"
            GuardInfo.TextColor3 = MUTED_TEXT
        end
    end))

    --------------------------------------------------
    -- BOTÕES
    --------------------------------------------------

    MakeDraggable(RecoverButton, RecoverButton, RecState, function()
        task.spawn(DoRecover, "manual", true)
    end)

    ManualToggle.Activated:Connect(function()
        State.VoidRec = not State.VoidRec

        ManualToggle.Text = State.VoidRec and "MANUAL • ON" or "MANUAL • OFF"
        ManualToggle.BackgroundColor3 = State.VoidRec and ON_COLOR or OFF_COLOR

        RefreshButton()
        RestingInfo()

        if RefreshHub then
            RefreshHub()
        end
    end)

    RecNow.Activated:Connect(function()
        task.spawn(DoRecover, "manual", true)
    end)

    AutoToggle.Activated:Connect(function()
        State.AutoRec = not State.AutoRec

        AutoToggle.Text = State.AutoRec and "AUTO-RECUPERAR • ON" or "AUTO-RECUPERAR • OFF"
        AutoToggle.BackgroundColor3 = State.AutoRec and ON_COLOR or OFF_COLOR

        if not State.AutoRec then
            ClearFailure("Recuperar Void")
        end

        RestingInfo()

        if RefreshHub then
            RefreshHub()
        end
    end)

    DropButton.Activated:Connect(function()
        DropIndex = (DropIndex % #DROP_OPTIONS) + 1
        Drop = DROP_OPTIONS[DropIndex]
        DropButton.Text = "LIMITE ABAIXO DA PLATAFORMA • " .. Drop .. " studs"
    end)

    GuardToggle.Activated:Connect(function()
        GuardOn = not GuardOn

        GuardToggle.Text = GuardOn and "PISO SEGURO • ON" or "PISO SEGURO • OFF"
        GuardToggle.BackgroundColor3 = GuardOn and ON_COLOR or OFF_COLOR
    end)

    KeyButton.Activated:Connect(function()
        Capturing = not Capturing
        KeyBusy.Active = Capturing

        KeyButton.Text = Capturing
            and "PRESSIONE UMA TECLA..."
            or ("TECLA • " .. RecKey.Name)

        KeyButton.BackgroundColor3 = Capturing and SELECTED_COLOR or OFF_COLOR
    end)

    ShowToggle.Activated:Connect(function()
        ShowButton = not ShowButton

        ShowToggle.Text = ShowButton
            and "BOTÃO NA TELA • ON"
            or "BOTÃO NA TELA • OFF"

        ShowToggle.BackgroundColor3 = ShowButton and ON_COLOR or OFF_COLOR

        RefreshButton()
    end)

    Track(UserInputService.InputBegan:Connect(function(Input)
        if not Alive then
            return
        end

        if Input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if Capturing then
            Capturing = false
            KeyBusy.Active = false
            KeyBusy.LastEnd = os.clock()

            if Input.KeyCode ~= Enum.KeyCode.Escape
                and Input.KeyCode ~= Enum.KeyCode.Unknown then
                RecKey = Input.KeyCode
            end

            KeyButton.Text = "TECLA • " .. RecKey.Name
            KeyButton.BackgroundColor3 = OFF_COLOR

            return
        end

        if KeyBusy.Active or os.clock() - KeyBusy.LastEnd < 0.3 then
            return
        end

        if State.VoidRec
            and Input.KeyCode == RecKey
            and not UserInputService:GetFocusedTextBox() then

            task.spawn(DoRecover, "manual", true)
        end
    end))

    --------------------------------------------------
    -- AUTO-RESET (DETECTOR DE TRAVAMENTO)
    -- Personagem preso (ragdoll / physics / travado por outro script)
    -- por muito tempo: reseta sozinho.
    --------------------------------------------------

    local TIMEOUTS = {3, 5, 8}
    local TimeoutIndex = 2
    local Timeout = TIMEOUTS[TimeoutIndex]
    local StuckSince = nil
    local Resetting = false

    local ResetCard = Card(
        Page,
        "AUTO-RESET (TRAVADO)",
        "Se o personagem ficar travado (ragdoll, estado de física ou preso por outro script) além do tempo escolhido, reseta sozinho. Não age durante funções do Hub que te seguram de propósito."
    )
    ResetCard.LayoutOrder = 6

    local ResetToggle = Button(ResetCard, "AUTO-RESET • OFF", 3)
    local TimeoutButton = Button(ResetCard, "TEMPO TRAVADO • " .. Timeout .. "s", 4)

    local function DoReset()
        if Resetting then
            return
        end

        Resetting = true
        Hooks.ResetWarn = nil

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid then
            Say("🔄 AUTO-RESET", "Personagem travado. Resetando.", YELLOW)

            local Ok, Err = pcall(function()
                Humanoid.Health = 0
            end)

            if not Ok then
                SetFailure("Auto-Reset", tostring(Err))
            else
                ClearFailure("Auto-Reset")
            end

            local Start = os.clock()

            while Alive and Character.Parent and os.clock() - Start < 4 do
                Grace(0.6)

                local Elapsed = os.clock() - Start

                if Elapsed > 1 and Humanoid.Parent then
                    pcall(function()
                        Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
                    end)
                end

                if Elapsed > 2 then
                    pcall(function()
                        Character:BreakJoints()
                    end)
                end

                task.wait(0.1)
            end
        end

        StuckSince = nil
        Resetting = false
    end

    ResetToggle.Activated:Connect(function()
        State.AutoReset = not State.AutoReset

        ResetToggle.Text = State.AutoReset and "AUTO-RESET • ON" or "AUTO-RESET • OFF"
        ResetToggle.BackgroundColor3 = State.AutoReset and ON_COLOR or OFF_COLOR

        StuckSince = nil
        Hooks.ResetWarn = nil

        if not State.AutoReset then
            ClearFailure("Auto-Reset")
        end

        if RefreshHub then
            RefreshHub()
        end
    end)

    TimeoutButton.Activated:Connect(function()
        TimeoutIndex = (TimeoutIndex % #TIMEOUTS) + 1
        Timeout = TIMEOUTS[TimeoutIndex]
        TimeoutButton.Text = "TEMPO TRAVADO • " .. Timeout .. "s"
    end)

    Track(RunService.Heartbeat:Connect(function()
        if not Alive or not State.AutoReset or Resetting then
            return
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local HRP = Character and Character:FindFirstChild("HumanoidRootPart")

        local Busy = State.Teleport
            or State.FakeRunning
            or State.RecRunning
            or State.AntiRunning
            or State.Escaping
            or State.Farm
            or InGrace()

        if not Humanoid or not HRP or Humanoid.Health <= 0 or Busy then
            StuckSince = nil

            if Hooks.ResetWarn then
                Hooks.ResetWarn = nil
            end

            return
        end

        local HState = Humanoid:GetState()

        local Stuck = HRP.Anchored
            or Humanoid.PlatformStand
            or HState == Enum.HumanoidStateType.Physics
            or HState == Enum.HumanoidStateType.Ragdoll
            or HState == Enum.HumanoidStateType.FallingDown

        local Now = os.clock()

        if not Stuck then
            StuckSince = nil
            Hooks.ResetWarn = nil
            return
        end

        if not StuckSince then
            StuckSince = Now
        end

        if Now - StuckSince > 1 then
            Hooks.ResetWarn = true
        end

        if Now - StuckSince >= Timeout then
            task.spawn(DoReset)
        end
    end))

    RestingInfo()
end

--==================================================
-- INVISÍVEL (aba INVISÍVEL)
-- Para fugir de scripts com autofarm ou loop tp: o servidor vê o seu
-- personagem longe, correndo em círculo, enquanto o seu aparelho te
-- mostra no lugar certo (câmera, skills e controles normais).
-- MANUAL liga/desliga na hora. AUTO é separado: liga sozinho quando
-- alguém teleporta colado em você e desliga depois de um tempo.
--==================================================

do
    local Page = Pages.Invisible
    local RenderName = "PABLOX_Invisivel"

    local CFG = {
        Distance = 333000,
        OrbitRadius = 60,
        OrbitSpeed = 300,
        AutoMax = 600,
        ThreatRadius = 7,
        TeleportJump = 30,
        GlueFrames = 18,
        GlueOffset = Vector3.new(0, 0, 2.2),
        GlueTol = 1,
        RadarJump = 40,
        RadarCount = 3,
        RadarWindow = 6,
        MarkTime = 180,
        AlertRadius = 150,
    }

    local HOLD_OPTIONS = {8, 15, 30, 60}
    local HoldIndex = 2
    local AutoHold = HOLD_OPTIONS[HoldIndex]

    local Manual = false
    local AutoEnabled = true
    local AutoOn = false
    local RadarOn = true
    local ButtonsOn = true
    local WantDown = true

    local Running = false
    local Used = "Side"
    local Offset = Vector3.zero
    local OrbitA = 0
    local TrueCF = nil
    local Swapped = nil
    local EnabledAt = 0
    local AutoStart = 0
    local ThreatUntil = 0
    local LastSay = 0
    local Conns = {}

    local Flagged = {}
    local Marked = {}
    local LastPos = {}
    local Glue = {}
    local JumpLog = {}
    local LastChar = {}
    local Hits = {On = 0, Off = 0}

    ----------------------------------------------
    -- INTERFACE (mesmo estilo dos outros botões)
    ----------------------------------------------

    local C1 = Card(
        Page,
        "INVISÍVEL",
        "Serve para fugir de scripts com autofarm ou com loop tp. O servidor passa a ver o seu personagem longe, correndo em círculo, e quem tenta te seguir não te acha. No seu aparelho você continua no lugar certo, com câmera, skills e controles normais. Este botão é o MANUAL: liga e desliga na hora."
    )
    C1.LayoutOrder = 1

    local ManualToggle = Button(C1, "INVISÍVEL (MANUAL) • OFF", 3)

    local C2 = Card(
        Page,
        "MODO AUTO (SEPARADO)",
        "Funciona separado do manual. Liga a invisibilidade sozinho quando alguém teleporta colado em você ou fica grudado nas suas costas (autofarm / loop tp) e desliga depois de alguns segundos sem ameaça. O RADAR marca quem dá vários teleportes seguidos e liga antes dele chegar."
    )
    C2.LayoutOrder = 2

    local AutoToggle = Button(C2, "MODO AUTO • ON", 3)
    AutoToggle.BackgroundColor3 = ON_COLOR
    local RadarToggle = Button(C2, "RADAR • ON", 4)
    RadarToggle.BackgroundColor3 = ON_COLOR
    local HoldButton = Button(C2, "TEMPO NO AUTO • " .. AutoHold .. "s", 5)

    local C3 = Card(
        Page,
        "BOTÕES NA TELA",
        "Dois botões pequenos e arrastáveis: INVIS (manual) e AUTO (liga/desliga o modo auto). Ficam na tela mesmo com a Hub fechada."
    )
    C3.LayoutOrder = 3

    local ButtonsToggle = Button(C3, "BOTÕES NA TELA • ON", 3)
    ButtonsToggle.BackgroundColor3 = ON_COLOR

    local C4 = Card(
        Page,
        "ONDE O SERVIDOR TE VÊ",
        "BAIXO: muito abaixo do mapa. LADO: muito longe para o lado. Se o BAIXO mataria você no void, o Hub usa o LADO sozinho."
    )
    C4.LayoutOrder = 4

    local PlaceButton = Button(C4, "ONDE FICA • BAIXO", 3)

    local C5, _, InfoLabel = Card(Page, "ESTADO", "● Desligado")
    C5.LayoutOrder = 5
    InfoLabel.Font = Enum.Font.GothamBold
    InfoLabel.TextColor3 = MUTED_TEXT

    -- botões pequenos na tela
    local FLOAT = 42
    local IDLE_COLOR = Color3.fromRGB(18, 18, 23)
    local ManState = {Center = nil}
    local AutoState = {Center = nil}

    local function MakeFloat(Name, Text)
        local B = Instance.new("TextButton")
        B.Name = Name
        B.Parent = Gui
        B.AnchorPoint = Vector2.new(0.5, 0.5)
        B.Size = UDim2.fromOffset(FLOAT, FLOAT)
        B.Position = UDim2.fromOffset(60, 200)
        B.BackgroundColor3 = IDLE_COLOR
        B.BorderSizePixel = 0
        B.AutoButtonColor = false
        B.Text = Text
        B.Font = Enum.Font.GothamBold
        B.TextSize = 10
        B.TextColor3 = Color3.fromRGB(245, 245, 250)
        B.Visible = false
        B.Active = true
        B.ZIndex = 20

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(1, 0)
        Corner.Parent = B

        local Stroke = Instance.new("UIStroke")
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Stroke.Color = Color3.fromRGB(0, 170, 255)
        Stroke.Thickness = 2
        Stroke.Parent = B

        return B
    end

    local ManualFloat = MakeFloat("InvisivelManual", "INVIS\nOFF")
    local AutoFloat = MakeFloat("InvisivelAuto", "AUTO\nON")

    local function PlaceFloat(B, StateT, Index)
        if not StateT.Center then
            local V = ScreenSize()

            StateT.Center = ClampCenter(
                Vector2.new(V.X - 36, V.Y / 2 + 150 + (Index - 1) * 50),
                Vector2.new(FLOAT, FLOAT),
                6
            )

            B.Position = UDim2.fromOffset(StateT.Center.X, StateT.Center.Y)
        end
    end

    local function Repaint()
        ManualToggle.Text = "INVISÍVEL (MANUAL) • " .. (Manual and "ON" or "OFF")
        ManualToggle.BackgroundColor3 = Manual and ON_COLOR or OFF_COLOR

        AutoToggle.Text = "MODO AUTO • " .. (AutoEnabled and "ON" or "OFF")
        AutoToggle.BackgroundColor3 = AutoEnabled and ON_COLOR or OFF_COLOR

        RadarToggle.Text = "RADAR • " .. (RadarOn and "ON" or "OFF")
        RadarToggle.BackgroundColor3 = RadarOn and ON_COLOR or OFF_COLOR

        ButtonsToggle.Text = "BOTÕES NA TELA • " .. (ButtonsOn and "ON" or "OFF")
        ButtonsToggle.BackgroundColor3 = ButtonsOn and ON_COLOR or OFF_COLOR

        PlaceButton.Text = "ONDE FICA • " .. (WantDown and "BAIXO" or "LADO")
        HoldButton.Text = "TEMPO NO AUTO • " .. AutoHold .. "s"

        ManualFloat.Visible = ButtonsOn
        AutoFloat.Visible = ButtonsOn

        if ButtonsOn then
            PlaceFloat(ManualFloat, ManState, 1)
            PlaceFloat(AutoFloat, AutoState, 2)
        end

        ManualFloat.Text = "INVIS\n" .. (Manual and "ON" or "OFF")
        ManualFloat.BackgroundColor3 = Manual and ON_COLOR or IDLE_COLOR

        if AutoOn then
            AutoFloat.Text = "AUTO\nATIVO"
            AutoFloat.BackgroundColor3 = Color3.fromRGB(150, 105, 20)
        elseif AutoEnabled then
            AutoFloat.Text = "AUTO\nON"
            AutoFloat.BackgroundColor3 = Color3.fromRGB(30, 60, 110)
        else
            AutoFloat.Text = "AUTO\nOFF"
            AutoFloat.BackgroundColor3 = IDLE_COLOR
        end
    end

    local function RestingInfo()
        if Running then
            InfoLabel.Text = (AutoOn and "● Invisível (AUTO)" or "● Invisível (MANUAL)")
                .. " • " .. (Used == "Down" and "embaixo do mapa" or "longe, ao lado")
                .. " • golpes: " .. Hits.On
            InfoLabel.TextColor3 = AutoOn and YELLOW or GREEN
        elseif AutoEnabled then
            InfoLabel.Text = "● Vigiando (modo auto) • golpes sem invisível: " .. Hits.Off
            InfoLabel.TextColor3 = GREEN
        else
            InfoLabel.Text = "● Desligado"
            InfoLabel.TextColor3 = MUTED_TEXT
        end
    end

    ----------------------------------------------
    -- NÚCLEO: o servidor vê longe, você vê perto
    ----------------------------------------------

    local function ComeBack()
        local Root = Swapped

        if Root and Root.Parent and TrueCF then
            Root.CFrame = TrueCF
        end

        Swapped = nil
    end

    local function GoFar(_, Dt)
        local Root = GetHRP()

        if not Root then
            Swapped = nil
            return
        end

        Grace(0.3)

        local CF = Root.CFrame

        TrueCF = CF
        Swapped = Root

        OrbitA = (OrbitA + (CFG.OrbitSpeed / math.max(CFG.OrbitRadius, 1)) * (Dt or 1 / 60)) % (2 * math.pi)

        local Pos = CF.Position + Offset + Vector3.new(math.cos(OrbitA), 0, math.sin(OrbitA)) * CFG.OrbitRadius
        local Tangent = Vector3.new(-math.sin(OrbitA), 0, math.cos(OrbitA))

        Root.CFrame = CFrame.lookAt(Pos, Pos + Tangent)
    end

    local function HeartbeatFar(Dt)
        GoFar(nil, Dt)
    end

    local function StartFx()
        local Root = GetHRP()

        if not Root then
            return false
        end

        Running = true
        Used = WantDown and "Down" or "Side"

        local Sign = Root.Position.X >= 0 and 1 or -1

        if Used == "Down" then
            local Limit = VoidShield.Original or workspace.FallenPartsDestroyHeight

            if Limit < -5000 then
                Limit = -500
            end

            if Root.Position.Y - CFG.Distance < Limit then
                Used = "Side"
            end
        end

        if Used == "Down" then
            Offset = Vector3.new(0, -CFG.Distance, 0)
        else
            Offset = Vector3.new(Sign * CFG.Distance, 0, 0)
        end

        EnabledAt = os.clock()
        Grace(1)

        local Bound = pcall(function()
            RunService:BindToRenderStep(RenderName, -2000, ComeBack)
        end)

        if not Bound then
            pcall(function()
                RunService:BindToRenderStep(RenderName, Enum.RenderPriority.First.Value, ComeBack)
            end)
        end

        table.insert(Conns, RunService.Stepped:Connect(ComeBack))

        pcall(function()
            table.insert(Conns, RunService.PreSimulation:Connect(ComeBack))
        end)

        table.insert(Conns, RunService.Heartbeat:Connect(HeartbeatFar))

        return true
    end

    local function StopFx()
        Running = false

        for _, Conn in ipairs(Conns) do
            pcall(function()
                Conn:Disconnect()
            end)
        end

        table.clear(Conns)

        pcall(function()
            RunService:UnbindFromRenderStep(RenderName)
        end)

        ComeBack()
        Grace(0.8)
    end

    local function Update()
        local Want = Manual or AutoOn

        if Want and not Running then
            if not StartFx() then
                Manual = false
                AutoOn = false
            end
        elseif not Want and Running then
            StopFx()
        end

        State.Invisible = Running

        Repaint()
        RestingInfo()

        if RefreshHub then
            RefreshHub()
        end
    end

    ----------------------------------------------
    -- DETECÇÃO DE AUTOFARM / LOOP TP (modo auto)
    ----------------------------------------------

    local function Trigger(P, Now)
        Flagged[P] = true
        ThreatUntil = Now + AutoHold

        if not AutoOn then
            AutoOn = true
            AutoStart = Now

            if Now - LastSay > 5 then
                LastSay = Now
                Say("👻 INVISÍVEL • AUTO", P.DisplayName .. " parece estar te seguindo. Ficando invisível.", YELLOW)
            end

            Update()
        end
    end

    local function Scan()
        if not Alive then
            return
        end

        local Now = os.clock()

        if AutoOn then
            local Keep = false

            for P in pairs(Flagged) do
                local H = P.Character and P.Character:FindFirstChildOfClass("Humanoid")

                if P.Parent and H and H.Health > 0 then
                    Keep = true
                else
                    Flagged[P] = nil
                end
            end

            if Keep and Now - AutoStart < CFG.AutoMax then
                ThreatUntil = Now + AutoHold
            end

            if Now > ThreatUntil or not AutoEnabled then
                AutoOn = false
                table.clear(Flagged)
                Update()
            end
        end

        if not AutoEnabled then
            return
        end

        local Root = GetHRP()

        if not Root then
            return
        end

        local MyCF = (Running and TrueCF) or Root.CFrame

        for _, P in ipairs(Players:GetPlayers()) do
            if P ~= Player then
                local Char = P.Character
                local R = Char and Char:FindFirstChild("HumanoidRootPart")
                local H = Char and Char:FindFirstChildOfClass("Humanoid")

                if R and H and H.Health > 0 then
                    local Pos = R.Position
                    local Prev = LastPos[P]

                    LastPos[P] = Pos

                    if LastChar[P] ~= Char then
                        LastChar[P] = Char
                        Prev = nil
                    end

                    -- RADAR: vários teleportes longos seguidos = suspeito
                    if RadarOn then
                        if Prev and (Pos - Prev).Magnitude > CFG.RadarJump then
                            local Log = JumpLog[P] or {}

                            JumpLog[P] = Log
                            Log[#Log + 1] = Now

                            while Log[1] and Now - Log[1] > CFG.RadarWindow do
                                table.remove(Log, 1)
                            end

                            if #Log >= CFG.RadarCount then
                                Marked[P] = Now + CFG.MarkTime
                            end
                        end

                        if Marked[P] and Now < Marked[P] and (Pos - MyCF.Position).Magnitude < CFG.AlertRadius then
                            Trigger(P, Now)
                        end
                    end

                    local Rel = MyCF:PointToObjectSpace(Pos)
                    local Threat = false

                    if Rel.Magnitude < CFG.ThreatRadius then
                        -- apareceu colado vindo de longe = teleporte
                        if Prev and (Prev - MyCF.Position).Magnitude > CFG.TeleportJump then
                            Threat = true
                        end

                        -- grudado nas suas costas (posição típica do autofarm)
                        local G = Rel - CFG.GlueOffset

                        if math.abs(G.X) < CFG.GlueTol and math.abs(G.Y) < CFG.GlueTol * 1.5
                            and math.abs(G.Z) < CFG.GlueTol then
                            Glue[P] = (Glue[P] or 0) + 1

                            if Glue[P] >= CFG.GlueFrames then
                                Threat = true
                            end
                        else
                            Glue[P] = 0
                        end
                    else
                        Glue[P] = 0
                    end

                    if Threat then
                        Trigger(P, Now)
                    end
                end
            end
        end
    end

    Track(RunService.RenderStepped:Connect(Scan))

    Track(Players.PlayerRemoving:Connect(function(P)
        LastPos[P], Glue[P], JumpLog[P], LastChar[P], Marked[P], Flagged[P] = nil, nil, nil, nil, nil, nil
    end))

    -- conta golpes sofridos (para você ver se funciona)
    local HpConn = nil

    local function HookHealth(Character)
        if HpConn then
            pcall(function()
                HpConn:Disconnect()
            end)

            HpConn = nil
        end

        local Hum = Character:WaitForChild("Humanoid", 5)

        if not Hum or not Alive then
            return
        end

        local Last = Hum.Health

        HpConn = Hum.HealthChanged:Connect(function(Now)
            if Now < Last - 0.5 then
                if Running then
                    Hits.On += 1
                else
                    Hits.Off += 1
                end
            end

            Last = Now
        end)
    end

    if Player.Character then
        task.spawn(HookHealth, Player.Character)
    end

    Track(Player.CharacterAdded:Connect(function(Character)
        task.spawn(HookHealth, Character)
    end))

    local Acc = 0

    Track(RunService.Heartbeat:Connect(function(Dt)
        if not Alive then
            return
        end

        Acc += Dt

        if Acc >= 0.4 then
            Acc = 0
            RestingInfo()
        end
    end))

    ----------------------------------------------
    -- BOTÕES
    ----------------------------------------------

    local function ToggleManual()
        Manual = not Manual
        Update()
    end

    local function ToggleAuto()
        AutoEnabled = not AutoEnabled

        if not AutoEnabled then
            AutoOn = false
            table.clear(Flagged)
        end

        Update()
    end

    ManualToggle.Activated:Connect(ToggleManual)
    AutoToggle.Activated:Connect(ToggleAuto)

    RadarToggle.Activated:Connect(function()
        RadarOn = not RadarOn
        Repaint()
    end)

    ButtonsToggle.Activated:Connect(function()
        ButtonsOn = not ButtonsOn
        Repaint()
    end)

    HoldButton.Activated:Connect(function()
        HoldIndex = (HoldIndex % #HOLD_OPTIONS) + 1
        AutoHold = HOLD_OPTIONS[HoldIndex]
        Repaint()
    end)

    PlaceButton.Activated:Connect(function()
        WantDown = not WantDown

        if Running then
            StopFx()
            StartFx()
        end

        Repaint()
        RestingInfo()
    end)

    MakeDraggable(ManualFloat, ManualFloat, ManState, ToggleManual)
    MakeDraggable(AutoFloat, AutoFloat, AutoState, ToggleAuto)

    -- desliga tudo ao fechar a Hub
    Track({
        Disconnect = function()
            Manual = false
            AutoOn = false
            AutoEnabled = false

            if Running then
                StopFx()
            end

            State.Invisible = false
        end,
    })

    Hooks.InvisibleOff = function()
        Manual = false
        AutoOn = false
        Update()
    end

    Repaint()
    RestingInfo()
end

--==================================================
-- AUTO-FUGA (v2)
-- Tomou dano de verdade → foge (fakeout: longe / cima e baixo)
-- → volta ATACANDO quem te bateu por 2,5 s → se continuar
-- apanhando, foge de novo e volta, até o alvo morrer.
-- Funciona com o Autofarm ligado (pausa o farm durante o ciclo
-- e foca em quem te ataca, mesmo que o farm estivesse em outro).
-- Protegido pelo Escudo de Void e pelo Piso Seguro.
--==================================================

do
    local Page = Pages.Escape

    local LOSS_OPTIONS = {1, 2, 3, 5, 10, 15, 25, 35, 50}
    local LossIndex = 2
    local WINDOW = 1.2

    local STYLES = {"LONGE", "CIMA/BAIXO", "MISTO", "FURTIVO"}
    local StyleIndex = 3

    local ESC_TIMES = {0.6, 1, 1.5, 2.5}
    local EscIndex = 2

    local COUNTER_TIMES = {2.5, 3.5, 5, 8}
    local CounterIndex = 1

    local REARM_TIMES = {4, 6, 10}
    local RearmIndex = 2

    local RepeatCycles = true
    local HugMode = true
    local AntiLoop = true
    local Preempt = true
    local LooperUntil = 0
    local LastThreatFrom = nil
    local LastThreatAt = 0

    local COOLDOWN = 1.2
    local FAR_DISTANCE = 3000
    local VERTICAL = 140
    local COUNTER_BEHIND = 2.2
    local ATTACK_GAP = 0.04
    local SOURCE_RANGE = 70
    local MAX_CYCLES = 60

    local Log = {}
    local LastTrigger = 0
    local Running = false
    local Countering = false
    local LastLoss = 0
    local LastDamageAt = 0
    local LastAttacker = nil
    local LastAttackerAt = 0
    local CycleNow = 0
    local TargetName = nil
    local HealthConn = nil

    local MainCard = Card(
        Page,
        "AUTO-FUGA",
        "Quando você leva dano de verdade, o Hub te teleporta para longe (ou para cima e para baixo, tipo fakeout) e depois te traz de volta ATACANDO quem te bateu por alguns segundos. Se você continuar apanhando, repete: foge, volta atacando, foge... até o alvo morrer. Funciona junto com o Autofarm e foca em quem está te atacando, mesmo se o farm estiver em outro jogador."
    )
    MainCard.LayoutOrder = 1

    local EscapeToggle = Button(MainCard, "AUTO-FUGA • OFF", 3)

    local InfoCard, _, Info = Card(Page, "ESTADO", "● Desligado")
    InfoCard.LayoutOrder = 2
    Info.Font = Enum.Font.GothamBold
    Info.TextColor3 = MUTED_TEXT

    local LossCard = Card(
        Page,
        "GATILHO (DANO LEVADO)",
        "Porcentagem da vida máxima perdida em cerca de 1 segundo para disparar a fuga. Só conta dano quando há um jogador ou o NPC perto de você (queda e void não disparam). Menor = dispara mais fácil (1%, 2% e 3% disparam até com golpes fracos)."
    )
    LossCard.LayoutOrder = 3

    local LossButton = Button(LossCard, "GATILHO • " .. LOSS_OPTIONS[LossIndex] .. "% da vida", 3)

    local StyleCard = Card(
        Page,
        "ESTILO DA FUGA",
        "LONGE: salta para pontos muito distantes. CIMA/BAIXO: alterna acima e abaixo de você (140 studs). MISTO: mistura os dois."
    )
    StyleCard.LayoutOrder = 4

    local StyleButton = Button(StyleCard, "ESTILO • " .. STYLES[StyleIndex], 3)
    local EscTimeButton = Button(StyleCard, "TEMPO FUGINDO • " .. ESC_TIMES[EscIndex] .. "s", 4)

    local CounterCard = Card(
        Page,
        "VOLTA ATACANDO",
        "Depois da fuga você volta para trás de quem te atacou (ou do NPC) e ataca sem parar com o M1 (PC) ou o botão de ataque do jogo (mobile) por este tempo."
    )
    CounterCard.LayoutOrder = 5

    local CounterButton = Button(CounterCard, "ATACAR POR • " .. COUNTER_TIMES[CounterIndex] .. "s", 3)

    local RepeatCard = Card(
        Page,
        "REPETIR ATÉ MORRER",
        "Ligado: depois de voltar atacando, se você ainda levou dano nos últimos segundos abaixo, foge e volta de novo — até o alvo morrer, você morrer ou parar de apanhar. Desligado: faz só um ciclo por gatilho."
    )
    RepeatCard.LayoutOrder = 6

    local RepeatButton = Button(RepeatCard, "REPETIR • ON", 3)
    local RearmButton = Button(RepeatCard, "CONTINUAR SE APANHAR NOS ÚLTIMOS • " .. REARM_TIMES[RearmIndex] .. "s", 4)
    local HugButton = Button(RepeatCard, "GRUDAR NO ATACANTE • ON", 5)
    local LoopButton = Button(RepeatCard, "ANTI LOOP-TP • ON", 6)
    local PreButton = Button(RepeatCard, "FUGA PREVENTIVA • ON", 7)
    HugButton.BackgroundColor3 = ON_COLOR
    LoopButton.BackgroundColor3 = ON_COLOR
    PreButton.BackgroundColor3 = ON_COLOR

    local function SetInfo(Text, Color)
        Info.Text = Text
        Info.TextColor3 = Color
    end

    local function RestingInfo()
        if State.Escaping then
            SetInfo(
                "● Ciclo " .. CycleNow .. " • alvo: " .. tostring(TargetName or "NPC"),
                YELLOW
            )
        elseif State.Escape then
            SetInfo(
                "● Vigiando • perda atual " .. math.floor(LastLoss + 0.5) .. "% • "
                    .. Hooks.EscapeCount .. " fugas",
                GREEN
            )
        else
            SetInfo("● Desligado", MUTED_TEXT)
        end
    end

    --------------------------------------------------
    -- QUEM ESTÁ ME ATACANDO?
    -- Marca "creator" do jogo, quem olha para mim, quem
    -- vem na minha direção e o último atacante (pesa mais).
    --------------------------------------------------

    local function FindAttacker()
        local HRP = GetHRP()

        if not HRP then
            return nil, false
        end

        local Now = os.clock()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Tag = Humanoid and Humanoid:FindFirstChild("creator")

        if Tag and Tag:IsA("ObjectValue") then
            local Value = Tag.Value

            if typeof(Value) == "Instance" and Value:IsA("Player") and Value ~= Player and GetPlayerRoot(Value) then
                return Value, true
            end
        end

        local Best
        local BestScore

        for _, Other in ipairs(Players:GetPlayers()) do
            if Other ~= Player then
                local Root = GetPlayerRoot(Other)

                if Root then
                    local Offset = HRP.Position - Root.Position
                    local Dist = Offset.Magnitude

                    if Dist <= SOURCE_RANGE then
                        local Score = Dist

                        if Dist > 0.1 then
                            local Dir = Offset.Unit
                            local Facing = Root.CFrame.LookVector:Dot(Dir)
                            local Closing = Root.AssemblyLinearVelocity:Dot(Dir)

                            if Facing > 0.3 then
                                Score -= 18 * Facing
                            end

                            if Closing > 12 then
                                Score -= 8
                            end
                        end

                        if Other == LastAttacker and Now - LastAttackerAt < 10 then
                            Score -= 14
                        end

                        if not BestScore or Score < BestScore then
                            BestScore = Score
                            Best = Other
                        end
                    end
                end
            end
        end

        if Best then
            return Best, true
        end

        local Npc = GetNPCTorso()

        if Npc and (Npc.Position - HRP.Position).Magnitude <= SOURCE_RANGE then
            return nil, true
        end

        return nil, false
    end

    --------------------------------------------------
    -- LEITURA DE DANO (HealthChanged = instantâneo)
    --------------------------------------------------

    local function OnHealth(Humanoid)
        local Last = Humanoid.Health

        HealthConn = Humanoid.HealthChanged:Connect(function(New)
            local Delta = Last - New
            Last = New

            if Delta <= 0.5 or not Alive then
                return
            end

            local Attacker, HasSource = FindAttacker()

            if not HasSource then
                return
            end

            local Now = os.clock()

            LastDamageAt = Now

            if Attacker then
                LastAttacker = Attacker
                LastAttackerAt = Now
            end

            table.insert(Log, {Now, Delta})
        end)
    end

    local function HookCharacter(Character)
        if HealthConn then
            HealthConn:Disconnect()
            HealthConn = nil
        end

        table.clear(Log)

        local Humanoid = Character:WaitForChild("Humanoid", 10)

        if Humanoid and Alive then
            OnHealth(Humanoid)
        end
    end

    if Player.Character then
        task.spawn(HookCharacter, Player.Character)
    end

    Track(Player.CharacterAdded:Connect(function(Character)
        task.spawn(HookCharacter, Character)
    end))

    local PRE_SKIP = {"idle", "walk", "run", "jump", "fall", "climb", "swim", "sit", "emote", "equip", "unequip", "block", "react", "stun", "ragdoll", "knock", "getup", "flinch", "hit", "damage", "dash", "dodge", "sprint"}

    local function WatchEnemy(Other)
        if Other == Player then
            return
        end

        local function Hook(Character)
            local Hum = Character:WaitForChild("Humanoid", 8)
            local Animator = Hum and (Hum:FindFirstChildOfClass("Animator") or Hum:WaitForChild("Animator", 8))

            if not Animator then
                return
            end

            Track(Animator.AnimationPlayed:Connect(function(AnimTrack)
                if not Alive or not Preempt or not State.Escape or AnimTrack.Looped then
                    return
                end

                local Pr = AnimTrack.Priority

                if Pr ~= Enum.AnimationPriority.Action and Pr ~= Enum.AnimationPriority.Action2
                    and Pr ~= Enum.AnimationPriority.Action3 and Pr ~= Enum.AnimationPriority.Action4 then
                    return
                end

                local Name = string.lower((AnimTrack.Animation and AnimTrack.Animation.Name) or AnimTrack.Name or "")

                for _, Word in ipairs(PRE_SKIP) do
                    if string.find(Name, Word, 1, true) then
                        return
                    end
                end

                local R, H = GetPlayerRoot(Other), GetHRP()

                if not R or not H then
                    return
                end

                local Off = H.Position - R.Position
                local D = Off.Magnitude

                if D <= 11 and D > 0.1 and R.CFrame.LookVector:Dot(Off.Unit) > 0.4 then
                    LastThreatFrom = Other
                    LastThreatAt = os.clock()
                end
            end))
        end

        if Other.Character then
            task.spawn(Hook, Other.Character)
        end

        Track(Other.CharacterAdded:Connect(Hook))
    end

    for _, Other in ipairs(Players:GetPlayers()) do
        WatchEnemy(Other)
    end

    Track(Players.PlayerAdded:Connect(WatchEnemy))

    local function LossInWindow()
        local Now = os.clock()
        local Sum = 0

        while #Log > 0 and Now - Log[1][1] > WINDOW do
            table.remove(Log, 1)
        end

        for _, Entry in ipairs(Log) do
            Sum += Entry[2]
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Max = Humanoid and math.max(Humanoid.MaxHealth, 1) or 100

        return Sum / Max * 100
    end

    --------------------------------------------------
    -- FASES
    --------------------------------------------------

    local function IAmAlive()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        return Humanoid ~= nil and Humanoid.Health > 0 and GetHRP() ~= nil
    end

    -- Foge: saltos rápidos (fakeout)
    local function FleePhase(Origin)
        local Start = os.clock()
        local Step = 0

        while Alive and State.Escape and os.clock() - Start < ESC_TIMES[EscIndex] do
            local HRP = GetHRP()

            if not HRP or not IAmAlive() then
                return false
            end

            Step += 1
            Grace(0.4)

            local Mode = STYLES[StyleIndex]

            if Mode == "MISTO" then
                Mode = (Step % 3 == 0) and "LONGE" or "CIMA/BAIXO"
            end

            local Pos

            if Mode == "FURTIVO" then
                -- um ponto novo e bem longe a CADA frame (ninguém consegue seguir)
                local Angle = math.random() * math.pi * 2
                local Dist = math.random(3000, 60000)

                Pos = Origin.Position + Vector3.new(
                    math.cos(Angle) * Dist,
                    math.random(-4000, 3000),
                    math.sin(Angle) * Dist
                )
            elseif Mode == "LONGE" then
                local Angle = math.random() * math.pi * 2
                local Dist = FAR_DISTANCE * (0.6 + math.random() * 0.4)

                Pos = Origin.Position + Vector3.new(
                    math.cos(Angle) * Dist,
                    math.random(-200, 300),
                    math.sin(Angle) * Dist
                )
            else
                local Dir = (Step % 2 == 0) and VERTICAL or -VERTICAL

                Pos = Origin.Position + Vector3.new(
                    math.random(-6, 6),
                    Dir,
                    math.random(-6, 6)
                )
            end

            HRP.AssemblyLinearVelocity = Vector3.zero
            HRP.AssemblyAngularVelocity = Vector3.zero
            HRP.CFrame = CFrame.new(Pos)

            if Mode == "FURTIVO" then
                RunService.Heartbeat:Wait()
            else
                task.wait(0.06)
            end
        end

        return true
    end

    -- Volta atacando. Devolve: "fim" | "cedo" | "alvo" (morreu) | "eu" (morri)
    local function CounterPhase(Target, Origin)
        Countering = true
        table.clear(Log)

        task.spawn(function()
            while Alive and Countering do
                if not State.Blocking then
                    pcall(GameInput.AttackAuto)
                end

                task.wait(ATTACK_GAP)
            end
        end)

        local Result = "fim"
        local CStart = os.clock()
        local EndTime = CStart + (HugMode and 1e9 or COUNTER_TIMES[CounterIndex])
        local Seen = false
        local LastRootPos, LastRootT, LooperHits = nil, 0, 0

        while Alive and State.Escape and os.clock() < EndTime do
            local HRP = GetHRP()

            if not HRP or not IAmAlive() then
                Result = "eu"
                break
            end

            Grace(0.4)

            local Root

            if Target then
                Root = GetPlayerRoot(Target)

                if Root then
                    Seen = true
                elseif Seen or Target.Parent ~= Players then
                    Result = "alvo"
                    break
                end
            else
                Root = GetNPCTorso()
            end

            if Root then
                -- detecta alvo com loop-tp / autofarm (ele se teleporta em volta de mim)
                if AntiLoop then
                    local Now = os.clock()
                    local PosNow = Root.Position

                    if LastRootPos and Now > LastRootT then
                        local Speed = (PosNow - LastRootPos).Magnitude / (Now - LastRootT)

                        if Speed > 140 then
                            LooperHits += 1
                        else
                            LooperHits = math.max(LooperHits - 0.2, 0)
                        end

                        if LooperHits >= 4 then
                            LooperUntil = Now + 6
                            LooperHits = 0
                        end
                    end

                    LastRootPos = PosNow
                    LastRootT = Now
                end

                if AntiLoop and os.clock() < LooperUntil then
                    -- ele já gruda em mim: não teleporto junto, fico firme, olho para ele e bato
                    local Flat = Vector3.new(Root.Position.X - HRP.Position.X, 0, Root.Position.Z - HRP.Position.Z)

                    if Flat.Magnitude > 14 or math.abs(Root.Position.Y - HRP.Position.Y) > 30 then
                        Combat.Place(Root, COUNTER_BEHIND)
                    elseif Flat.Magnitude > 0.1 then
                        HRP.CFrame = CFrame.lookAt(HRP.Position, HRP.Position + Flat.Unit)
                        HRP.AssemblyAngularVelocity = Vector3.zero
                    end
                else
                    Combat.Place(Root, COUNTER_BEHIND)
                end
            else
                HRP.AssemblyLinearVelocity = Vector3.zero
                HRP.CFrame = Origin
            end

            -- apanhou forte de novo: corta a volta e foge já
            if RepeatCycles and os.clock() - CStart > 1 and LossInWindow() >= LOSS_OPTIONS[LossIndex] * 1.5 then
                Result = "cedo"
                break
            end

            RunService.Heartbeat:Wait()
        end

        Countering = false

        return Result
    end

    --------------------------------------------------
    -- CICLOS: foge → volta atacando → repete
    --------------------------------------------------

    local function RunEscape(LossPct, Preset)
        Running = true
        State.Escaping = true
        LastTrigger = os.clock()
        CycleNow = 0

        VoidShield.Add("escape")
        Grace(2)

        local Target = Preset or FindAttacker()

        if not Target and LastAttacker and os.clock() - LastAttackerAt < 10 and GetPlayerRoot(LastAttacker) then
            Target = LastAttacker
        end

        TargetName = Target and Target.DisplayName or nil

        Say(
            "🏃 AUTO-FUGA",
            Preset
                and ((Preset.DisplayName or "Alguém") .. " tentou te atacar. Fugindo e voltando em cima dele!")
                or ("Perdeu " .. math.floor(LossPct + 0.5) .. "% da vida. Fugindo e voltando em "
                    .. (Target and Target.DisplayName or "NPC") .. "!"),
            YELLOW
        )

        local Ok, Err = pcall(function()
            while Alive and State.Escape and CycleNow < MAX_CYCLES do
                local HRP = GetHRP()

                if not HRP or not IAmAlive() then
                    return
                end

                CycleNow += 1
                Hooks.EscapeCount += 1

                -- quem está me batendo agora tem prioridade
                local Fresh = FindAttacker()

                if Fresh and Fresh ~= Target then
                    Target = Fresh
                    TargetName = Fresh.DisplayName
                end

                RestingInfo()

                local Origin = HRP.CFrame

                if not FleePhase(Origin) then
                    return
                end

                local Result = CounterPhase(Target, Origin)

                if Result == "eu" then
                    return
                end

                if Result == "alvo" then
                    Say("✓ AUTO-FUGA", (Target and Target.DisplayName or "Alvo") .. " foi derrotado.", GREEN)
                    return
                end

                if not RepeatCycles then
                    return
                end

                -- só repete se ainda estou apanhando
                if os.clock() - LastDamageAt > REARM_TIMES[RearmIndex] and Result ~= "cedo" then
                    return
                end

                if Target and not GetPlayerRoot(Target) then
                    return
                end
            end
        end)

        Countering = false

        VoidShield.Remove("escape")
        Grace(1)

        State.Escaping = false
        Running = false
        LastTrigger = os.clock()
        TargetName = nil
        table.clear(Log)

        if Ok then
            ClearFailure("Auto-Fuga")
        else
            SetFailure("Auto-Fuga", tostring(Err))
        end

        RestingInfo()
    end

    --------------------------------------------------
    -- VIGIA
    --------------------------------------------------

    Track(RunService.Heartbeat:Connect(function()
        if not Alive or not State.Escape or Running then
            return
        end

        if not IAmAlive() then
            return
        end

        local Loss = LossInWindow()

        LastLoss = Loss

        if State.FakeRunning or State.RecRunning or State.AntiRunning then
            return
        end

        -- fuga preventiva: alguém começou um golpe virado para mim, bem perto
        if Preempt and LastThreatFrom and os.clock() - LastThreatAt < 0.25 and os.clock() - LastTrigger >= COOLDOWN then
            local From = LastThreatFrom

            LastThreatFrom = nil

            if GetPlayerRoot(From) then
                task.spawn(RunEscape, 0, From)
                return
            end
        end

        if Loss >= LOSS_OPTIONS[LossIndex] and os.clock() - LastTrigger >= COOLDOWN then
            task.spawn(RunEscape, Loss)
        end
    end))

    local InfoAcc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive then
            return
        end

        InfoAcc += dt

        if InfoAcc >= 0.4 then
            InfoAcc = 0
            RestingInfo()
        end
    end))

    --------------------------------------------------
    -- BOTÕES
    --------------------------------------------------

    EscapeToggle.Activated:Connect(function()
        State.Escape = not State.Escape

        EscapeToggle.Text = State.Escape and "AUTO-FUGA • ON" or "AUTO-FUGA • OFF"
        EscapeToggle.BackgroundColor3 = State.Escape and ON_COLOR or OFF_COLOR

        table.clear(Log)

        if not State.Escape then
            ClearFailure("Auto-Fuga")
        end

        RestingInfo()

        if RefreshHub then
            RefreshHub()
        end
    end)

    LossButton.Activated:Connect(function()
        LossIndex = (LossIndex % #LOSS_OPTIONS) + 1
        LossButton.Text = "GATILHO • " .. LOSS_OPTIONS[LossIndex] .. "% da vida"
    end)

    StyleButton.Activated:Connect(function()
        StyleIndex = (StyleIndex % #STYLES) + 1
        StyleButton.Text = "ESTILO • " .. STYLES[StyleIndex]
    end)

    EscTimeButton.Activated:Connect(function()
        EscIndex = (EscIndex % #ESC_TIMES) + 1
        EscTimeButton.Text = "TEMPO FUGINDO • " .. ESC_TIMES[EscIndex] .. "s"
    end)

    CounterButton.Activated:Connect(function()
        CounterIndex = (CounterIndex % #COUNTER_TIMES) + 1
        CounterButton.Text = "ATACAR POR • " .. COUNTER_TIMES[CounterIndex] .. "s"
    end)

    RepeatButton.BackgroundColor3 = ON_COLOR

    RepeatButton.Activated:Connect(function()
        RepeatCycles = not RepeatCycles
        RepeatButton.Text = RepeatCycles and "REPETIR • ON" or "REPETIR • OFF"
        RepeatButton.BackgroundColor3 = RepeatCycles and ON_COLOR or OFF_COLOR
    end)

    RearmButton.Activated:Connect(function()
        RearmIndex = (RearmIndex % #REARM_TIMES) + 1
        RearmButton.Text = "CONTINUAR SE APANHAR NOS ÚLTIMOS • " .. REARM_TIMES[RearmIndex] .. "s"
    end)

    HugButton.Activated:Connect(function()
        HugMode = not HugMode
        HugButton.Text = HugMode and "GRUDAR NO ATACANTE • ON" or "GRUDAR NO ATACANTE • OFF"
        HugButton.BackgroundColor3 = HugMode and ON_COLOR or OFF_COLOR
    end)

    LoopButton.Activated:Connect(function()
        AntiLoop = not AntiLoop
        LoopButton.Text = AntiLoop and "ANTI LOOP-TP • ON" or "ANTI LOOP-TP • OFF"
        LoopButton.BackgroundColor3 = AntiLoop and ON_COLOR or OFF_COLOR
    end)

    PreButton.Activated:Connect(function()
        Preempt = not Preempt
        PreButton.Text = Preempt and "FUGA PREVENTIVA • ON" or "FUGA PREVENTIVA • OFF"
        PreButton.BackgroundColor3 = Preempt and ON_COLOR or OFF_COLOR
    end)

    RestingInfo()
end

--==================================================
-- AUTOFARM (MOBILE E PC) + ANTI-STUN + BOTÕES DO JOGO
--
-- • Alvo: jogadores marcados (o mais próximo vivo); ninguém marcado
--   = NPC. Segue o NPC mesmo fora do mapa (Escudo + Piso Seguro).
-- • Posição: Combat.Place (atrás do alvo, prevendo o movimento).
-- • Ataque: PC = M1 (clique do mouse); Mobile = botão de ataque
--   da tela. Nunca esconde o HUD e nunca equipa ferramenta.
-- • O Anti-Stun liga e desliga junto com o autofarm.
--==================================================

do
    local NORMAL_SPEED = 16
    local NORMAL_JUMP = 50
    local MAX_BELOW = 100

    local STUN_NAMES = {
        "stun", "stunned", "ragdoll", "freeze", "frozen",
        "paralyzed", "nojump", "noattack", "endlag", "slowed",
    }

    local Farms = {}
    local ForceOffAll

    local function SyncFlags()
        State.Farm = State.FarmMobile or State.FarmPC
        State.AntiStun = State.Farm
    end

    --------------------------------------------------
    -- ANTI-STUN
    --------------------------------------------------

    local function IsStunName(Name)
        Name = string.lower(Name)

        for _, Part in ipairs(STUN_NAMES) do
            if string.find(Name, Part, 1, true) then
                return true
            end
        end

        return false
    end

    local StunErrors = 0
    local ScanAcc = 0
    local Fixes = 0

    local function AntiStunStep(Scan)
        local Character = Player.Character

        if not Character then
            return
        end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        local Root = Character:FindFirstChild("HumanoidRootPart")
        local Fixed = 0

        if Humanoid and Humanoid.Health > 0 then
            if Humanoid.PlatformStand then
                Humanoid.PlatformStand = false
                Fixed += 1
            end

            if Humanoid.Sit and not Humanoid.SeatPart then
                Humanoid.Sit = false
                Fixed += 1
            end

            if Humanoid.WalkSpeed < NORMAL_SPEED then
                Humanoid.WalkSpeed = NORMAL_SPEED
                Fixed += 1
            end

            if Humanoid.UseJumpPower and Humanoid.JumpPower < NORMAL_JUMP then
                Humanoid.JumpPower = NORMAL_JUMP
                Fixed += 1
            end

            local HState = Humanoid:GetState()

            if HState == Enum.HumanoidStateType.Physics
                or HState == Enum.HumanoidStateType.Ragdoll
                or HState == Enum.HumanoidStateType.FallingDown then

                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                Fixed += 1
            end
        end

        -- Não solta o personagem quando o próprio Hub travou ele de propósito
        if Root and Root.Anchored and not State.Teleport and not State.AntiRunning then
            Root.Anchored = false
            Fixed += 1
        end

        if Scan then
            for _, Obj in ipairs(Character:GetDescendants()) do
                if Obj:IsA("Motor6D") then
                    if not Obj.Enabled then
                        Obj.Enabled = true
                        Fixed += 1
                    end
                elseif Obj:IsA("BallSocketConstraint") then
                    -- ragdoll (não mexe em BodyVelocity etc. para não cortar o dash do jogo)
                    Obj:Destroy()
                    Fixed += 1
                elseif (Obj:IsA("BoolValue") or Obj:IsA("StringValue") or Obj:IsA("NumberValue"))
                    and IsStunName(Obj.Name) then

                    Obj:Destroy()
                    Fixed += 1
                end
            end

            for Name in pairs(Character:GetAttributes()) do
                if IsStunName(Name) then
                    Character:SetAttribute(Name, nil)
                    Fixed += 1
                end
            end
        end

        Fixes += Fixed
        Hooks.StunFixed = Fixes
    end

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive or not State.AntiStun then
            return
        end

        ScanAcc += dt

        local Scan = ScanAcc >= 0.1

        if Scan then
            ScanAcc = 0
        end

        local Ok, Err = pcall(AntiStunStep, Scan)

        if Ok then
            if StunErrors >= 5 then
                ClearFailure("Anti-Stun")
            end

            StunErrors = 0
        else
            StunErrors += 1

            if StunErrors == 5 then
                SetFailure("Anti-Stun", tostring(Err))
            end

            if StunErrors >= 40 then
                StunErrors = 0

                if ForceOffAll then
                    ForceOffAll("Anti-Stun com erro repetido")
                end
            end
        end
    end))

    --------------------------------------------------
    -- CARTÃO "BOTÕES DO JOGO" (calibrar / testar Ataque, Block, Dash)
    --------------------------------------------------

    local function BuildInputCard(Page, IsPC, Order)
        local InputCard = Card(
            Page,
            "BOTÕES DO JOGO",
            IsPC
                and "Ataque = M1 (clique do mouse). Block e Dash são os botões do jogo: se não forem achados sozinhos, toque em CALIBRAR e depois no botão do jogo."
                or "Ataque, Block e Dash são os botões do jogo. Se não forem achados sozinhos, toque em CALIBRAR e depois no botão na tela do jogo (o Hub fecha por 10 s)."
        )
        InputCard.LayoutOrder = Order

        local Captions = {}
        local Index = 0

        local function RefreshAll()
            for Kind, Cap in pairs(Captions) do
                local Text, Color = GameInput.Describe(Kind, IsPC)
                Cap.Text = Text
                Cap.TextColor3 = Color
            end
        end

        for _, Kind in ipairs({"Attack", "Block", "Dash"}) do
            Index += 1

            local Cap = Caption(InputCard, "", Index * 3)
            Cap.TextWrapped = true
            Cap.Size = UDim2.new(1, 0, 0, 26)
            Captions[Kind] = Cap

            local Row = MakeRow(InputCard, Index * 3 + 1)

            local Calibrate = Button(Row, "CALIBRAR", 1)
            Calibrate.Size = UDim2.new(0.34, -4, 1, 0)

            local Test = Button(Row, "TESTAR", 2)
            Test.Size = UDim2.new(0.33, -4, 1, 0)

            local Clear = Button(Row, "LIMPAR", 3)
            Clear.Size = UDim2.new(0.33, -4, 1, 0)

            Calibrate.Activated:Connect(function()
                GameInput.Calibrate(Kind, RefreshAll)
            end)

            Test.Activated:Connect(function()
                local Called, Ok, Why = pcall(GameInput.Test, Kind, IsPC, "AUTO")

                if Called and Ok then
                    Say("✓ " .. GameInput.Names[Kind], "Botão apertado.", GREEN)
                else
                    Say(
                        "✖ " .. GameInput.Names[Kind],
                        tostring(Called and Why or Ok),
                        RED
                    )
                end
            end)

            Clear.Activated:Connect(function()
                GameInput.ClearCalibration(Kind)
                RefreshAll()
            end)
        end

        RefreshAll()

        local Acc = 0

        Track(RunService.Heartbeat:Connect(function(dt)
            if not Alive or not Main.Visible or not Page.Visible then
                return
            end

            Acc += dt

            if Acc >= 1 then
                Acc = 0
                RefreshAll()
            end
        end))
    end

    --------------------------------------------------
    -- AUTOFARM (UMA FÁBRICA PARA OS DOIS MODOS)
    --------------------------------------------------

    local function CreateFarm(Mode)
        local IsPC = Mode == "PC"
        local Key = IsPC and "FarmPC" or "FarmMobile"
        local Page = IsPC and Pages.FarmPC or Pages.FarmMobile
        local Label = IsPC and "PC" or "MOBILE"
        local Interval = IsPC and 0.01 or 0.02
        local METHODS = IsPC and {"AUTO", "SINAL"} or {"AUTO", "TOQUE", "CLIQUE", "SINAL"}
        local MethodIndex = 1

        local DISTANCES = {1.5, 2.2, 3, 4}
        local DistIndex = 2
        local Behind = DISTANCES[DistIndex]

        local AimCam = true
        local Targets = {}
        local Gen = 0
        local Conns = {}
        local ErrCount = 0
        local AttackFails = 0
        local NoTargetSince = nil
        local NoTargetNotified = false
        local CurrentLabel = nil
        local CurrentWhy = nil
        local FlashUntil = 0
        local FlashToken = 0
        local Stop
        local StickyTarget = nil
        local FollowOut = true

        -- modo Tekola
        local SAFE_HEIGHT = 600
        local UseTool = true
        local AntiStrip = true
        local SafeHover = true
        local VoidGuard = true
        local LastStrip = 0

        ----------------------------------------------
        -- INTERFACE
        ----------------------------------------------

        local FarmCard = Card(
            Page,
            "AUTOFARM • " .. Label,
            IsPC
                and "AUTOFARM no estilo Tekola: teleporta atrás do alvo sem parar (a cada quadro), mira a câmera, equipa a ferramenta e ataca com o M1. Sem ninguém marcado, farma o NPC. Anti-void e anti-trava incluídos. Liga e desliga junto com o Anti-Stun."
                or "AUTOFARM no estilo Tekola: teleporta atrás do alvo sem parar (a cada quadro), mira a câmera, equipa a ferramenta e aperta o botão de ataque do jogo. Sem ninguém marcado, farma o NPC. Anti-void e anti-trava incluídos. Liga e desliga junto com o Anti-Stun."
        )
        FarmCard.LayoutOrder = 1

        local Toggle = Button(FarmCard, "AUTOFARM • OFF", 3)
        local DistButton = Button(FarmCard, "DISTÂNCIA ATRÁS • " .. Behind .. " studs", 4)
        local AimButton = Button(FarmCard, "MIRAR CÂMERA • ON", 5)
        AimButton.BackgroundColor3 = ON_COLOR
        local MethodButton = Button(FarmCard, "ATAQUE • AUTO", 6)
        local FollowButton = Button(FarmCard, "SEGUIR FORA DO MAPA • ON", 7)
        FollowButton.BackgroundColor3 = ON_COLOR
        local ToolButton = Button(FarmCard, "USAR FERRAMENTA • ON", 8)
        ToolButton.BackgroundColor3 = ON_COLOR
        local StripButton = Button(FarmCard, "ANTI-TRAVA • ON", 9)
        StripButton.BackgroundColor3 = ON_COLOR
        local HoverButton = Button(FarmCard, "SEM ALVO: ALTURA SEGURA • ON", 10)
        HoverButton.BackgroundColor3 = ON_COLOR
        local VoidButton = Button(FarmCard, "ANTI-VOID • ON", 11)
        VoidButton.BackgroundColor3 = ON_COLOR

        local StunCard = Card(
            Page,
            "ANTI-STUN",
            "Remove stun, ragdoll e travas do seu personagem. Liga e desliga junto com o autofarm."
        )
        StunCard.LayoutOrder = 2

        local StunInfo = Caption(StunCard, "● Desligado", 3)
        StunInfo.TextColor3 = MUTED_TEXT

        local InfoCard, _, Info = Card(Page, "ESTADO", "● Desligado")
        InfoCard.LayoutOrder = 3
        Info.Font = Enum.Font.GothamBold
        Info.TextColor3 = MUTED_TEXT

        BuildInputCard(Page, IsPC, 4)

        local List = CreatePlayerList(Page, "ALVOS — AUTOFARM " .. Label, Targets, 5)

        for _, Other in ipairs(Players:GetPlayers()) do
            List.Add(Other)
        end

        local function SetInfo(Text, Color)
            Info.Text = Text
            Info.TextColor3 = Color
        end

        local function Refresh()
            if State[Key] and State.AntiStun then
                StunInfo.Text = "● Ligado • " .. Hooks.StunFixed
                    .. (Hooks.StunFixed == 1 and " correção" or " correções")
                StunInfo.TextColor3 = GREEN
            else
                StunInfo.Text = "● Desligado"
                StunInfo.TextColor3 = MUTED_TEXT
            end

            if os.clock() < FlashUntil then
                return
            end

            if State[Key] then
                if State.Escaping then
                    SetInfo("● Pausado • Auto-Fuga em ação", YELLOW)
                elseif CurrentLabel then
                    SetInfo("● Farmando • " .. CurrentLabel, GREEN)
                else
                    SetInfo("● Sem alvo • " .. (CurrentWhy or "aguardando"), YELLOW)
                end
            else
                SetInfo("● Desligado", MUTED_TEXT)
            end
        end

        local function Flash(Text, Color)
            FlashToken += 1
            local My = FlashToken

            FlashUntil = os.clock() + 2.5
            SetInfo(Text, Color)

            task.delay(2.6, function()
                if Alive and My == FlashToken then
                    Refresh()
                end
            end)
        end

        ----------------------------------------------
        -- ESCOLHA DO ALVO
        ----------------------------------------------

        local function PickTarget(MyRoot)
            local Marked = 0
            local Best
            local BestLabel
            local BestPlayer
            local BestDistance = math.huge
            local TopY = GetPlatformTopY()

            for Other in pairs(Targets) do
                Marked += 1

                local Root = GetPlayerRoot(Other)

                if Root and (FollowOut or not (TopY and Root.Position.Y < TopY - MAX_BELOW)) then
                    local Distance = (Root.Position - MyRoot.Position).Magnitude
                    local Score = Distance

                    -- fica no mesmo alvo (não fica trocando) e prefere o mais machucado
                    if Other == StickyTarget then
                        Score -= 15
                    end

                    local TargetHum = Other.Character and Other.Character:FindFirstChildOfClass("Humanoid")

                    if TargetHum and TargetHum.Health > 0 then
                        Score += (TargetHum.Health / math.max(TargetHum.MaxHealth, 1)) * 12
                    end

                    if Score < BestDistance then
                        BestDistance = Score
                        Best = Root
                        BestLabel = Other.DisplayName
                        BestPlayer = Other
                    end
                end
            end

            if Best then
                StickyTarget = BestPlayer
                return Best, BestLabel
            end

            -- Marcou jogadores mas nenhum está disponível: espera (não vai ao NPC)
            if Marked > 0 then
                return nil, "marcados indisponíveis"
            end

            -- NPC: segue em qualquer lugar (mesmo fora do mapa)
            local Torso = GetNPCTorso()

            if Torso then
                return Torso, "NPC"
            end

            return nil, "NPC não encontrado"
        end

        ----------------------------------------------
        -- POSICIONAMENTO (todo frame)
        ----------------------------------------------

        local function SpawnPos()
            local Spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)

            if Spawn then
                return Spawn.Position + Vector3.new(0, 5, 0)
            end

            return Vector3.new(0, 20, 0)
        end

        local function VoidLimit()
            local TopY = GetPlatformTopY()

            if TopY then
                return TopY - 120
            end

            return -50
        end

        -- Anti-void: caiu do mapa (ou foi longe demais) = volta para o spawn.
        -- Não atrapalha quando o alvo também está lá fora e "Seguir fora do mapa" está ligado.
        local function VoidCheck(MyRoot, Target)
            if not VoidGuard or State.Invisible then
                return false
            end

            local P = MyRoot.Position
            local Limit = VoidLimit()
            local Far = math.abs(P.X) > 50000 or math.abs(P.Z) > 50000

            if P.Y >= Limit and not Far then
                return false
            end

            if FollowOut and Target then
                local T = Target.Position

                if T.Y < Limit or math.abs(T.X) > 50000 or math.abs(T.Z) > 50000 then
                    return false
                end
            end

            Grace(1)
            MyRoot.AssemblyLinearVelocity = Vector3.zero
            MyRoot.AssemblyAngularVelocity = Vector3.zero
            MyRoot.CFrame = CFrame.new(SpawnPos())

            return true
        end

        -- Anti-trava (Tekola): tira forças e travas físicas do seu personagem
        local function StripControl()
            local Character = Player.Character

            if not Character then
                return
            end

            local Hum = Character:FindFirstChildOfClass("Humanoid")

            if Hum then
                Hum.PlatformStand = false
                Hum.Sit = false
            end

            for _, Obj in ipairs(Character:GetDescendants()) do
                if Obj:IsA("BodyMover") or Obj:IsA("LinearVelocity") or Obj:IsA("VectorForce")
                    or Obj:IsA("AlignPosition") then
                    Obj:Destroy()
                end
            end
        end

        local function Hold()
            if not State[Key] then
                return
            end

            if State.FakeRunning
                or State.RecRunning
                or State.AntiRunning
                or State.Teleport
                or State.Escaping then
                return
            end

            local MyRoot = GetPlayerRoot(Player)

            if not MyRoot then
                CurrentLabel = nil
                CurrentWhy = "sem personagem"
                return
            end

            local Target, Result = PickTarget(MyRoot)
            local Now = os.clock()

            if AntiStrip and Now - LastStrip > 0.05 then
                LastStrip = Now
                pcall(StripControl)
            end

            if not Target then
                CurrentLabel = nil
                CurrentWhy = Result

                if VoidCheck(MyRoot, nil) then
                    return
                end

                -- sem alvo: espera lá em cima, em segurança (Tekola)
                if SafeHover then
                    local P = MyRoot.Position

                    if math.abs(P.Y - SAFE_HEIGHT) > 3 then
                        Grace(0.8)
                    end

                    MyRoot.AssemblyLinearVelocity = Vector3.zero
                    MyRoot.CFrame = CFrame.new(P.X, SAFE_HEIGHT, P.Z) * (MyRoot.CFrame - MyRoot.CFrame.Position)
                end

                if not NoTargetSince then
                    NoTargetSince = Now
                end

                if not NoTargetNotified and Now - NoTargetSince > 8 then
                    NoTargetNotified = true

                    Say("⚠ AUTOFARM", "Sem alvo há 8 s (" .. tostring(Result) .. ").", YELLOW)
                end

                return
            end

            NoTargetSince = nil
            NoTargetNotified = false
            CurrentLabel = Result
            CurrentWhy = nil

            -- Salto grande: o Anti-Fakeout não pode reagir ao próprio autofarm
            if (Target.Position - MyRoot.Position).Magnitude > 60 then
                Grace(0.8)
            end

            if VoidCheck(MyRoot, Target) then
                return
            end

            do
                local P = MyRoot.Position

                if P.X ~= P.X or P.Y ~= P.Y or P.Z ~= P.Z or P.Y < -1000000 then
                    ReturnToPlatform()
                    return
                end
            end

            Combat.Place(Target, Behind)
            MyRoot.AssemblyAngularVelocity = Vector3.zero

            if AimCam then
                local Cam = workspace.CurrentCamera

                if Cam then
                    Cam.CFrame = CFrame.new(Cam.CFrame.Position, Target.Position)
                end
            end
        end

        local function SafeHold()
            local Ok, Err = pcall(Hold)

            if Ok then
                ErrCount = 0
                return
            end

            ErrCount += 1

            if ErrCount == 5 then
                SetFailure("Autofarm", tostring(Err))
            end

            if ErrCount >= 60 and Stop then
                ErrCount = 0
                Stop()
                Say("✖ AUTOFARM", "Desligado por erro repetido.", RED)
            end
        end

        ----------------------------------------------
        -- ATAQUE (loop separado)
        ----------------------------------------------

        local function StartAttackLoop()
            Gen += 1
            local Mine = Gen

            task.spawn(function()
                while Alive and Mine == Gen and State[Key] do
                    task.wait(Interval)

                    if State[Key]
                        and CurrentLabel
                        and not State.Escaping
                        and not State.Blocking
                        and not State.FakeRunning
                        and not State.RecRunning
                        and not State.AntiRunning
                        and not State.Teleport
                        and GetPlayerRoot(Player) then

                        -- equipa a ferramenta e ativa (Tekola)
                        if UseTool then
                            pcall(function()
                                local Character = Player.Character
                                local Hum = Character and Character:FindFirstChildOfClass("Humanoid")
                                local Tool = Character and Character:FindFirstChildOfClass("Tool")

                                if not Tool then
                                    local Pack = Player:FindFirstChild("Backpack")

                                    Tool = Pack and Pack:FindFirstChildOfClass("Tool")

                                    if Tool and Hum then
                                        Hum:EquipTool(Tool)
                                    end
                                elseif Tool.Parent == Character then
                                    Tool:Activate()
                                end
                            end)
                        end

                        local Called, Ok, Why = pcall(
                            GameInput.Attack,
                            Mode,
                            METHODS[MethodIndex]
                        )

                        if Called and Ok then
                            if AttackFails >= 6 then
                                ClearFailure("Autofarm")
                            end

                            AttackFails = 0
                        else
                            AttackFails += 1

                            if AttackFails == 6 then
                                SetFailure(
                                    "Autofarm",
                                    "ataque: " .. tostring(Called and Why or Ok)
                                )
                            end
                        end
                    end
                end
            end)
        end

        ----------------------------------------------
        -- LIGAR / DESLIGAR
        ----------------------------------------------

        local function Release()
            for _, Conn in ipairs(Conns) do
                pcall(function()
                    Conn:Disconnect()
                end)
            end

            table.clear(Conns)
        end

        Stop = function()
            State[Key] = false
            SyncFlags()
            Gen += 1
            Release()

            if not State.Farm then
                VoidShield.Remove("farm")
            end

            CurrentLabel = nil
            CurrentWhy = nil
            AttackFails = 0
            ErrCount = 0

            Toggle.Text = "AUTOFARM • OFF"
            Toggle.BackgroundColor3 = OFF_COLOR

            ClearFailure("Autofarm")
            Grace(0.8)
            Refresh()

            if RefreshHub then
                RefreshHub()
            end
        end

        local function Start()
            local Block

            if State.Teleport then
                Block = "DESLIGUE O TELEPORTE NPC"
            elseif State.FarmMobile or State.FarmPC then
                Block = "DESLIGUE O OUTRO AUTOFARM"
            end

            if Block then
                Toggle.Text = Block
                Say("⚠ CONFLITO", Block .. " antes de ligar o Autofarm.", YELLOW)

                task.delay(1.6, function()
                    if Alive and not State[Key] then
                        Toggle.Text = "AUTOFARM • OFF"
                    end
                end)

                return
            end

            State[Key] = true
            SyncFlags()
            AttackFails = 0
            ErrCount = 0
            NoTargetSince = nil
            NoTargetNotified = false
            Grace(0.8)

            -- Protege do void se o NPC sair do mapa
            VoidShield.Add("farm")

            Toggle.Text = "AUTOFARM • ON"
            Toggle.BackgroundColor3 = ON_COLOR

            Release()

            Conns[1] = RunService.Heartbeat:Connect(SafeHold)
            Conns[2] = RunService.Stepped:Connect(SafeHold)
            Conns[3] = RunService.RenderStepped:Connect(SafeHold)

            pcall(function()
                Conns[4] = RunService.PreSimulation:Connect(SafeHold)
            end)

            for _, Conn in ipairs(Conns) do
                Track(Conn)
            end

            StartAttackLoop()
            Refresh()

            if RefreshHub then
                RefreshHub()
            end
        end

        Toggle.Activated:Connect(function()
            if State[Key] then
                Stop()
            else
                Start()
            end
        end)

        DistButton.Activated:Connect(function()
            DistIndex = (DistIndex % #DISTANCES) + 1
            Behind = DISTANCES[DistIndex]
            DistButton.Text = "DISTÂNCIA ATRÁS • " .. Behind .. " studs"
        end)

        AimButton.Activated:Connect(function()
            AimCam = not AimCam

            AimButton.Text = AimCam and "MIRAR CÂMERA • ON" or "MIRAR CÂMERA • OFF"
            AimButton.BackgroundColor3 = AimCam and ON_COLOR or OFF_COLOR
        end)

        FollowButton.Activated:Connect(function()
            FollowOut = not FollowOut

            FollowButton.Text = FollowOut and "SEGUIR FORA DO MAPA • ON" or "SEGUIR FORA DO MAPA • OFF"
            FollowButton.BackgroundColor3 = FollowOut and ON_COLOR or OFF_COLOR
        end)

        local function Flip(Button_, Name, Get, Set)
            Button_.Activated:Connect(function()
                Set(not Get())

                Button_.Text = Name .. " • " .. (Get() and "ON" or "OFF")
                Button_.BackgroundColor3 = Get() and ON_COLOR or OFF_COLOR
            end)
        end

        Flip(ToolButton, "USAR FERRAMENTA", function() return UseTool end, function(V) UseTool = V end)
        Flip(StripButton, "ANTI-TRAVA", function() return AntiStrip end, function(V) AntiStrip = V end)
        Flip(HoverButton, "SEM ALVO: ALTURA SEGURA", function() return SafeHover end, function(V) SafeHover = V end)
        Flip(VoidButton, "ANTI-VOID", function() return VoidGuard end, function(V) VoidGuard = V end)

        MethodButton.Activated:Connect(function()
            MethodIndex = (MethodIndex % #METHODS) + 1
            MethodButton.Text = "ATAQUE • " .. METHODS[MethodIndex]
        end)

        Farms[Key] = {Key = Key, Stop = Stop, Refresh = Refresh}

        Refresh()
    end

    CreateFarm("MOBILE")
    CreateFarm("PC")

    ForceOffAll = function(Reason)
        for _, Farm in pairs(Farms) do
            if State[Farm.Key] then
                Farm.Stop()
            end
        end

        Say("✖ AUTOFARM", tostring(Reason), RED)
    end

    local RefreshAcc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive then
            return
        end

        RefreshAcc += dt

        if RefreshAcc < 0.3 then
            return
        end

        RefreshAcc = 0

        for _, Farm in pairs(Farms) do
            Farm.Refresh()
        end
    end))
end

--==================================================
-- AUTO-BLOCK (v6 adaptado ao Hub)
-- Só bloqueia o ataque de:
--   • o DUMMY (NPC enemyforyose)
--   • jogadores MARCADOS na lista
-- Sem Key, sem dash, sem "block ao apanhar".
--==================================================

;(function()
    local Page = Pages.AutoBlock
    local Targets = {}
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    ------------------------------------------------
    -- AJUSTES
    ------------------------------------------------

    local Cfg = {
        Dist = 8,        -- studs: só reage a quem estiver até aqui
        React = 0,       -- s: espera antes de apertar o Block
        Dummy = true,    -- bloquear o ataque do dummy
    }

    local DIST_MIN = 3
    local DIST_MAX = 15
    local REACT_MAX = 0.30

    local CLOSE_DIST = 5          -- até aqui ignora o ângulo (colado em você)
    local FACING_MIN = -0.3
    local THREAT_WINDOW = 0.8     -- quanto tempo uma animação de ataque conta como ameaça
    local MY_ATTACK_WINDOW = 0.8  -- reações logo após o SEU ataque são ignoradas
    local HOLD_MIN = 0.25         -- segura o block pelo menos isso
    local HOLD_MAX = 2            -- e no máximo isso
    local NO_THREAT_RELEASE = 0.2 -- solta se ficar isso sem ameaça

    local ALLOW_KEY_ON_MOBILE = false
    local BLOCK_ACTION_NAME = ""  -- força o nome da ação do Block, se precisar

    local IGNORE_WORDS = {"block", "react", "idle", "walk", "run", "jump", "fall", "climb", "swim", "sit", "emote", "equip", "unequip", "stun", "ragdoll", "knock", "getup", "dash", "sprint", "stagger", "flinch", "damage", "recoil"}
    local NOT_MY_ATTACK = {"react", "stun", "knock", "ragdoll", "getup", "stagger", "flinch", "damage", "sprint", "dash", "idle", "walk", "run", "jump", "fall", "climb", "swim", "sit", "emote", "equip", "unequip"}
    local DUMMY_SKIP = {"death", "dead", "spawn", "intro", "taunt", "dance", "pose"}
    local EXTRA_IGNORE = {}   -- ex.: {"taunt", "pose"}
    local EXTRA_ATTACKS = {}  -- ex.: {"swing"}

    ------------------------------------------------
    -- PAINEL
    ------------------------------------------------

    local HeadCard = Card(
        Page,
        "AUTO-BLOCK",
        "Segura o Block sozinho quando o DUMMY ou um jogador MARCADO na lista te ataca. Não bloqueia mais nada."
    )
    HeadCard.LayoutOrder = 1

    local MasterButton = Button(HeadCard, "AUTO-BLOCK • OFF", 3)

    local StateCard, _, StateLabel = Card(Page, "ESTADO", "● Desligado")
    StateCard.LayoutOrder = 2
    StateLabel.Font = Enum.Font.GothamBold
    StateLabel.TextColor3 = MUTED_TEXT

    local NoteLabel = Caption(StateCard, "", 3)

    local List = CreatePlayerList(Page, "JOGADORES MARCADOS — AUTO-BLOCK", Targets, 3)

    for _, Other in ipairs(Players:GetPlayers()) do
        List.Add(Other)
    end

    local function ToggleRow(Parent, Order, Text, Key)
        local B = Button(Parent, "", Order)

        local function Paint()
            local On = Cfg[Key]

            B.Text = Text .. " • " .. (On and "ON" or "OFF")
            B.BackgroundColor3 = On and ON_COLOR or OFF_COLOR
        end

        Paint()

        B.Activated:Connect(function()
            Cfg[Key] = not Cfg[Key]
            Paint()
        end)

        return B
    end

    -- − [valor] + com repetição ao segurar
    local function StepRow(Parent, Order, Get, Set, Min, Max, Step, Format)
        local Row = MakeRow(Parent, Order)

        local Minus = Button(Row, "−", 1)
        Minus.Size = UDim2.fromOffset(52, 38)

        local Label = Instance.new("TextLabel")
        Label.Parent = Row
        Label.LayoutOrder = 2
        Label.Size = UDim2.new(1, -(52 * 2 + 12), 1, 0)
        Label.BackgroundColor3 = Color3.fromRGB(25, 25, 31)
        Label.BackgroundTransparency = 0.15
        Label.BorderSizePixel = 0
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 12
        Label.TextColor3 = Color3.fromRGB(235, 235, 240)
        Label.ZIndex = 17

        local LabelCorner = Instance.new("UICorner")
        LabelCorner.CornerRadius = UDim.new(0, 8)
        LabelCorner.Parent = Label

        local Plus = Button(Row, "+", 3)
        Plus.Size = UDim2.fromOffset(52, 38)

        local function Paint()
            Label.Text = Format(Get())
        end

        local function Change(Sign)
            local Value = Get() + Sign * Step
            Value = math.floor(Value / Step + 0.5) * Step
            Value = math.clamp(Value, Min, Max)
            Value = math.floor(Value * 1000 + 0.5) / 1000
            Set(Value)
            Paint()
        end

        local function Hook(B, Sign)
            local Token = 0

            B.MouseButton1Down:Connect(function()
                Token += 1

                local Mine = Token

                Change(Sign)

                task.spawn(function()
                    task.wait(0.45)

                    while Alive and Token == Mine and B.Parent do
                        Change(Sign)
                        task.wait(0.09)
                    end
                end)
            end)

            local function Stop()
                Token += 1
            end

            B.MouseButton1Up:Connect(Stop)
            B.MouseLeave:Connect(Stop)
        end

        Hook(Minus, -1)
        Hook(Plus, 1)
        Paint()
    end

    local TriggerCard = Card(
        Page,
        "O QUE BLOQUEIA",
        "Jogadores: só os marcados na lista acima (ninguém marcado = nenhum jogador). Dummy: o NPC do jogo."
    )
    TriggerCard.LayoutOrder = 4

    ToggleRow(TriggerCard, 3, "BLOQUEAR O DUMMY", "Dummy")

    local AdjustCard = Card(
        Page,
        "ALCANCE E REAÇÃO",
        "Alcance: distância máxima do atacante para o golpe contar. Reação: espera antes de apertar o Block (0 = instantâneo)."
    )
    AdjustCard.LayoutOrder = 5

    StepRow(AdjustCard, 3,
        function() return Cfg.Dist end,
        function(V) Cfg.Dist = V end,
        DIST_MIN, DIST_MAX, 1,
        function(V) return "ALCANCE • " .. math.floor(V + 0.5) .. " studs" end
    )

    StepRow(AdjustCard, 4,
        function() return Cfg.React end,
        function(V) Cfg.React = V end,
        0, REACT_MAX, 0.02,
        function(V) return string.format("REAÇÃO • %.2f s", V) end
    )

    local InputCard = Card(
        Page,
        "BOTÃO BLOCK DO JOGO",
        "O Hub acha o Block sozinho. Se não bloquear, toque em CALIBRAR e aperte o botão de Block do jogo; use TESTAR para ver se funciona."
    )
    InputCard.LayoutOrder = 6

    local InputInfo = Instance.new("TextLabel")
    InputInfo.Parent = InputCard
    InputInfo.LayoutOrder = 3
    InputInfo.Size = UDim2.new(1, 0, 0, 0)
    InputInfo.AutomaticSize = Enum.AutomaticSize.Y
    InputInfo.BackgroundTransparency = 1
    InputInfo.Font = Enum.Font.GothamBold
    InputInfo.TextSize = 11
    InputInfo.TextWrapped = true
    InputInfo.TextXAlignment = Enum.TextXAlignment.Left
    InputInfo.TextColor3 = MUTED_TEXT
    InputInfo.Text = ""
    InputInfo.ZIndex = 16

    local InputRow = MakeRow(InputCard, 4)
    local CalButton = Button(InputRow, "CALIBRAR", 1)
    CalButton.Size = UDim2.new(1 / 3, -4, 1, 0)
    local TestButton = Button(InputRow, "TESTAR", 2)
    TestButton.Size = UDim2.new(1 / 3, -4, 1, 0)
    local ClearButton = Button(InputRow, "LIMPAR", 3)
    ClearButton.Size = UDim2.new(1 / 3, -4, 1, 0)

    ------------------------------------------------
    -- ESTADO
    ------------------------------------------------

    local Enabled = false
    local Blocking = false
    local ReleaseNow = false
    local Scheduled = false
    local LastThreat = 0
    local LastMyAttack = 0
    local Blocks = 0
    local PressFails = 0
    local MethodMisses = 0
    local LastReason = "nenhuma ameaça ainda"
    local LastNoteText = ""
    local LastInput = nil
    local CalibratedAction = nil
    local Calibrating = false
    local GoodMethod, CurrentMethod = nil, nil
    local PressedAction, PressedInfo = nil, nil

    local Threats = {}
    local Seen = setmetatable({}, {__mode = "k"})
    local Connected = setmetatable({}, {__mode = "k"})
    local DamagedAt = setmetatable({}, {__mode = "k"})
    local PlayerConns = {}
    local PlayerEnts = {}

    local DummyEnt = {Kind = "dummy", Name = "DUMMY"}
    local DummyModel = nil
    local DummyAnimator = nil
    local DummyConns = {}

    local function Note(Text)
        if Text ~= LastNoteText then
            LastNoteText = Text
            NoteLabel.Text = "↳ " .. Text
        end
    end

    ------------------------------------------------
    -- ALVOS: jogador marcado ou dummy
    ------------------------------------------------

    local function EntOf(P)
        local E = PlayerEnts[P]

        if not E then
            E = {Kind = "player", Player = P, Name = P.Name}
            PlayerEnts[P] = E
        end

        return E
    end

    local function CharOf(E)
        if E.Kind == "dummy" then
            return DummyModel
        end

        return E.Player.Character
    end

    local function IsValid(E)
        if E.Kind == "dummy" then
            return DummyModel ~= nil and DummyModel.Parent ~= nil
        end

        return E.Player.Parent == Players
    end

    local function Allowed(E)
        if E.Kind == "dummy" then
            return Cfg.Dummy
        end

        return E.Player ~= Player and Targets[E.Player] == true
    end

    local function CountTargets()
        local N = 0

        for Chosen in pairs(Targets) do
            if Chosen.Parent == Players then
                N += 1
            end
        end

        return N
    end

    local function RootOfChar(Char)
        return Char and (
            Char:FindFirstChild("HumanoidRootPart")
            or Char:FindFirstChild("Torso")
            or Char:FindFirstChild("UpperTorso")
        )
    end

    local function RootOf(E)
        return RootOfChar(CharOf(E))
    end

    ------------------------------------------------
    -- ANIMAÇÕES
    ------------------------------------------------

    local AnimInfo = {}
    local AnimFolder = ReplicatedStorage:FindFirstChild("Animations")

    if AnimFolder then
        for _, Anim in ipairs(AnimFolder:GetDescendants()) do
            if Anim:IsA("Animation") then
                AnimInfo[Anim.AnimationId] = {
                    Name = Anim.Name,
                    Block = string.find(string.lower(Anim.Name), "block") ~= nil,
                    Sub = Anim.Parent ~= AnimFolder,
                }
            end
        end
    end

    local function TrackName(AnimTrack)
        return (AnimTrack.Animation and AnimTrack.Animation.Name) or AnimTrack.Name
    end

    local function IsBlockTrack(AnimTrack)
        local Id = AnimTrack.Animation and AnimTrack.Animation.AnimationId
        local Info = Id and AnimInfo[Id]

        if Info then
            return Info.Block
        end

        return string.find(string.lower(TrackName(AnimTrack)), "block") ~= nil
    end

    local function IsActionPriority(Priority)
        return Priority == Enum.AnimationPriority.Action
            or Priority == Enum.AnimationPriority.Action2
            or Priority == Enum.AnimationPriority.Action3
            or Priority == Enum.AnimationPriority.Action4
    end

    local function IsHitName(Name)
        return string.find(Name, "^hit") ~= nil or string.find(Name, "hit%d") ~= nil
    end

    local function HasWord(Name, Words)
        for _, Word in ipairs(Words) do
            if string.find(Name, Word) then
                return true
            end
        end

        return false
    end

    -- "attack" | "ambiguous" | "ignore" | nil
    local function Classify(AnimTrack, IsDummy)
        local Id = AnimTrack.Animation and AnimTrack.Animation.AnimationId

        if not Id or IsBlockTrack(AnimTrack) then
            return nil
        end

        local Info = AnimInfo[Id]
        local Name = Info and Info.Name or TrackName(AnimTrack)
        local N = string.lower(Name)

        if HasWord(N, EXTRA_ATTACKS) then
            return "attack", Name
        end

        if HasWord(N, IGNORE_WORDS) then
            return "ignore", Name
        end

        if HasWord(N, EXTRA_IGNORE) then
            return "ignore", Name
        end

        if IsHitName(N) then
            return "ambiguous", Name
        end

        if Info and Info.Sub then
            return "attack", Name
        end

        if IsActionPriority(AnimTrack.Priority) then
            return "ambiguous", Name .. "(?)"
        end

        -- dummy: golpe sem prioridade de ação (não em loop) também conta
        if IsDummy and not AnimTrack.Looped and not HasWord(N, DUMMY_SKIP) then
            return "ambiguous", Name .. "(?)"
        end

        return nil
    end

    local function Measure(E, MinFacing)
        local MyRoot = RootOfChar(Player.Character)
        local Root = RootOf(E)

        if not MyRoot or not Root then
            return nil
        end

        local Diff = MyRoot.Position - Root.Position
        local Dist = Diff.Magnitude
        local Facing = Dist <= CLOSE_DIST
            or (Dist > 0.1 and Root.CFrame.LookVector:Dot(Diff.Unit) > (MinFacing or FACING_MIN))

        return Dist, Facing
    end

    local function IAmBlockingAnim()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")

        if not Animator then
            return false
        end

        for _, AnimTrack in ipairs(Animator:GetPlayingAnimationTracks()) do
            if IsBlockTrack(AnimTrack) then
                return true
            end
        end

        return false
    end

    ------------------------------------------------
    -- AÇÃO DO BLOCK + MÉTODOS DE APERTAR
    ------------------------------------------------

    local function FindBlockAction()
        local Ok, Actions = pcall(function()
            return ContextActionService:GetAllBoundActionInfo()
        end)

        if not Ok or not Actions then
            return nil
        end

        if BLOCK_ACTION_NAME ~= "" and Actions[BLOCK_ACTION_NAME] then
            return BLOCK_ACTION_NAME, Actions[BLOCK_ACTION_NAME]
        end

        if CalibratedAction and Actions[CalibratedAction] then
            return CalibratedAction, Actions[CalibratedAction]
        end

        for Name, Info in pairs(Actions) do
            local N = string.lower(Name)

            if string.find(N, "block") or string.find(N, "guard")
                or string.find(N, "defend") or string.find(N, "parry") then
                return Name, Info
            end
        end

        return nil
    end

    local function KeyOfAction(Info)
        for _, Kind in ipairs((Info and Info.inputTypes) or {}) do
            if typeof(Kind) == "EnumItem" and Kind.EnumType == Enum.KeyCode
                and not string.find(Kind.Name, "^Button")
                and not string.find(Kind.Name, "^Thumbstick") then
                return Kind
            end
        end

        return nil
    end

    local M_KEY = {Name = "tecla", F = function(Down, Action, Info)
        local Key = KeyOfAction(Info)

        if not Key or not VIM then
            return false
        end

        return (pcall(function()
            VIM:SendKeyEvent(Down, Key, false, game)
        end))
    end}

    local M_CALL = {Name = "callfunction", F = function(Down, Action)
        if not LastInput then
            return false
        end

        return (pcall(function()
            ContextActionService:CallFunction(
                Action,
                Down and Enum.UserInputState.Begin or Enum.UserInputState.End,
                LastInput
            )
        end))
    end}

    local M_CONN = {Name = "getconnections", F = function(Down, Action)
        if typeof(getconnections) ~= "function" then
            return false
        end

        local OkB, Btn = pcall(function()
            return ContextActionService:GetButton(Action)
        end)

        if not (OkB and Btn) then
            return false
        end

        local Signal = Down and Btn.MouseButton1Down or Btn.MouseButton1Up
        local OkC, Conns = pcall(getconnections, Signal)

        if not (OkC and typeof(Conns) == "table") then
            return false
        end

        local N = 0

        for _, Conn in ipairs(Conns) do
            pcall(function()
                Conn:Fire()
            end)

            N += 1
        end

        return N > 0
    end}

    -- guarda a posição do toque virtual para soltar no mesmo lugar,
    -- mesmo que o jogo já tenha removido o botão
    local LastTouch = nil

    local M_TOUCH = {Name = "toque", F = function(Down, Action)
        local X, Y

        if Down then
            local OkB, Btn = pcall(function()
                return ContextActionService:GetButton(Action)
            end)

            if not (OkB and Btn) then
                return false
            end

            local Center = Btn.AbsolutePosition + (Btn.AbsoluteSize / 2)
            local Inset = GuiService:GetGuiInset()

            X, Y = Center.X, Center.Y + Inset.Y
            LastTouch = {X, Y}
        else
            if not LastTouch then
                return false
            end

            X, Y = LastTouch[1], LastTouch[2]
            LastTouch = nil
        end

        if not VIM then
            return false
        end

        return (pcall(function()
            VIM:SendTouchEvent(1, Down and 0 or 2, X, Y)
        end))
    end}

    local Order

    if IsMobile then
        Order = {M_CALL, M_CONN, M_TOUCH}

        if ALLOW_KEY_ON_MOBILE then
            table.insert(Order, M_KEY)
        end
    else
        Order = {M_KEY, M_CALL, M_CONN, M_TOUCH}
    end

    -- Down = true aperta, false solta. Retorna (nome do método) ou (nil, motivo)
    local function Press(Down)
        if not Down then
            if CurrentMethod and PressedAction then
                pcall(CurrentMethod.F, false, PressedAction, PressedInfo)
            end

            CurrentMethod = nil
            PressedAction, PressedInfo = nil, nil

            return "solto", ""
        end

        local Action, Info = FindBlockAction()

        if not Action then
            return nil, "acao nao encontrada"
        end

        PressedAction, PressedInfo = Action, Info

        if GoodMethod then
            local M = GoodMethod

            if M.F(true, Action, Info) then
                CurrentMethod = M

                task.delay(0.45, function()
                    if Blocking and GoodMethod == M then
                        if IAmBlockingAnim() then
                            MethodMisses = 0
                        else
                            MethodMisses += 1

                            if MethodMisses >= 2 then
                                GoodMethod = nil
                                MethodMisses = 0
                            end
                        end
                    end
                end)

                return M.Name, Action
            end

            GoodMethod = nil
        end

        for _, M in ipairs(Order) do
            if M.F(true, Action, Info) then
                local T0 = os.clock()

                while os.clock() - T0 < 0.4 do
                    if IAmBlockingAnim() then
                        GoodMethod, CurrentMethod = M, M

                        return M.Name, Action
                    end

                    RunService.Heartbeat:Wait()
                end

                M.F(false, Action, Info)
            end
        end

        return nil, "nenhum metodo bloqueou (acao: " .. Action .. ")"
    end

    ------------------------------------------------
    -- BLOQUEAR (segura, confirma, solta)
    ------------------------------------------------

    local function CanStart()
        if not Enabled or Blocking then
            return false
        end

        if State.Escaping or State.FakeRunning or State.RecRunning or State.AntiRunning then
            return false
        end

        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        return Humanoid ~= nil and Humanoid.Health > 0
    end

    local function DoBlock(Origin)
        if Blocking or IAmBlockingAnim() then
            return
        end

        Blocking = true
        State.Blocking = true
        ReleaseNow = false

        local Method, Detail = Press(true)

        if Method then
            PressFails = 0
            Blocks += 1
            LastReason = Origin .. " | " .. Method
            ClearFailure("Auto-Block")

            local Start = os.clock()

            while Alive do
                if ReleaseNow then
                    break
                end

                local T = os.clock() - Start

                if T >= HOLD_MAX then
                    break
                end

                if T >= HOLD_MIN and os.clock() - LastThreat > NO_THREAT_RELEASE then
                    break
                end

                RunService.Heartbeat:Wait()
            end

            Press(false)
        else
            PressFails += 1
            Note("FALHOU: " .. tostring(Detail))

            if PressFails >= 3 then
                SetFailure(
                    "Auto-Block",
                    Detail == "acao nao encontrada"
                        and "não achei o Block do jogo: use CALIBRAR"
                        or "o Block não confirmou: calibre o botão"
                )
            end
        end

        ReleaseNow = false
        task.wait(0.02)
        Blocking = false
        State.Blocking = false
    end

    -- Dispara o block respeitando o atraso de reação. Só um agendamento por vez.
    local function FireBlock(Origin)
        if Scheduled or not CanStart() then
            return
        end

        if Cfg.React <= 0 then
            task.spawn(DoBlock, Origin)

            return
        end

        Scheduled = true

        task.spawn(function()
            task.wait(Cfg.React)

            Scheduled = false

            if not Alive then
                return
            end

            -- a ameaça sumiu durante a espera (ex.: animação cancelada)? não bloqueia
            if os.clock() - LastThreat > Cfg.React + 0.15 then
                return
            end

            if CanStart() then
                DoBlock(Origin)
            end
        end)
    end

    ------------------------------------------------
    -- AMEAÇAS
    ------------------------------------------------

    local function EvaluateThreat(A)
        if not Allowed(A.E) then
            return
        end

        local Dist, Facing = Measure(A.E)

        if not Dist or Dist > Cfg.Dist then
            return
        end

        if not Facing then
            Note(string.format("sem mira: %s %s %.0f", A.E.Name, A.Name, Dist))

            return
        end

        LastThreat = os.clock()
        FireBlock(string.format("%s %s %.0f", A.E.Name, A.Name, Dist))
    end

    -- Animação ambígua (Hit#, desconhecida): pode ser golpe ou reação a um golpe SEU
    local function ValidateAmbiguous(E)
        local Dist = Measure(E, 0.3)

        if not Dist or Dist > Cfg.Dist then
            return false, "longe"
        end

        local Root = RootOf(E)
        local MyRoot = RootOfChar(Player.Character)

        if Dist > CLOSE_DIST and Root and MyRoot then
            local Diff = MyRoot.Position - Root.Position

            if Diff.Magnitude > 0.1 and Root.CFrame.LookVector:Dot(Diff.Unit) <= 0.3 then
                return false, "sem mira"
            end
        end

        if os.clock() - (DamagedAt[E] or 0) < 0.4 then
            return false, "ele apanhou"
        end

        if os.clock() - LastMyAttack < MY_ATTACK_WINDOW then
            return false, "reacao ao meu ataque"
        end

        return true
    end

    local function ConsiderTrack(E, AnimTrack, Force)
        if not Allowed(E) then
            return
        end

        if not Force and Seen[AnimTrack] then
            return
        end

        Seen[AnimTrack] = true

        if not Connected[AnimTrack] then
            Connected[AnimTrack] = true

            AnimTrack.Stopped:Connect(function()
                Seen[AnimTrack] = nil
            end)
        end

        local Kind, Name = Classify(AnimTrack, E.Kind == "dummy")

        if Kind == "ambiguous" then
            local IsHit = IsHitName(string.lower(Name))
            local Ok, Why = ValidateAmbiguous(E)

            if not Ok then
                local D = Measure(E)

                if D and D <= Cfg.Dist + 5 then
                    Note(string.format("ignorado (%s): %s %s %.0f", Why, E.Name, Name, D))
                end

                return
            end

            Kind, Name = "attack", Name .. (IsHit and "(hit)" or "")
        end

        if Kind == "attack" then
            local A = {E = E, Name = Name, T = os.clock()}

            Threats[AnimTrack] = A
            EvaluateThreat(A)
        elseif Kind == "ignore" and IsActionPriority(AnimTrack.Priority) then
            local D = Measure(E)

            if D and D <= Cfg.Dist + 5 then
                Note(string.format("ignorado: %s %s %.0f", E.Name, Name, D))
            end
        end
    end

    ------------------------------------------------
    -- LIGAÇÕES: jogadores
    ------------------------------------------------

    local function DropList(List)
        for _, Conn in ipairs(List) do
            pcall(function()
                Conn:Disconnect()
            end)
        end

        table.clear(List)
    end

    local function HookPlayerChar(P, Character)
        if PlayerConns[P] then
            DropList(PlayerConns[P])
        else
            PlayerConns[P] = {}
        end

        local Humanoid = Character:WaitForChild("Humanoid", 10)

        if not Humanoid or not Alive then
            return
        end

        local List = PlayerConns[P]
        local E = EntOf(P)
        local Last = Humanoid.Health

        table.insert(List, Humanoid.HealthChanged:Connect(function(New)
            if New < Last then
                DamagedAt[E] = os.clock()
            end

            Last = New
        end))

        local Animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 10)

        if Animator and Alive then
            table.insert(List, Animator.AnimationPlayed:Connect(function(AnimTrack)
                if Alive and Enabled then
                    ConsiderTrack(E, AnimTrack, true)
                end
            end))
        end
    end

    local function HookPlayer(P)
        if P == Player then
            return
        end

        if P.Character then
            task.spawn(HookPlayerChar, P, P.Character)
        end

        Track(P.CharacterAdded:Connect(function(Character)
            task.spawn(HookPlayerChar, P, Character)
        end))
    end

    for _, Other in ipairs(Players:GetPlayers()) do
        HookPlayer(Other)
    end

    Track(Players.PlayerAdded:Connect(HookPlayer))

    Track(Players.PlayerRemoving:Connect(function(P)
        if PlayerConns[P] then
            DropList(PlayerConns[P])
        end

        PlayerConns[P] = nil
        PlayerEnts[P] = nil
        Targets[P] = nil
    end))

    ------------------------------------------------
    -- LIGAÇÕES: dummy (workspace.Folder.enemyforyose)
    ------------------------------------------------

    local function RefreshDummy()
        local Folder = workspace:FindFirstChild("Folder")
        local Model = Folder and Folder:FindFirstChild("enemyforyose")
        local Animator = Model and Model:FindFirstChildWhichIsA("Animator", true)

        if Model == DummyModel and Animator == DummyAnimator then
            return
        end

        DropList(DummyConns)

        DummyModel = Model
        DummyAnimator = Animator

        if not Animator then
            return
        end

        table.insert(DummyConns, Animator.AnimationPlayed:Connect(function(AnimTrack)
            if Alive and Enabled then
                ConsiderTrack(DummyEnt, AnimTrack, true)
            end
        end))

        local Humanoid = Model:FindFirstChildWhichIsA("Humanoid", true)

        if Humanoid then
            local Last = Humanoid.Health

            table.insert(DummyConns, Humanoid.HealthChanged:Connect(function(New)
                if New < Last then
                    DamagedAt[DummyEnt] = os.clock()
                end

                Last = New
            end))
        end
    end

    task.spawn(function()
        while Alive do
            RefreshDummy()
            task.wait(0.5)
        end
    end)

    ------------------------------------------------
    -- MEUS ATAQUES (para ignorar as reações a eles)
    ------------------------------------------------

    local function IsMyAttack(Name, AnimTrack)
        if IsBlockTrack(AnimTrack) or IsHitName(Name) then
            return false
        end

        return not HasWord(Name, NOT_MY_ATTACK)
    end

    local MyConns = {}

    local function HookMe(Character)
        DropList(MyConns)

        local Humanoid = Character:WaitForChild("Humanoid", 10)
        local Animator = Humanoid and (Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 10))

        if not Animator or not Alive then
            return
        end

        table.insert(MyConns, Animator.AnimationPlayed:Connect(function(AnimTrack)
            if not Alive then
                return
            end

            if IsActionPriority(AnimTrack.Priority) and IsMyAttack(string.lower(TrackName(AnimTrack)), AnimTrack) then
                LastMyAttack = os.clock()
            end
        end))
    end

    if Player.Character then
        task.spawn(HookMe, Player.Character)
    end

    Track(Player.CharacterAdded:Connect(function(Character)
        task.spawn(HookMe, Character)
    end))

    ------------------------------------------------
    -- LOOP A CADA FRAME
    ------------------------------------------------

    local function ScanAnimator(E, Animator)
        for _, AnimTrack in ipairs(Animator:GetPlayingAnimationTracks()) do
            if not Seen[AnimTrack] then
                ConsiderTrack(E, AnimTrack, false)
            end
        end
    end

    Track(RunService.Heartbeat:Connect(function()
        if not Alive or not Enabled then
            return
        end

        local Now = os.clock()

        for _, Other in ipairs(Players:GetPlayers()) do
            if Other ~= Player and Targets[Other] and Other.Character then
                local Humanoid = Other.Character:FindFirstChildOfClass("Humanoid")
                local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")

                if Animator then
                    ScanAnimator(EntOf(Other), Animator)
                end
            end
        end

        if Cfg.Dummy and DummyModel and DummyAnimator then
            ScanAnimator(DummyEnt, DummyAnimator)
        end

        -- reavalia golpes em andamento (ele pode se aproximar durante a animação)
        for AnimTrack, A in pairs(Threats) do
            if not AnimTrack.IsPlaying or Now - A.T > THREAT_WINDOW or not IsValid(A.E) then
                Threats[AnimTrack] = nil
            else
                EvaluateThreat(A)
            end
        end
    end))

    ------------------------------------------------
    -- ENTRADAS (último toque/tecla + calibração)
    ------------------------------------------------

    local function ActionOfKey(Input, Actions)
        for Name, Info in pairs(Actions) do
            for _, Kind in ipairs(Info.inputTypes or {}) do
                if Kind == Input.KeyCode then
                    return Name
                end
            end
        end

        return nil
    end

    local function ActionOfTouch(Input, Actions)
        local Pos = Input.Position

        for _, Obj in ipairs(PlayerGui:GetGuiObjectsAtPosition(Pos.X, Pos.Y)) do
            if Obj:IsA("ImageButton") and Obj.Name == "ContextActionButton" then
                for Name in pairs(Actions) do
                    local OkB, Btn = pcall(function()
                        return ContextActionService:GetButton(Name)
                    end)

                    if OkB and Btn == Obj then
                        return Name
                    end
                end
            end
        end

        return nil
    end

    local RefreshInput

    Track(UserInputService.InputBegan:Connect(function(Input)
        if not Alive then
            return
        end

        LastInput = Input

        if not Calibrating then
            return
        end

        local Ok, Actions = pcall(function()
            return ContextActionService:GetAllBoundActionInfo()
        end)

        if not (Ok and Actions) then
            return
        end

        local Name

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            Name = ActionOfKey(Input, Actions)
        elseif Input.UserInputType == Enum.UserInputType.Touch
            or Input.UserInputType == Enum.UserInputType.MouseButton1 then
            Name = ActionOfTouch(Input, Actions)
        end

        if Name then
            CalibratedAction = Name
            Calibrating = false
            Note("calibrado: " .. Name)
            RefreshInput()
        end
    end))

    Track(UserInputService.InputEnded:Connect(function(Input)
        if Alive then
            LastInput = Input
        end
    end))

    ------------------------------------------------
    -- BOTÕES + ESTADO
    ------------------------------------------------

    local function Refresh()
        MasterButton.Text = Enabled and "AUTO-BLOCK • ON" or "AUTO-BLOCK • OFF"
        MasterButton.BackgroundColor3 = Enabled and ON_COLOR or OFF_COLOR

        if RefreshHub then
            RefreshHub()
        end
    end

    RefreshInput = function()
        local Action = FindBlockAction()
        local Text, Color

        if Calibrating then
            Text, Color = "● Aperte o botão de Block do jogo agora...", YELLOW
        elseif Action then
            Text = "● ação: " .. tostring(Action)
                .. (CalibratedAction and " (calibrada)" or "")
                .. (GoodMethod and (" • método " .. GoodMethod.Name) or "")
            Color = GREEN
        else
            Text, Color = "● Block não encontrado — use CALIBRAR", RED
        end

        InputInfo.Text = Text
        InputInfo.TextColor3 = Color
    end

    MasterButton.Activated:Connect(function()
        Enabled = not Enabled
        State.AutoBlock = Enabled

        if Enabled then
            if CountTargets() == 0 and not Cfg.Dummy then
                Say("⚠ AUTO-BLOCK", "Nada para vigiar: ligue o DUMMY ou marque jogadores.", YELLOW)
            end

            if not FindBlockAction() then
                Say("⚠ AUTO-BLOCK", "Botão de Block não encontrado. Toque em CALIBRAR.", YELLOW)
            end
        else
            ReleaseNow = true
            table.clear(Threats)
            ClearFailure("Auto-Block")
        end

        Refresh()
    end)

    CalButton.Activated:Connect(function()
        Calibrating = true
        RefreshInput()
    end)

    TestButton.Activated:Connect(function()
        if Blocking then
            return
        end

        LastThreat = os.clock()
        task.spawn(DoBlock, "teste manual")
    end)

    ClearButton.Activated:Connect(function()
        CalibratedAction = nil
        Calibrating = false
        GoodMethod = nil
        PressFails = 0
        ClearFailure("Auto-Block")
        RefreshInput()
    end)

    local Acc = 0

    Track(RunService.Heartbeat:Connect(function(dt)
        if not Alive then
            return
        end

        Acc += dt

        if Acc < 0.35 then
            return
        end

        Acc = 0

        if Blocking then
            StateLabel.Text = "● Bloqueando • " .. LastReason
            StateLabel.TextColor3 = YELLOW
        elseif Enabled then
            local N = CountTargets()

            if N == 0 and not Cfg.Dummy then
                StateLabel.Text = "● Ligado, mas nada para vigiar — ligue o DUMMY ou marque alguém"
                StateLabel.TextColor3 = YELLOW
            else
                local Watching = {}

                if Cfg.Dummy then
                    table.insert(Watching, "dummy")
                end

                if N > 0 then
                    table.insert(Watching, N .. (N == 1 and " jogador" or " jogadores"))
                end

                StateLabel.Text = "● Vigiando " .. table.concat(Watching, " + ")
                    .. " • " .. Blocks .. " blocks • última: " .. LastReason
                StateLabel.TextColor3 = GREEN
            end
        else
            StateLabel.Text = "● Desligado"
            StateLabel.TextColor3 = MUTED_TEXT
        end

        RefreshInput()
    end))

    Refresh()
    RefreshInput()
end)()


--==================================================
-- OTIMIZAR
-- Monitor de FPS / ping / memória, gráficos sempre no nível 3,
-- botões de otimização e estabilizador automático.
--==================================================

;(function()
    local Page = Pages.Optimize
    local Lighting = game:GetService("Lighting")
    local FAILURE = "Otimização"

    local Cfg = {
        Quality3 = true,
        Boost = false,
        Fx = false,
        Mats = false,
        Unlock = false,
        Net = false,
        Auto = true,
        Eco3D = false,
        Smooth = false,
    }

    local Saved = {
        Lighting = nil,
        Terrain = nil,
        Effects = setmetatable({}, {__mode = "k"}),
        Mats = setmetatable({}, {__mode = "k"}),
    }

    local Setters = {}
    local NetApplied = 0
    local PropSaved = {}
    local FxConn = nil
    local MatConn = nil
    local MatGen = 0

    ----------------------------------------------
    -- MONITOR
    ----------------------------------------------

    local MonCard = Card(
        Page,
        "MONITOR • FPS E PING",
        "Valores ao vivo. O ping é o tempo de ida e volta até o servidor: o Hub não consegue baixar a sua internet, mas tira atrasos do lado do seu aparelho e evita travadas que parecem lag."
    )
    MonCard.LayoutOrder = 1

    local FpsLine = Caption(MonCard, "● FPS: --", 3)
    local PingLine = Caption(MonCard, "● PING: --", 4)
    local MemLine = Caption(MonCard, "● MEMÓRIA: --", 5)
    local StabLine = Caption(MonCard, "● ESTABILIDADE: --", 6)
    local QualLine = Caption(MonCard, "● GRÁFICOS: --", 7)
    local NetLine = Caption(MonCard, "● REDE: --", 8)

    local Samples = {}
    local SampleTime = 0
    local FpsNow = 0
    local FpsAvg5 = 60
    local FpsMin10 = 60
    local StabilityPct = 100
    local PingNow = nil
    local PingHist = {}
    local Jitter = 0
    local MemNow = 0
    local LowSince = nil
    local HighPingSince = nil
    local AutoLevel = 0
    local LastPingWarn = 0
    local LastMemWarn = 0

    local function GetPing()
        local Ok, Value = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)

        if Ok and typeof(Value) == "number" then
            return math.floor(Value + 0.5)
        end

        local Ok2, Value2 = pcall(function()
            return Player:GetNetworkPing() * 2000
        end)

        if Ok2 and typeof(Value2) == "number" then
            return math.floor(Value2 + 0.5)
        end

        return nil
    end

    local function Paint(Label, Text, Color)
        Label.Text = Text
        Label.TextColor3 = Color
    end

    local function Analyze()
        local Count = #Samples

        if Count < 5 then
            return
        end

        local Sum = 0
        local Newest = Samples[Count][1]
        local Last5, Sum5, Min = 0, 0, math.huge

        for _, Entry in ipairs(Samples) do
            Sum += Entry[2]

            if Newest - Entry[1] <= 5 then
                Last5 += 1
                Sum5 += Entry[2]
            end

            if Entry[2] < Min then
                Min = Entry[2]
            end
        end

        local Mean = Sum / Count
        local Variance = 0

        for _, Entry in ipairs(Samples) do
            Variance += (Entry[2] - Mean) ^ 2
        end

        local Std = math.sqrt(Variance / Count)

        FpsAvg5 = Last5 > 0 and (Sum5 / Last5) or Mean
        FpsMin10 = Min
        StabilityPct = math.clamp(100 - (Std / math.max(Mean, 1)) * 200, 0, 100)
    end

    local function Refresh()
        Paint(
            FpsLine,
            string.format("● FPS: %d  •  média %d  •  mínimo %d", FpsNow, FpsAvg5, FpsMin10),
            FpsAvg5 >= 50 and GREEN or (FpsAvg5 >= 30 and YELLOW or RED)
        )

        if PingNow then
            Paint(
                PingLine,
                "● PING: " .. PingNow .. " ms" .. (PingNow <= 80 and " • ótimo" or (PingNow <= 150 and " • bom" or " • alto")),
                PingNow <= 80 and GREEN or (PingNow <= 150 and YELLOW or RED)
            )
        else
            Paint(PingLine, "● PING: indisponível", MUTED_TEXT)
        end

        Paint(
            MemLine,
            string.format("● MEMÓRIA: %d MB", MemNow),
            MemNow < 1200 and GREEN or (MemNow < 1800 and YELLOW or RED)
        )

        Paint(
            StabLine,
            string.format("● ESTABILIDADE: %d%%", StabilityPct)
                .. (StabilityPct >= 80 and " • estável" or (StabilityPct >= 55 and " • oscilando" or " • instável")),
            StabilityPct >= 80 and GREEN or (StabilityPct >= 55 and YELLOW or RED)
        )

        Paint(
            NetLine,
            string.format("● REDE: variação do ping %d ms", math.floor(Jitter + 0.5))
                .. (Jitter <= 15 and " • estável" or (Jitter <= 40 and " • oscilando" or " • instável"))
                .. (Cfg.Net and (" • rede leve: " .. NetApplied .. " ajustes") or ""),
            Jitter <= 15 and GREEN or (Jitter <= 40 and YELLOW or RED)
        )

        local Level = "?"

        pcall(function()
            Level = tostring(settings().Rendering.QualityLevel)
        end)

        Paint(
            QualLine,
            "● GRÁFICOS: " .. string.gsub(Level, "Enum.QualityLevel.", "")
                .. (Cfg.Quality3 and " • travado no 3" or ""),
            Cfg.Quality3 and GREEN or MUTED_TEXT
        )
    end

    ----------------------------------------------
    -- AJUSTE DE PROPRIEDADES (guarda o valor antigo e restaura)
    ----------------------------------------------

    local function PropSet(Key, GetObj, Name, Value)
        local Ok = pcall(function()
            local Obj = GetObj()
            local Old = Obj[Name]
            local New = Value

            if typeof(Value) == "function" then
                New = Value()
            end

            Obj[Name] = New

            if PropSaved[Key] == nil then
                PropSaved[Key] = {Obj, Name, Old}
            end
        end)

        return Ok
    end

    local function PropRestore(Prefix)
        for Key, Data in pairs(PropSaved) do
            if string.sub(Key, 1, #Prefix) == Prefix then
                pcall(function()
                    Data[1][Data[2]] = Data[3]
                end)

                PropSaved[Key] = nil
            end
        end
    end

    local function SetFpsCap(Value)
        if typeof(setfpscap) == "function" then
            return (pcall(setfpscap, Value))
        end

        if typeof(setfflag) == "function" then
            return (pcall(setfflag, "DFIntTaskSchedulerTargetFps", tostring(Value)))
        end

        return false
    end

    ----------------------------------------------
    -- COMPONENTES
    ----------------------------------------------

    local function AddToggle(ParentCard, Order, Key, Label, Apply)
        local B = Button(ParentCard, "", Order)

        local function Style()
            local On = Cfg[Key]

            B.Text = Label .. " • " .. (On and "ON" or "OFF")
            B.BackgroundColor3 = On and ON_COLOR or OFF_COLOR
        end

        local function Set(On, Silent)
            Cfg[Key] = On

            local Ok, Err = pcall(Apply, On)

            if not Ok then
                Cfg[Key] = false
                Style()
                SetFailure(FAILURE, tostring(Err))
                Say("✖ OTIMIZAR", Label .. ": " .. ShortText(Err), RED)
                return
            end

            ClearFailure(FAILURE)
            Style()

            if not Silent then
                Say(On and "✓ OTIMIZAR" or "○ OTIMIZAR", Label .. (On and " ligado." or " desligado."), On and GREEN or YELLOW)
            end
        end

        B.Activated:Connect(function()
            Set(not Cfg[Key], false)
        end)

        Style()
        Setters[Key] = Set

        return B
    end

    ----------------------------------------------
    -- 1) GRÁFICOS SEMPRE NO NÍVEL 3
    ----------------------------------------------

    local function ApplyQuality()
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level03
        end)

        pcall(function()
            local Game = UserSettings():GetService("UserGameSettings")
            Game.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel3
        end)
    end

    local function QualityIsThree()
        local Ok, Value = pcall(function()
            return settings().Rendering.QualityLevel
        end)

        return Ok and (Value == Enum.QualityLevel.Level03 or Value == 3)
    end

    local QualCard = Card(
        Page,
        "GRÁFICOS NO NÍVEL 3",
        "Mantém a qualidade gráfica sempre no nível 3 (o Hub volta para o 3 se o jogo ou você mudarem). Equilíbrio entre imagem e FPS."
    )
    QualCard.LayoutOrder = 2

    AddToggle(QualCard, 3, "Quality3", "GRÁFICOS NÍVEL 3", function(On)
        if On then
            ApplyQuality()
        end
    end)

    ----------------------------------------------
    -- 2) BOOST DE FPS (luz, sombras, efeitos de tela, água)
    ----------------------------------------------

    local function BoostApply(On)
        local Terrain = workspace:FindFirstChildOfClass("Terrain")

        if On then
            Saved.Lighting = {GlobalShadows = Lighting.GlobalShadows, Effects = {}}

            Lighting.GlobalShadows = false

            for _, Obj in ipairs(Lighting:GetChildren()) do
                if Obj:IsA("PostEffect") and Obj.Enabled then
                    Saved.Lighting.Effects[Obj] = true
                    Obj.Enabled = false
                end
            end

            if Terrain then
                Saved.Terrain = {
                    Decoration = Terrain.Decoration,
                    WaterWaveSize = Terrain.WaterWaveSize,
                    WaterWaveSpeed = Terrain.WaterWaveSpeed,
                    WaterReflectance = Terrain.WaterReflectance,
                }

                pcall(function()
                    Terrain.Decoration = false
                end)

                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
            end
        else
            if Saved.Lighting then
                Lighting.GlobalShadows = Saved.Lighting.GlobalShadows

                for Obj in pairs(Saved.Lighting.Effects) do
                    if Obj.Parent then
                        Obj.Enabled = true
                    end
                end

                Saved.Lighting = nil
            end

            if Terrain and Saved.Terrain then
                pcall(function()
                    Terrain.Decoration = Saved.Terrain.Decoration
                end)

                Terrain.WaterWaveSize = Saved.Terrain.WaterWaveSize
                Terrain.WaterWaveSpeed = Saved.Terrain.WaterWaveSpeed
                Terrain.WaterReflectance = Saved.Terrain.WaterReflectance
                Saved.Terrain = nil
            end
        end
    end

    local BoostCard = Card(
        Page,
        "OTIMIZAÇÕES DE FPS",
        "BOOST: sem sombras, sem efeitos de tela e água simples. SEM PARTÍCULAS: desliga fumaça, fogo e rastros (inclusive de skills). MATERIAIS LEVES: troca materiais por liso e esconde decalques. Tudo volta ao normal ao desligar."
    )
    BoostCard.LayoutOrder = 3

    AddToggle(BoostCard, 3, "Boost", "BOOST DE FPS", BoostApply)

    ----------------------------------------------
    -- 3) SEM PARTÍCULAS / EFEITOS
    ----------------------------------------------

    local FX_CLASSES = {"ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles"}

    local function IsFx(Obj)
        for _, Class in ipairs(FX_CLASSES) do
            if Obj:IsA(Class) then
                return true
            end
        end

        return false
    end

    local function KillFx(Obj)
        if IsFx(Obj) and Obj.Enabled then
            Saved.Effects[Obj] = true
            Obj.Enabled = false
        end
    end

    local function FxApply(On)
        if FxConn then
            FxConn:Disconnect()
            FxConn = nil
        end

        if On then
            local Count = 0

            for _, Obj in ipairs(workspace:GetDescendants()) do
                KillFx(Obj)
                Count += 1

                if Count % 600 == 0 then
                    task.wait()
                end
            end

            FxConn = workspace.DescendantAdded:Connect(KillFx)
            Track(FxConn)
        else
            for Obj in pairs(Saved.Effects) do
                if Obj.Parent then
                    Obj.Enabled = true
                end

                Saved.Effects[Obj] = nil
            end
        end
    end

    AddToggle(BoostCard, 4, "Fx", "SEM PARTÍCULAS", FxApply)

    ----------------------------------------------
    -- 4) MATERIAIS LEVES
    ----------------------------------------------

    local function LightMat(Obj)
        if Obj:IsA("BasePart") and not Obj:IsDescendantOf(Players) then
            local Character = Obj:FindFirstAncestorOfClass("Model")
            local IsPlayer = Character and Players:GetPlayerFromCharacter(Character)

            if not IsPlayer and Obj.Material ~= Enum.Material.SmoothPlastic and not Saved.Mats[Obj] then
                Saved.Mats[Obj] = {Obj.Material}
                Obj.Material = Enum.Material.SmoothPlastic
            end
        elseif Obj:IsA("Decal") or Obj:IsA("Texture") then
            if Obj.Transparency < 1 and not Saved.Mats[Obj] then
                Saved.Mats[Obj] = {nil, Obj.Transparency}
                Obj.Transparency = 1
            end
        end
    end

    local function MatsApply(On)
        MatGen += 1
        local Mine = MatGen

        if MatConn then
            MatConn:Disconnect()
            MatConn = nil
        end

        if On then
            MatConn = workspace.DescendantAdded:Connect(LightMat)
            Track(MatConn)

            task.spawn(function()
                local Count = 0

                for _, Obj in ipairs(workspace:GetDescendants()) do
                    if MatGen ~= Mine then
                        return
                    end

                    LightMat(Obj)
                    Count += 1

                    if Count % 400 == 0 then
                        task.wait()
                    end
                end
            end)
        else
            task.spawn(function()
                local Count = 0

                for Obj, Data in pairs(Saved.Mats) do
                    if Obj.Parent then
                        if Data[1] then
                            Obj.Material = Data[1]
                        elseif Data[2] then
                            Obj.Transparency = Data[2]
                        end
                    end

                    Saved.Mats[Obj] = nil
                    Count += 1

                    if Count % 400 == 0 then
                        task.wait()
                    end
                end
            end)
        end
    end

    AddToggle(BoostCard, 5, "Mats", "MATERIAIS LEVES", MatsApply)

    ----------------------------------------------
    -- 5) REDE / FPS ALTO / ECONOMIA 3D
    ----------------------------------------------

    local NetCard = Card(
        Page,
        "REDE E TAXA DE QUADROS",
"REDE LEVE: tira atrasos de replicação, libera o limite de envio, desliga a limitação de física/interpolação e o carregamento extra de regiões (cada ajuste que o seu executor aceitar conta no monitor). Não baixa a latência real da internet, mas tira os atrasos que dependem do seu aparelho. FPS DESBLOQUEADO: tira o limite de 60 FPS. ECONOMIA 3D: tela preta para poupar bateria e FPS em farm parado."
    )
    NetCard.LayoutOrder = 4

    AddToggle(NetCard, 3, "Net", "REDE LEVE", function(On)
        if On then
            local Applied = 0

            local function Count(Ok)
                if Ok then
                    Applied += 1
                end
            end

            local function Network()
                return settings().Network
            end

            local function Physics()
                return settings().Physics
            end

            Count(PropSet("net.lag", Network, "IncomingReplicationLag", 0))
            Count(PropSet("net.regions", Network, "RenderStreamedRegions", false))
            Count(PropSet("net.sleep", Physics, "AllowSleep", true))
            Count(PropSet("net.throttle", Physics, "PhysicsEnvironmentalThrottle", function()
                return Enum.EnviromentalPhysicsThrottle.Disabled
            end))
            Count(PropSet("net.adjust", Physics, "ThrottleAdjustTime", 0))
            Count(PropSet("net.interp", function()
                return workspace
            end, "InterpolationThrottling", function()
                return Enum.InterpolationThrottlingMode.Disabled
            end))
            Count((pcall(function()
                game:GetService("NetworkClient"):SetOutgoingKBPSLimit(math.huge)
            end)))

            NetApplied = Applied
        else
            PropRestore("net.")
            NetApplied = 0
        end
    end)

    AddToggle(NetCard, 4, "Unlock", "FPS DESBLOQUEADO", function(On)
        if Cfg.Smooth then
            return
        end

        if not SetFpsCap(On and 240 or 60) then
            error("o executor não tem setfpscap")
        end
    end)

    AddToggle(NetCard, 5, "Eco3D", "ECONOMIA 3D (TELA PRETA)", function(On)
        RunService:Set3dRenderingEnabled(not On)

        if On then
            Say("⚠ ECONOMIA 3D", "Tela preta de propósito. Desligue o botão para ver o jogo de novo.", YELLOW)
        end
    end)

    Track(Gui.Destroying:Connect(function()
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)

        PropRestore("net.")
        PropRestore("sm.")

        if Cfg.Smooth or Cfg.Unlock then
            SetFpsCap(60)
        end
    end))

    ----------------------------------------------
    -- 5B) FLUIDEZ: QUADROS ESTÁVEIS (ritmo constante)
    ----------------------------------------------

    local FPS_TARGETS = {60, 90, 120, 144, 240}
    local FpsIndex = 1
    local CapNow = 60
    local LastCapChange = 0

    local SmoothCard = Card(
        Page,
        "FLUIDEZ • QUADROS ESTÁVEIS",
        "Foca em quadros constantes (ritmo parelho), não só em FPS alto. Trava o FPS no alvo escolhido e ajusta o limite sozinho: se o aparelho não aguenta o alvo, ele baixa o limite até ficar estável e sobe de novo quando dá. Também desliga o ajuste automático de qualidade do Roblox (que causa quedas) e a limitação de física."
    )
    SmoothCard.LayoutOrder = 4

    local PaceLine = Caption(SmoothCard, "● Desligado", 5)
    PaceLine.TextColor3 = MUTED_TEXT

    AddToggle(SmoothCard, 3, "Smooth", "FLUIDEZ", function(On)
        if On then
            CapNow = FPS_TARGETS[FpsIndex]
            LastCapChange = os.clock()

            PropSet("sm.frm", function()
                return settings().Rendering
            end, "FrameRateManager", function()
                return Enum.FramerateManagerMode.Off
            end)

            PropSet("sm.eager", function()
                return settings().Rendering
            end, "EagerBulkExecution", true)

            PropSet("sm.sleep", function()
                return settings().Physics
            end, "AllowSleep", true)

            PropSet("sm.throttle", function()
                return settings().Physics
            end, "PhysicsEnvironmentalThrottle", function()
                return Enum.EnviromentalPhysicsThrottle.Disabled
            end)

            if not SetFpsCap(CapNow) then
                Say("⚠ FLUIDEZ", "Seu executor não tem setfpscap: o limite de quadros não muda, o resto foi aplicado.", YELLOW)
            end
        else
            PropRestore("sm.")
            SetFpsCap(Cfg.Unlock and 240 or 60)
        end
    end)

    local TargetButton = Button(SmoothCard, "ALVO DE FPS • " .. FPS_TARGETS[FpsIndex], 4)

    TargetButton.Activated:Connect(function()
        FpsIndex = (FpsIndex % #FPS_TARGETS) + 1
        TargetButton.Text = "ALVO DE FPS • " .. FPS_TARGETS[FpsIndex]

        if Cfg.Smooth then
            CapNow = FPS_TARGETS[FpsIndex]
            LastCapChange = os.clock()
            SetFpsCap(CapNow)
        end
    end)

    local function Pace(Now)
        if not Cfg.Smooth then
            PaceLine.Text = "● Desligado"
            PaceLine.TextColor3 = MUTED_TEXT
            return
        end

        local Target = FPS_TARGETS[FpsIndex]

        PaceLine.Text = string.format(
            "● Alvo %d • limite agora %d • média %d • estabilidade %d%%",
            Target, CapNow, FpsAvg5, StabilityPct
        )
        PaceLine.TextColor3 = StabilityPct >= 80 and GREEN or (StabilityPct >= 55 and YELLOW or RED)

        if #Samples < 30 or Now - LastCapChange < 4 then
            return
        end

        local NewCap = CapNow

        if FpsAvg5 < CapNow * 0.88 and StabilityPct < 75 then
            -- oscilando abaixo do limite: baixa o limite para o que o aparelho segura
            NewCap = math.max(30, math.floor(FpsAvg5 * 0.97 / 5) * 5)
        elseif CapNow < Target and FpsAvg5 >= CapNow * 0.96 and StabilityPct >= 85 and Now - LastCapChange > 10 then
            NewCap = math.min(Target, CapNow + 5)
        end

        if NewCap ~= CapNow then
            CapNow = NewCap
            LastCapChange = Now
            SetFpsCap(NewCap)
        end
    end

    ----------------------------------------------
    -- 6) ESTABILIZADOR AUTOMÁTICO + ATALHOS
    ----------------------------------------------

    local AutoCard = Card(
        Page,
        "ESTABILIZADOR AUTOMÁTICO",
        "Vigia FPS, ping, variação do ping e memória. Se o FPS ficar baixo por 5 s, liga as otimizações aos poucos (boost, partículas, materiais). Se o ping ficar alto ou instável, liga a rede leve e avisa. Se a memória encher, limpa."
    )
    AutoCard.LayoutOrder = 5

    AddToggle(AutoCard, 3, "Auto", "ESTABILIZADOR", function() end)

    local MaxButton = Button(AutoCard, "MODO FLUIDO: LIGAR TUDO", 4)
    local OffButton = Button(AutoCard, "DESLIGAR TODAS AS OTIMIZAÇÕES", 5)
    local MemButton = Button(AutoCard, "LIMPAR MEMÓRIA AGORA", 6)

    MaxButton.Activated:Connect(function()
        for _, Key in ipairs({"Quality3", "Boost", "Fx", "Net", "Smooth"}) do
            if Setters[Key] and not Cfg[Key] then
                Setters[Key](true, true)
            end
        end

        Say("✓ MODO FLUIDO", "Gráficos 3, boost, sem partículas, rede leve e quadros estáveis.", GREEN)
    end)

    OffButton.Activated:Connect(function()
        for _, Key in ipairs({"Boost", "Fx", "Mats", "Net", "Unlock", "Eco3D", "Smooth"}) do
            if Setters[Key] and Cfg[Key] then
                Setters[Key](false, true)
            end
        end

        AutoLevel = 0
        Say("○ OTIMIZAÇÕES", "Tudo desligado (o gráfico nível 3 continua).", YELLOW)
    end)

    MemButton.Activated:Connect(function()
        local Before = Stats:GetTotalMemoryUsageMb()

        pcall(collectgarbage, "collect")

        task.wait(0.3)

        local After = Stats:GetTotalMemoryUsageMb()

        Say("🧹 MEMÓRIA", string.format("%d MB → %d MB", Before, After), GREEN)
    end)

    local AUTO_STEPS = {
        {"Boost", "boost de FPS"},
        {"Fx", "sem partículas"},
        {"Mats", "materiais leves"},
    }

    local function AutoCheck()
        if not Cfg.Auto then
            LowSince = nil
            HighPingSince = nil
            return
        end

        local Now = os.clock()

        -- FPS baixo por 5 s -> liga o próximo nível
        if #Samples >= 30 and FpsAvg5 < 30 and AutoLevel < #AUTO_STEPS then
            LowSince = LowSince or Now

            if Now - LowSince >= 5 then
                LowSince = Now
                AutoLevel += 1

                local Step = AUTO_STEPS[AutoLevel]

                if Setters[Step[1]] and not Cfg[Step[1]] then
                    Setters[Step[1]](true, true)
                    Say("⚡ ESTABILIZADOR", "FPS baixo (" .. math.floor(FpsAvg5) .. "). Liguei: " .. Step[2] .. ".", YELLOW)
                end
            end
        else
            LowSince = nil
        end

        -- ping alto por 6 s -> avisa e liga rede leve
        if PingNow and (PingNow > 250 or Jitter > 70) then
            HighPingSince = HighPingSince or Now

            if Now - HighPingSince >= 6 and Now - LastPingWarn > 30 then
                LastPingWarn = Now

                if Setters.Net and not Cfg.Net then
                    Setters.Net(true, true)
                end

                Say("⚠ PING ALTO", PingNow .. " ms. Verifique a conexão (Wi-Fi/dados). Liguei a rede leve.", RED)
            end
        else
            HighPingSince = nil
        end

        -- memória alta -> limpa
        if MemNow > 1800 and Now - LastMemWarn > 60 then
            LastMemWarn = Now
            pcall(collectgarbage, "collect")
            Say("🧹 MEMÓRIA ALTA", MemNow .. " MB. Fiz uma limpeza.", YELLOW)
        end
    end

    ----------------------------------------------
    -- LOOPS
    ----------------------------------------------

    local Acc = 0
    local UiAcc = 0
    local QualAcc = 0

    Track(RunService.RenderStepped:Connect(function(dt)
        if not Alive then
            return
        end

        SampleTime += dt
        FpsNow = math.floor(1 / math.max(dt, 0.0001) + 0.5)

        table.insert(Samples, {os.clock(), FpsNow})

        if #Samples > 600 then
            table.remove(Samples, 1)
        end

        while #Samples > 0 and os.clock() - Samples[1][1] > 10 do
            table.remove(Samples, 1)
        end

        Acc += dt
        UiAcc += dt
        QualAcc += dt

        if Acc >= 0.5 then
            Acc = 0

            Analyze()
            PingNow = GetPing()
            MemNow = math.floor(Stats:GetTotalMemoryUsageMb() + 0.5)

            if PingNow then
                table.insert(PingHist, PingNow)

                if #PingHist > 20 then
                    table.remove(PingHist, 1)
                end

                local Sum, Count = 0, #PingHist

                for _, V in ipairs(PingHist) do
                    Sum += V
                end

                local Mean = Sum / Count
                local Var = 0

                for _, V in ipairs(PingHist) do
                    Var += (V - Mean) ^ 2
                end

                Jitter = math.sqrt(Var / Count)
            end

            AutoCheck()
            Pace(os.clock())
        end

        -- mantém os gráficos no 3
        if QualAcc >= 1.5 then
            QualAcc = 0

            if Cfg.Quality3 and not QualityIsThree() then
                ApplyQuality()
            end
        end

        if UiAcc >= 0.5 then
            UiAcc = 0

            if Page.Visible and Main.Visible then
                Refresh()
            end
        end
    end))

    -- começa com os gráficos no 3
    ApplyQuality()
    Refresh()
end)()


--==================================================
-- ADAPTAÇÃO AUTOMÁTICA DOS BOTÕES DO JOGO
-- Se o Hub não achou o botão de Block / Dash / Ataque, ele aprende
-- sozinho quando você usa o botão de verdade (sem precisar calibrar).
--==================================================

;(function()
    local Recent = {}
    local Learned = {}
    local ATTACK_WORDS = {"attack", "atk", "m1", "punch", "swing", "slash", "melee", "combat", "strike", "kick"}

    Track(UserInputService.InputBegan:Connect(function(Input)
        local Type = Input.UserInputType

        if Type == Enum.UserInputType.Touch or Type == Enum.UserInputType.MouseButton1 then
            table.insert(Recent, {T = os.clock(), Pos = Vector2.new(Input.Position.X, Input.Position.Y)})

            if #Recent > 10 then
                table.remove(Recent, 1)
            end
        end
    end))

    local function ButtonNear(Window)
        local Now = os.clock()

        for I = #Recent, 1, -1 do
            local R = Recent[I]

            if Now - R.T > Window then
                break
            end

            local Ok, Objects = pcall(function()
                return PlayerGui:GetGuiObjectsAtPosition(R.Pos.X, R.Pos.Y)
            end)

            if Ok then
                for _, Obj in ipairs(Objects) do
                    if not Obj:IsDescendantOf(Gui) then
                        local Walk = Obj

                        while Walk and Walk ~= PlayerGui do
                            if Walk:IsA("GuiButton") then
                                return Walk
                            end

                            Walk = Walk.Parent
                        end
                    end
                end
            end
        end

        return nil
    end

    local function Learn(Kind, Label)
        if Learned[Kind] or GameInput.Calib[Kind] then
            return
        end

        -- se o Hub já acha sozinho, não precisa aprender
        if GameInput.Find(Kind) then
            Learned[Kind] = true
            return
        end

        local Found = ButtonNear(0.45)

        if not Found then
            return
        end

        local Cam = workspace.CurrentCamera
        local View = Cam and Cam.ViewportSize or Gui.AbsoluteSize
        local Center = Found.AbsolutePosition + Found.AbsoluteSize / 2

        GameInput.Calib[Kind] = {
            Ref = Found,
            Name = Found.Name,
            Class = Found.ClassName,
            Fx = Center.X / View.X,
            Fy = Center.Y / View.Y,
        }

        GameInput.Cache[Kind] = nil
        Learned[Kind] = true

        Say("🧠 ADAPTEI AO JOGO", "Aprendi o botão de " .. Label .. ": " .. Found.Name .. ".", GREEN)
    end

    local function Classify(Name)
        Name = string.lower(Name)

        if string.find(Name, "block", 1, true) then
            return "Block", "Block"
        end

        if string.find(Name, "dash", 1, true) or string.find(Name, "dodge", 1, true) then
            return "Dash", "Dash"
        end

        for _, Word in ipairs(ATTACK_WORDS) do
            if string.find(Name, Word, 1, true) then
                return "Attack", "Ataque"
            end
        end

        return nil
    end

    local function HookMe(Character)
        local Humanoid = Character:WaitForChild("Humanoid", 8)
        local Animator = Humanoid and (Humanoid:FindFirstChildOfClass("Animator") or Humanoid:WaitForChild("Animator", 8))

        if not Animator then
            return
        end

        Track(Animator.AnimationPlayed:Connect(function(AnimTrack)
            if not Alive then
                return
            end

            local Name = AnimTrack.Animation and AnimTrack.Animation.Name or AnimTrack.Name
            local Kind, Label = Classify(Name)

            if Kind then
                Learn(Kind, Label)
            end
        end))
    end

    if Player.Character then
        task.spawn(HookMe, Player.Character)
    end

    Track(Player.CharacterAdded:Connect(HookMe))
end)()


--==================================================
-- AO REENTRAR (REJOIN)
-- Salva o que estava ligado e, no rejoin, executa o Hub de novo sozinho
-- e liga tudo outra vez.
--==================================================

;(function()
    local HttpService = game:GetService("HttpService")

    -- ⚙ CONFIGURE: de onde o Hub se recarrega depois do rejoin
    -- Opção 1: salve este script como PABLOX_HUB.lua na pasta "workspace" do executor
    -- Opção 2: se você carrega por link (loadstring(game:HttpGet(...))), coloque o link em SCRIPT_URL
    local SCRIPT_FILE = "PABLOX_HUB.lua"
    local SCRIPT_URL = ""

    local STATE_FILE = "PABLOX_STATE.json"

    local HAS_FS = typeof(writefile) == "function"
        and typeof(readfile) == "function"
        and typeof(isfile) == "function"

    local RestoreOn = true
    local LastJson = nil
    local LastQueue = 0

    -- botões que alternam opções (clicar várias vezes até chegar no valor salvo)
    local CycleKeys = {
        ["FORÇA"] = true, ["POSIÇÃO"] = true, ["RESPOSTA"] = true, ["TEMPO"] = true,
        ["NÍVEL"] = true, ["DISTÂNCIA ATRÁS"] = true, ["GATILHO"] = true,
        ["ESTILO"] = true, ["TEMPO FUGINDO"] = true, ["ATACAR POR"] = true,
        ["ATAQUE"] = true, ["ESTILO FAKEOUT"] = true,
        ["ONDE FICA"] = true, ["TEMPO NO AUTO"] = true, ["ALVO DE FPS"] = true,
    }

    local C1 = Card(
        Pages.Status,
        "AO REENTRAR (REJOIN)",
        "O Hub guarda o que estava ligado e, no rejoin, executa de novo sozinho e liga tudo outra vez. Precisa do script salvo como PABLOX_HUB.lua na pasta workspace do executor (ou do link em SCRIPT_URL)."
    )
    C1.LayoutOrder = 3

    local RestoreToggle = Button(C1, "RESTAURAR TUDO • ON", 3)
    RestoreToggle.BackgroundColor3 = ON_COLOR

    RestoreToggle.Activated:Connect(function()
        RestoreOn = not RestoreOn

        RestoreToggle.Text = RestoreOn and "RESTAURAR TUDO • ON" or "RESTAURAR TUDO • OFF"
        RestoreToggle.BackgroundColor3 = RestoreOn and ON_COLOR or OFF_COLOR
    end)

    local function Fire(Btn)
        if typeof(firesignal) == "function" then
            if pcall(firesignal, Btn.Activated) then
                return true
            end
        end

        if typeof(getconnections) == "function" then
            local Ok, List = pcall(getconnections, Btn.Activated)

            if Ok and typeof(List) == "table" then
                for _, Conn in ipairs(List) do
                    pcall(function()
                        Conn:Fire()
                    end)
                end

                return #List > 0
            end
        end

        return false
    end

    local function Collect()
        local Data = {restore = RestoreOn, toggles = {}, cycles = {}, t = os.time()}

        for _, Obj in ipairs(Gui:GetDescendants()) do
            if Obj:IsA("TextButton") then
                local Name, Flag = string.match(Obj.Text, "^(.+) • (O[NF]+)$")

                if Name and (Flag == "ON" or Flag == "OFF") then
                    if Name ~= "RESTAURAR TUDO" then
                        Data.toggles[Name] = Flag == "ON"
                    end
                else
                    local Prefix = string.match(Obj.Text, "^(.-) • ")

                    if Prefix and CycleKeys[Prefix] then
                        Data.cycles[Prefix] = Obj.Text
                    end
                end
            end
        end

        return Data
    end

    local function Save()
        if not HAS_FS or not Alive then
            return
        end

        local Ok, Json = pcall(function()
            return HttpService:JSONEncode(Collect())
        end)

        if Ok and Json ~= LastJson then
            LastJson = Json
            pcall(writefile, STATE_FILE, Json)
        end
    end

    local function QueueReexec()
        if os.clock() - LastQueue < 5 then
            return
        end

        LastQueue = os.clock()

        local Queue = queue_on_teleport
            or (syn and syn.queue_on_teleport)
            or (fluxus and fluxus.queue_on_teleport)

        if typeof(Queue) ~= "function" then
            Say("⚠ REJOIN", "Seu executor não tem queue_on_teleport. O Hub não recarrega sozinho.", YELLOW)
            return
        end

        local Payload = string.format([[
local File, Url = %q, %q
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(3)
    local Source
    if Url ~= "" then
        local Ok, Result = pcall(function() return game:HttpGet(Url) end)
        if Ok then Source = Result end
    end
    if not Source and typeof(isfile) == "function" and isfile(File) then
        Source = readfile(File)
    end
    if Source then
        local Fn = loadstring(Source)
        if Fn then Fn() end
    end
end)
]], SCRIPT_FILE, SCRIPT_URL)

        pcall(Queue, Payload)
    end

    local function FindButton(Text)
        for _, Obj in ipairs(Gui:GetDescendants()) do
            if Obj:IsA("TextButton") and Obj.Text == Text then
                return Obj
            end
        end
    end

    local function Restore()
        if not HAS_FS then
            return
        end

        local Ok, Data = pcall(function()
            if isfile(STATE_FILE) then
                return HttpService:JSONDecode(readfile(STATE_FILE))
            end
        end)

        if not Ok or typeof(Data) ~= "table" then
            return
        end

        if Data.restore == false then
            RestoreOn = false
            RestoreToggle.Text = "RESTAURAR TUDO • OFF"
            RestoreToggle.BackgroundColor3 = OFF_COLOR
            return
        end

        task.spawn(function()
            task.wait(2)

            for Prefix, WantText in pairs(Data.cycles or {}) do
                for _ = 1, 9 do
                    local Btn

                    for _, Obj in ipairs(Gui:GetDescendants()) do
                        if Obj:IsA("TextButton") and string.sub(Obj.Text, 1, #Prefix + 3) == Prefix .. " • " then
                            Btn = Obj
                            break
                        end
                    end

                    if not Btn or Btn.Text == WantText then
                        break
                    end

                    Fire(Btn)
                    task.wait(0.05)
                end
            end

            for Name, Want in pairs(Data.toggles or {}) do
                for _ = 1, 6 do
                    local Wrong = Name .. " • " .. (Want and "OFF" or "ON")
                    local Now = FindButton(Wrong)

                    if not Now then
                        break
                    end

                    Fire(Now)
                    task.wait(0.4)

                    if not FindButton(Wrong) then
                        break
                    end

                    task.wait(1)
                end
            end

            Say("↻ HUB RESTAURADO", "Voltou com as funções que estavam ligadas.", GREEN)
        end)
    end

    task.spawn(function()
        while Alive do
            task.wait(5)
            Save()
        end
    end)

    Track(Player.OnTeleport:Connect(function(TeleportState)
        if TeleportState == Enum.TeleportState.Started
            or TeleportState == Enum.TeleportState.InProgress
            or TeleportState == Enum.TeleportState.RequestedFromServer then

            Save()
            QueueReexec()
        end
    end))

    Restore()
end)()


--==================================================
-- FIM DA PARTE 2
--==================================================

Notifier.Show("✓ PABLOX HUB v16", "Carregado. Toque no botão redondo para abrir.", GREEN)


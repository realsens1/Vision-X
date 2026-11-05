--// Vision X  |  LocalScript  (StarterPlayer > StarterPlayerScripts)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CAS = game:GetService("ContextActionService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local function cam() return workspace.CurrentCamera end

local env = (getgenv and getgenv()) or _G
if env.VisionXClose then pcall(env.VisionXClose) end

-- Robust GUI Container Detection
local GuiRoot = PlayerGui
if gethui then
	local ok, h = pcall(gethui)
	if ok and h then GuiRoot = h end
elseif game:GetService("CoreGui") then
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then GuiRoot = cg end
end

for _, root in ipairs({ PlayerGui, GuiRoot }) do
	if root then
		for _, n in ipairs({ "VisionX", "VisionXESP" }) do
			local old = root:FindFirstChild(n)
			if old then old:Destroy() end
		end
	end
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local BLACK, PANEL, CARD = Color3.fromRGB(22, 22, 26), Color3.fromRGB(27, 27, 33), Color3.fromRGB(32, 32, 39)
local LINE, TEXT, DIM = Color3.fromRGB(42, 42, 52), Color3.fromRGB(235, 235, 240), Color3.fromRGB(140, 140, 152)
local GREEN, OFFC = Color3.fromRGB(52, 199, 89), Color3.fromRGB(46, 46, 54)
local Q, B = Enum.EasingStyle.Quint, Enum.EasingStyle.Back
local OUT, IN = Enum.EasingDirection.Out, Enum.EasingDirection.In

local VERSION = "V13"
local ANIM = 1
local function tw(o, t, props, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t / ANIM, style or Q, dir or OUT), props)
	tween:Play()
	return tween
end
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local rounds = {}
local function rcorner(o, r)
	local c = corner(o, r)
	table.insert(rounds, { c = c, r = r })
	return c
end
local function stroke(o, c, th, tr)
	return new("UIStroke", { Color = c or LINE, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function txt(parent, props)
	local d = { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextColor3 = TEXT, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", BorderSizePixel = 0 }
	for k, v in pairs(props) do d[k] = v end
	return new("TextLabel", d, parent)
end
local clickFn = function() end
local notifyFn = function() end
local function button(parent, props)
	local d = { AutoButtonColor = false, BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextColor3 = TEXT,
		TextSize = 12, BackgroundColor3 = CARD, Text = "" }
	for k, v in pairs(props) do d[k] = v end
	local b = new("TextButton", d, parent)
	corner(b, 7)
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tw(sc, 0.12, { Scale = 1.03 }) end)
	b.MouseButton1Down:Connect(function() clickFn() tw(sc, 0.08, { Scale = 0.95 }) end)
	local function up() tw(sc, 0.18, { Scale = 1 }) end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	return b
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local D = { hue = 0.6, transparency = 0, lock = false, flight = 5, jump = 50, walk = 16, fov = 70, spin = 100, bg = 1, guiScale = 100, corner = 14, sbRight = false, font = 1, textSize = 100,
	anim = 100, dragW = 60, espTeam = 216, espEnemy = 0, fpsColor = 1, fpsPos = 1, key = "RightShift",
	dashPow = 90, dashCd = 10, wcSpeed = 25, followDist = 6, url = "", pins = {}, notify = true, fcSpeed = 60, roleFilter = 1,
	sprintMul = 18, xrayT = 60, soundVol = 50, sound = false, camMode = 1, sky = 1, favs = {} }
local S = {}
for k, v in pairs(D) do S[k] = v end
local F = { grabGun = false, dodge = false, infcam = false, roles = false, plat = false, sprint = false, xray = false, chatCmd = false, wc = false, stats = false, alerts = false, hide = false, rainbow = false, glow = false, fg = false, ctp = false, sit = false, afk = false, spin = false, fb = false, fpsb = false, fly = false, noclip = false, inf = false, jp = false, ws = false, grav = false, esp = false, fps = false,
	fovActive = false, fovReturn = false }

local conns, cleanups = {}, {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(conns, c)
	return c
end

-- theme / transparency registries
local themeFns, bgs = {}, {}
local accA, accB
local function accent(h) return Color3.fromHSV(h % 1, 0.75, 1) end
local function accent2(h) return Color3.fromHSV((h + 0.12) % 1, 0.8, 1) end
local function applyTheme()
	accA, accB = accent(S.hue), accent2(S.hue)
	for _, f in ipairs(themeFns) do f(accA, accB) end
end
local function onTheme(fn)
	table.insert(themeFns, fn)
	fn(accent(S.hue), accent2(S.hue))
end
local function gradient(parent)
	local g = new("UIGradient", { Rotation = 30 }, parent)
	onTheme(function(a, b) g.Color = ColorSequence.new(a, b) end)
	return g
end
local function bg(o, base, role) table.insert(bgs, { o = o, base = base or 0, role = role }) end
local function applyTransparency()
	local t = S.transparency / 100
	for _, e in ipairs(bgs) do e.o.BackgroundTransparency = e.base + (1 - e.base) * t end
end
accA, accB = accent(S.hue), accent2(S.hue)

---------------------------------------------------------------------
-- Root GUI
---------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "VisionX", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100 }, GuiRoot)
local clickSnd = new("Sound", { Name = "Click", SoundId = "rbxassetid://6895079853", Volume = 0.5 }, gui)
clickFn = function()
	if S.sound then
		clickSnd.PlaybackSpeed = 0.95 + math.random() * 0.1
		clickSnd.Volume = S.soundVol / 100
		clickSnd:Play()
	end
end

local W, H = 560, 420
local shadow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1 }, gui)
local shadowScale = new("UIScale", { Scale = 0.9 }, shadow)
local sh1 = new("Frame", { Position = UDim2.fromOffset(-18, -12), Size = UDim2.fromOffset(W + 36, H + 38), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0 }, shadow)
corner(sh1, 38)
local sh2 = new("Frame", { Position = UDim2.fromOffset(-9, -5), Size = UDim2.fromOffset(W + 18, H + 20), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0 }, shadow)
corner(sh2, 28)
local main = new("CanvasGroup", { Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = BLACK, BorderSizePixel = 0, Active = true, GroupTransparency = 1 }, gui)
rcorner(main, 18)
local mainStroke = stroke(main, Color3.new(1, 1, 1), 1.3, 0.35)
local mainGrad = gradient(mainStroke)
local scale = new("UIScale", { Scale = 0.9 }, main)
bg(main, 0, "main")
local sheen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, main)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.6, 0.985),
	NumberSequenceKeypoint.new(1, 1) }) }, sheen)
local topLine = new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, main)
local topGrad = new("UIGradient", {}, topLine)
onTheme(function(a, b)
	topGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(0.5, b), ColorSequenceKeypoint.new(1, a) })
end)

-- FPS overlay
local fpsLabel = txt(gui, { Name = "FPS", Text = "FPS: 0", Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(100, 16),
	Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0.4, Visible = false })

---------------------------------------------------------------------
-- Title bar
---------------------------------------------------------------------
local title = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = PANEL, BorderSizePixel = 0, Active = true }, main)
bg(title, 1, "panel")

local function winBtn(text, xoff, hov)
	local b = button(title, { Text = text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xoff, 0, 12), Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = CARD, TextColor3 = TEXT, TextSize = 14 })
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 10)
	stroke(b, LINE, 1, 0.5)
	b.MouseEnter:Connect(function() tw(b, 0.15, { BackgroundColor3 = hov }) end)
	b.MouseLeave:Connect(function() tw(b, 0.2, { BackgroundColor3 = CARD }) end)
	return b
end
local minBtn = winBtn("-", -50, Color3.fromRGB(56, 56, 68))
local closeBtn = winBtn("X", -14, Color3.fromRGB(190, 60, 70))

---------------------------------------------------------------------
-- Dragging
---------------------------------------------------------------------
local vp = cam().ViewportSize
local pos = Vector2.new(vp.X / 2, vp.Y / 2)
local target = pos
local function gs() return S.guiScale / 100 end
local function clampPos(v)
	local vs = cam().ViewportSize
	local w, h = W * gs(), H * gs()
	return Vector2.new(
		math.clamp(v.X, 40 - w / 2, vs.X - 40 + w / 2),
		math.clamp(v.Y, h / 2 - 10, vs.Y - 40 + h / 2))
end
local function fitOnScreen(v)
	local vs = cam().ViewportSize
	local w, h = W * gs(), H * gs()
	return Vector2.new(
		math.clamp(v.X, math.min(w / 2, vs.X / 2), math.max(vs.X - w / 2, vs.X / 2)),
		math.clamp(v.Y, math.min(h / 2, vs.Y / 2), math.max(vs.Y - h / 2, vs.Y / 2)))
end
main.Position = UDim2.fromOffset(pos.X, pos.Y)

local dragging, dInput, dStart, dOrigin = false, nil, nil, nil
local dragRate = 17
local function sink() return Enum.ContextActionResult.Sink end
local function stopDrag()
	dragging = false
	CAS:UnbindAction("VisionXSink")
end
connect(title.InputBegan, function(i)
	if S.lock then return end
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging, dInput = true, i
		dStart, dOrigin = Vector2.new(i.Position.X, i.Position.Y), target
		CAS:BindActionAtPriority("VisionXSink", sink, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
	end
end)
connect(UIS.InputChanged, function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i == dInput) then
		target = clampPos(dOrigin + (Vector2.new(i.Position.X, i.Position.Y) - dStart))
	end
end)
connect(UIS.InputEnded, function(i)
	if dragging and (i == dInput or i.UserInputType == Enum.UserInputType.MouseButton1) then stopDrag() end
end)
connect(RunService.RenderStepped, function(dt)
	pos = pos:Lerp(target, 1 - math.exp(-dt * dragRate))
	main.Position = UDim2.fromOffset(pos.X, pos.Y)
	shadow.Position = main.Position
	shadowScale.Scale = scale.Scale
	shadow.Visible = main.Visible
	local gt = main.GroupTransparency
	sh1.BackgroundTransparency = 0.9 + 0.1 * gt
	sh2.BackgroundTransparency = 0.8 + 0.2 * gt
	topGrad.Offset = Vector2.new(math.sin(os.clock() * 0.9), 0)
end)
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function() target = clampPos(target) end)

---------------------------------------------------------------------
-- Sidebar + content
---------------------------------------------------------------------
local sidebar = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0, 168, 1, -24), BackgroundTransparency = 1, BorderSizePixel = 0 }, main)

-- brand
local logo = new("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sidebar)
rcorner(logo, 10)
gradient(logo)
txt(logo, { Text = "V", Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center })
local brand = txt(sidebar, { Text = "Vision X (" .. VERSION .. ")", Position = UDim2.fromOffset(44, 2), Size = UDim2.new(1, -44, 0, 18),
	Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = Color3.new(1, 1, 1) })
local brandGrad = gradient(brand)
connect(RunService.RenderStepped, function() brandGrad.Rotation = (os.clock() * 25) % 360 end)
txt(sidebar, { Text = "Toolkit", Position = UDim2.fromOffset(44, 19), Size = UDim2.new(1, -44, 0, 14), TextSize = 10, TextColor3 = DIM })

-- profile card
local prof = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = CARD,
	Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, sidebar)
rcorner(prof, 12); stroke(prof, LINE, 1, 0.6); bg(prof, 0, "card")
prof.MouseEnter:Connect(function() tw(prof, 0.15, { BackgroundColor3 = Color3.fromRGB(44, 44, 54) }) end)
prof.MouseLeave:Connect(function() tw(prof, 0.2, { BackgroundColor3 = CARD }) end)
local avatar = new("ImageLabel", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, ImageTransparency = 1 }, prof)
corner(avatar, 17)
gradient(stroke(avatar, Color3.new(1, 1, 1), 1.5, 0))
txt(prof, { Text = LP.DisplayName, Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -74, 0, 17), TextSize = 12, Font = Enum.Font.GothamBold,
	TextTruncate = Enum.TextTruncate.AtEnd })
txt(prof, { Text = "@" .. LP.Name, Position = UDim2.fromOffset(50, 25), Size = UDim2.new(1, -74, 0, 14), TextSize = 10, TextColor3 = DIM,
	TextTruncate = Enum.TextTruncate.AtEnd })
txt(prof, { Text = ">", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(14, 20), TextSize = 18,
	TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center })
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok and avatar.Parent then
		avatar.Image = img
		tw(avatar, 0.3, { ImageTransparency = 0 })
	end
end)

-- content
local content = new("Frame", { Position = UDim2.fromOffset(192, 52), Size = UDim2.new(1, -204, 1, -64), BackgroundTransparency = 1,
	BorderSizePixel = 0, ClipsDescendants = true }, main)
local HDR = 0

local pages, current = {}, nil
local COLS = {}
local function colFor(sc, order)
	local c = COLS[sc]
	if not c then return sc end
	return order >= c.split and c.right or c.left
end
local function makePage(name, split)
	local g = new("CanvasGroup", { Name = name, Position = UDim2.fromOffset(0, HDR), Size = UDim2.new(1, 0, 1, -HDR), BackgroundTransparency = 1, Visible = false,
		GroupTransparency = 1 }, content)
	local sc = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never }, g)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 12), PaddingRight = UDim.new(0, 8) }, sc)
	if split then
		local row = new("Frame", { Name = "Cols", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, sc)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top }, row)
		local function col(order)
			local f = new("Frame", { Name = "Col", Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
				LayoutOrder = order }, row)
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, f)
			return f
		end
		COLS[sc] = { left = col(1), right = col(2), split = split }
	else
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sc)
	end
	pages[name] = g
	return sc
end

-- tabs with a sliding highlight
local switchTo
local TAB_H, TAB_STEP = 28, 31
local mainTabs = { { "Main", "Home" }, { "Player", "User" }, { "Visuals", "Cam" }, { "Murder Mystery 2", "Knife" }, { "Server", "Server" }, { "Customize", "Paint" }, { "Settings", "Gear" } }
local utilTabs = { { "Favorites", "Star" }, { "Search", "Search" }, { "Changelog", "Log" } }
local tabIndex, catBtns = {}, {}
local tabHolder = new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, #mainTabs * TAB_STEP), BackgroundTransparency = 1 }, sidebar)
local hl = new("Frame", { Size = UDim2.new(1, 0, 0, TAB_H), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, tabHolder)
rcorner(hl, 10)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(88, 88, 100), Color3.fromRGB(58, 58, 68)), Rotation = 90 }, hl)
stroke(hl, Color3.new(1, 1, 1), 1, 0.88)
for i, t in ipairs(mainTabs) do
	local n = t[1]
	tabIndex[n] = i
	local b = button(tabHolder, { Text = n, Position = UDim2.fromOffset(0, (i - 1) * TAB_STEP), Size = UDim2.new(1, 0, 0, TAB_H),
		BackgroundTransparency = 1, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12 })
	new("UIPadding", { PaddingLeft = UDim.new(0, 12) }, b)
	catBtns[n] = { b = b }
	b.MouseEnter:Connect(function() if current ~= n then tw(b, 0.15, { TextColor3 = TEXT }) end end)
	b.MouseLeave:Connect(function() if current ~= n then tw(b, 0.2, { TextColor3 = DIM }) end end)
	b.MouseButton1Click:Connect(function() switchTo(n) end)
end
local util = new("Frame", { Position = UDim2.fromOffset(0, 48 + #mainTabs * TAB_STEP + 8), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, sidebar)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, util)
for i, t in ipairs(utilTabs) do
	local n = t[1]
	local b = button(util, { Text = t[2], LayoutOrder = i, Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = CARD, TextColor3 = DIM, TextSize = 11 })
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 10)
	catBtns[n] = { b = b, util = true }
	b.MouseEnter:Connect(function() if current ~= n then tw(b, 0.15, { TextColor3 = TEXT }) end end)
	b.MouseLeave:Connect(function() if current ~= n then tw(b, 0.2, { TextColor3 = DIM }) end end)
	b.MouseButton1Click:Connect(function() switchTo(n) end)
end
prof.MouseButton1Click:Connect(function() switchTo("Settings") end)

local function updateCats()
	for n, c in pairs(catBtns) do
		local on = n == current
		tw(c.b, 0.2, { TextColor3 = on and TEXT or DIM })
		if c.util then tw(c.b, 0.2, { BackgroundColor3 = on and Color3.fromRGB(70, 70, 82) or CARD }) end
	end
	local idx = tabIndex[current]
	if idx then
		tw(hl, 0.32, { Position = UDim2.fromOffset(0, (idx - 1) * TAB_STEP), BackgroundTransparency = 0 })
	else
		tw(hl, 0.2, { BackgroundTransparency = 1 })
	end
end
function switchTo(name)
	if name == current then return end
	current = name
	for n, p in pairs(pages) do
		if n == name then
			p.Visible = true
			p.Position = UDim2.fromOffset(18, HDR)
			p.GroupTransparency = 1
			tw(p, 0.32, { Position = UDim2.fromOffset(0, HDR), GroupTransparency = 0 })
		elseif p.Visible then
			tw(p, 0.18, { Position = UDim2.fromOffset(-18, HDR), GroupTransparency = 1 })
			task.delay(0.2 / ANIM, function() if current ~= n then p.Visible = false end end)
		end
	end
	updateCats()
end

---------------------------------------------------------------------
-- Control builders
---------------------------------------------------------------------
local TG, SL, ACT, lastLabel = {}, {}, {}, nil
local CARDS, FAV = {}, {}
local function card(sc, h, order)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true }, colFor(sc, order))
	rcorner(f, 14)
	local st = stroke(f, LINE, 1, 0.6)
	bg(f, 0, "card")
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 215)), Rotation = 90 }, f)
	f.MouseEnter:Connect(function() tw(st, 0.2, { Color = Color3.fromRGB(90, 90, 108), Transparency = 0.2 }) end)
	f.MouseLeave:Connect(function() tw(st, 0.25, { Color = LINE, Transparency = 0.6 }) end)
	return f
end
local STAR_OFF = Color3.fromRGB(80, 80, 92)
local function cardLabel(c, text, sub)
	lastLabel = text
	local lbl = txt(c, { Text = text, Position = UDim2.fromOffset(10, 9), Size = UDim2.new(1, -90, 0, 20), Font = Enum.Font.GothamBold, TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd })
	local star = new("TextButton", { Text = "*", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
		TextColor3 = STAR_OFF, TextSize = 13, Font = Enum.Font.GothamBold, AutoButtonColor = false, BorderSizePixel = 0 }, c)
	local function place()
		local maxX = c.AbsoluteSize.X > 0 and (c.AbsoluteSize.X - 84) or 9999
		star.Position = UDim2.fromOffset(math.min(10 + lbl.TextBounds.X + 4, maxX), 10)
	end
	lbl:GetPropertyChangedSignal("TextBounds"):Connect(place)
	place()
	local e = { name = text, desc = sub or "", card = c, parent = c.Parent, order = c.LayoutOrder, star = star }
	table.insert(CARDS, e)
	star.MouseButton1Click:Connect(function() clickFn() if FAV.toggle then FAV.toggle(e) end end)
	if sub then
		txt(c, { Text = sub, Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -72, 0, 24), TextSize = 11,
			TextColor3 = DIM, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	end
end

local function toggleOn() return Color3.fromHSV(S.hue % 1, 0.3, 0.68) end
local function makeToggle(parent, cb)
	local track = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(44, 24),
		Text = "", AutoButtonColor = false, BackgroundColor3 = OFFC, BorderSizePixel = 0 }, parent)
	corner(track, 12)
	local tst = stroke(track, Color3.new(1, 1, 1), 2, 1)
	local thumb = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	corner(thumb, 9)
	local o = { state = false }
	local bar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 3, 0.2, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	corner(bar, 2)
	gradient(bar)
	local nm = lastLabel
	local function flash()
		local st = parent:FindFirstChildOfClass("UIStroke")
		if not st then return end
		tw(st, 0.12, { Color = accA, Transparency = 0 })
		task.delay(0.45 / ANIM, function() tw(st, 0.4, { Color = LINE, Transparency = 0.6 }) end)
	end
	local function render()
		tw(track, 0.25, { BackgroundColor3 = o.state and toggleOn() or OFFC })
		tw(tst, 0.25, { Transparency = o.state and 0.55 or 1, Color = toggleOn() })
		tw(bar, 0.3, { BackgroundTransparency = o.state and 0 or 1, Size = UDim2.new(0, 3, o.state and 0.6 or 0.2, 0) })
		tw(thumb, 0.32, { Position = UDim2.new(0, o.state and 23 or 3, 0.5, 0) }, B)
	end
	onTheme(function() if o.state then track.BackgroundColor3 = toggleOn() tst.Color = toggleOn() end end)
	function o.Set(v, silent)
		o.state = v and true or false
		render()
		if not silent then
			if o.state then flash() end
			if nm then notifyFn(nm, o.state) end
			if cb then cb(o.state) end
		end
	end
	track.MouseButton1Down:Connect(function() tw(thumb, 0.1, { Size = UDim2.fromOffset(22, 18) }) end)
	track.MouseButton1Up:Connect(function() tw(thumb, 0.15, { Size = UDim2.fromOffset(18, 18) }) end)
	track.MouseButton1Click:Connect(function() clickFn() o.Set(not o.state) end)
	if lastLabel then TG[lastLabel:lower()] = o end
	return o
end

local function makeSlider(parent, scroller, o)
	local ty = o.y or 44
	local track = new("Frame", { Position = UDim2.new(0, 10, 0, ty), Size = UDim2.new(1, -72, 0, 6),
		BackgroundColor3 = o.rainbow and Color3.new(1, 1, 1) or Color3.fromRGB(52, 52, 62), BorderSizePixel = 0 }, parent)
	corner(track, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		Visible = not o.rainbow }, track)
	corner(fill, 3)
	local fg = new("UIGradient", {}, fill)
	local thumb = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, track)
	corner(thumb, 8)
	local thumbSt = stroke(thumb, Color3.fromRGB(44, 44, 54), 3, 0)
	local hit = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, track)

	local box
	if o.rainbow then
		local kps = {}
		for i = 0, 6 do table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 0.75, 1))) end
		new("UIGradient", { Color = ColorSequence.new(kps) }, track)
		box = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, ty - 9), Size = UDim2.fromOffset(46, 24),
			BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
		corner(box, 6)
		stroke(box, Color3.new(1, 1, 1), 1.5, 0.3)
		if not o.colorOf then onTheme(function(a) box.BackgroundColor3 = a end) end
	else
		box = new("TextBox", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, ty - 9), Size = UDim2.fromOffset(46, 24),
			BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = DIM,
			ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Right }, parent)
		onTheme(function(a, b) fg.Color = ColorSequence.new(a, b) end)
	end

	local s = { value = o.default }
	function s.Set(v, silent)
		v = math.clamp(math.floor(v + 0.5), o.min, o.max)
		s.value = v
		local a = (v - o.min) / (o.max - o.min)
		tw(fill, 0.06, { Size = UDim2.fromScale(a, 1) }, Enum.EasingStyle.Quad)
		tw(thumb, 0.06, { Position = UDim2.fromScale(a, 0.5) }, Enum.EasingStyle.Quad)
		if box:IsA("TextBox") then box.Text = o.fmt and o.fmt(v) or tostring(v) end
		if o.colorOf then box.BackgroundColor3 = o.colorOf(v) end
		if not silent and o.onChange then o.onChange(v) end
	end
	if box:IsA("TextBox") then
		box.FocusLost:Connect(function()
			local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
			if n then s.Set(n) else s.Set(s.value, true) end
		end)
	end

	local drag, dI, sfCur = false, nil, nil
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		s.Set(o.min + a * (o.max - o.min))
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag, dI = true, i
			sfCur = parent:FindFirstAncestorOfClass("ScrollingFrame") or scroller
			sfCur.ScrollingEnabled = false
			tw(thumb, 0.12, { Size = UDim2.fromOffset(20, 20) })
			tw(thumbSt, 0.12, { Color = accA })
			fromX(i.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i == dI) then fromX(i.Position.X) end
	end)
	connect(UIS.InputEnded, function(i)
		if drag and (i == dI or i.UserInputType == Enum.UserInputType.MouseButton1) then
			drag = false
			(sfCur or scroller).ScrollingEnabled = true
			tw(thumb, 0.15, { Size = UDim2.fromOffset(16, 16) })
			tw(thumbSt, 0.25, { Color = Color3.fromRGB(44, 44, 54) })
		end
	end)
	s.Set(o.default, true)
	if lastLabel then SL[lastLabel:lower()] = s end
	return s
end

---------------------------------------------------------------------
-- Pages Initialization
---------------------------------------------------------------------
local TWOCOL = W >= 640
local mainSc = makePage("Main", TWOCOL and 100 or nil)
local playerSc = makePage("Player", TWOCOL and 100 or nil)
local visSc = makePage("Visuals", TWOCOL and 100 or nil)
local mm2Sc = makePage("Murder Mystery 2", TWOCOL and 100 or nil)
local serverSc = makePage("Server", TWOCOL and 100 or nil)
local custSc = makePage("Customize", TWOCOL and 100 or nil)
local favSc = makePage("Favorites")
local searchSc = makePage("Search")
local chgSc = makePage("Changelog")
local setSc = makePage("Settings", TWOCOL and 100 or nil)

local ctl = {}
ctl.baseGrav = workspace.Gravity
ctl.espTeam, ctl.espEnemy = Color3.fromHSV(0.6, 0.73, 1), Color3.fromHSV(0, 0.73, 1)

-- Init GUI Switch
applyTheme()
applyTransparency()
current = nil
switchTo("Main")

tw(main, 0.45, { GroupTransparency = 0 })
tw(scale, 0.55, { Scale = gs() }, Enum.EasingStyle.Back)
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
local GuiRoot = PlayerGui
do
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then GuiRoot = h end
end
for _, root in ipairs({ PlayerGui, GuiRoot }) do
	for _, n in ipairs({ "VisionX", "VisionXESP" }) do
		local old = root:FindFirstChild(n)
		if old then old:Destroy() end
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

local VERSION = "V12"
local ANIM = 1
local function tw(o, t, props, style, dir)
	local tween = TweenService:Create(o, TweenInfo.new(t / ANIM, style or Q, dir or OUT), props)
	tween:Play()
	return tween
end
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
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
	dashPow = 90, dashCd = 10, wcSpeed = 25, followDist = 6, url = "", pins = {}, notify = true, fcSpeed = 60,
	sprintMul = 18, xrayT = 60, soundVol = 50, sound = false, camMode = 1, sky = 1, favs = {} }
local S = {}
for k, v in pairs(D) do S[k] = v end
local F = { roles = false, plat = false, sprint = false, xray = false, chatCmd = false, wc = false, stats = false, alerts = false, hide = false, rainbow = false, glow = false, fg = false, ctp = false, sit = false, afk = false, spin = false, fb = false, fpsb = false, fly = false, noclip = false, inf = false, jp = false, ws = false, grav = false, esp = false, fps = false,
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

local W, H = 720, 360
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
local minBtn = winBtn("\226\136\146", -50, Color3.fromRGB(56, 56, 68))
local closeBtn = winBtn("X", -14, Color3.fromRGB(190, 60, 70))

---------------------------------------------------------------------
-- Dragging (smooth, weighted, camera-safe)
---------------------------------------------------------------------
local vp = cam().ViewportSize
local pos = Vector2.new(vp.X / 2, vp.Y / 2)
local target = pos
local function gs() return S.guiScale / 100 end
local function clampPos(v) -- loose: window may leave the screen, but 40px always stays reachable
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
txt(prof, { Text = "\226\128\186", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(14, 20), TextSize = 18,
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

-- content (two columns per page)
local content = new("Frame", { Position = UDim2.fromOffset(192, 52), Size = UDim2.new(1, -204, 1, -64), BackgroundTransparency = 1,
	BorderSizePixel = 0, ClipsDescendants = true }, main)
local HDR = 0
local hdrLbl = { Text = "" }

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
local mainTabs = { { "Main", "\240\159\143\160" }, { "Player", "\240\159\145\164" }, { "Visuals", "\240\159\142\165" }, { "Server", "\240\159\140\144" }, { "Customize", "\240\159\142\168" }, { "Settings", "\226\154\153" } }
local utilTabs = { { "Favorites", "\226\152\133" }, { "Search", "\240\159\148\141" }, { "Changelog", "\240\159\147\139" } }
local tabIndex, catBtns = {}, {}
local tabHolder = new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, #mainTabs * TAB_STEP), BackgroundTransparency = 1 }, sidebar)
local hl = new("Frame", { Size = UDim2.new(1, 0, 0, TAB_H), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, tabHolder)
rcorner(hl, 10)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(88, 88, 100), Color3.fromRGB(58, 58, 68)), Rotation = 90 }, hl)
stroke(hl, Color3.new(1, 1, 1), 1, 0.88)
for i, t in ipairs(mainTabs) do
	local n = t[1]
	tabIndex[n] = i
	local b = button(tabHolder, { Text = t[2] .. "   " .. n, Position = UDim2.fromOffset(0, (i - 1) * TAB_STEP), Size = UDim2.new(1, 0, 0, TAB_H),
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
	local b = button(util, { Text = t[2], LayoutOrder = i, Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = CARD, TextColor3 = DIM, TextSize = 14 })
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
	local star = new("TextButton", { Text = "\226\152\133", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
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
-- Pages
---------------------------------------------------------------------
local function cycBtn(c, w, text, onClick)
	local b = button(c, { Text = text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(w, 22),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 11 })
	stroke(b, LINE, 1)
	b.MouseButton1Click:Connect(onClick)
	return b
end
local function dropBtn(c, w, text, options, onPick)
	local b = button(c, { Text = text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(w, 26),
		BackgroundColor3 = Color3.fromRGB(24, 24, 29), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
	stroke(b, LINE, 1, 0.5)
	local chev = txt(b, { Text = "\226\150\190", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 14),
		TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Center })
	local h0 = c.Size.Y.Offset
	local list = new("Frame", { Position = UDim2.fromOffset(10, h0 + 2), Size = UDim2.new(1, -20, 0, #options * 28), BackgroundTransparency = 1 }, c)
	local btns, open = {}, false
	local function mark()
		for i, ob in ipairs(btns) do
			tw(ob, 0.15, { BackgroundColor3 = options[i] == b.Text and Color3.fromRGB(64, 64, 78) or Color3.fromRGB(24, 24, 29) })
		end
	end
	local function setOpen(v)
		open = v
		if v then mark() end
		tw(c, 0.3, { Size = UDim2.new(1, 0, 0, v and (h0 + 8 + #options * 28) or h0) })
		tw(chev, 0.25, { Rotation = v and 180 or 0 })
	end
	for i, name in ipairs(options) do
		local ob = button(list, { Text = name, Position = UDim2.fromOffset(0, (i - 1) * 28), Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Color3.fromRGB(24, 24, 29), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left })
		new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, ob)
		btns[i] = ob
		ob.MouseButton1Click:Connect(function()
			onPick(i)
			setOpen(false)
		end)
	end
	b.MouseButton1Click:Connect(function() setOpen(not open) end)
	return b
end
local function pickerFor(c, box)
	local pad = box:FindFirstChildOfClass("UIPadding")
	if pad then pad.PaddingRight = UDim.new(0, 32) end
	local h0 = c.Size.Y.Offset
	local btn = button(c, { Text = "\226\150\190", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 34), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.fromRGB(46, 46, 58), TextSize = 11 })
	local lst = new("ScrollingFrame", { Position = UDim2.fromOffset(10, h0 + 2), Size = UDim2.new(1, -20, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, c)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, lst)
	local open = false
	local function setOpen(v)
		open = v
		for _, ch in ipairs(lst:GetChildren()) do
			if ch:IsA("TextButton") or ch.Name == "Msg" then ch:Destroy() end
		end
		local n = 0
		if v then
			box:ReleaseFocus()
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LP then table.insert(list, p) end
			end
			table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
			for i, p in ipairs(list) do
				n += 1
				local ob = button(lst, { Text = p.DisplayName .. "  (@" .. p.Name .. ")", LayoutOrder = i, Size = UDim2.new(1, -6, 0, 26),
					BackgroundColor3 = Color3.fromRGB(24, 24, 29), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
				new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, ob)
				ob.MouseButton1Click:Connect(function()
					box.Text = p.Name
					setOpen(false)
				end)
			end
			if n == 0 then
				txt(lst, { Name = "Msg", Text = "No other players in the server", Size = UDim2.new(1, 0, 0, 26), TextSize = 11, TextColor3 = DIM })
			end
		end
		local rows = math.min(math.max(n, 1), 5)
		tw(lst, 0.3, { Size = UDim2.new(1, -20, 0, v and rows * 28 or 0) })
		tw(c, 0.3, { Size = UDim2.new(1, 0, 0, v and (h0 + 8 + rows * 28) or h0) })
		tw(btn, 0.25, { Rotation = v and 180 or 0 })
	end
	btn.MouseButton1Click:Connect(function() setOpen(not open) end)
end
local mainSc, playerSc, visSc, serverSc, custSc, favSc, searchSc, chgSc, setSc = makePage("Main", 100), makePage("Player", 100), makePage("Visuals", 100), makePage("Server", 100), makePage("Customize", 100), makePage("Favorites"), makePage("Search"), makePage("Changelog"), makePage("Settings", 100)
local function section(sc, text, order)
	local l = txt(colFor(sc, order), { Text = text, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = TEXT, TextYAlignment = Enum.TextYAlignment.Top })
	local u = new("Frame", { Position = UDim2.new(0, 1, 1, -4), Size = UDim2.fromOffset(24, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, l)
	corner(u, 1)
	gradient(u)
	return l
end
section(mainSc, "Movement", 1); section(mainSc, "Abilities", 100); section(mainSc, "Tools", 110)
section(playerSc, "Players", 0); section(playerSc, "Teleport", 100); section(playerSc, "Character", 110)
section(visSc, "Players", 0); section(visSc, "Camera", 3); section(visSc, "World", 100); section(visSc, "Overlays", 110)
section(serverSc, "Connection", 0); section(serverSc, "Performance", 5); section(serverSc, "Extras", 100)
section(custSc, "Theme", 0); section(custSc, "Layout", 6); section(custSc, "Motion and input", 100); section(custSc, "Overlay colors", 110); section(custSc, "Shortcuts", 120)
section(setSc, "Behavior", 0); section(setSc, "Data", 100)
local ctl = {}
ctl.baseGrav = workspace.Gravity
ctl.espTeam, ctl.espEnemy = Color3.fromHSV(0.6, 0.73, 1), Color3.fromHSV(0, 0.73, 1)

-- TP ---------------------------------------------------------------
do
	local c = card(playerSc, 122, 1)
	cardLabel(c, "TP")
	local box = new("TextBox", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		PlaceholderText = "Type Name", PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TEXT,
		ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, c)
	corner(box, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	local bst = stroke(box, LINE, 1)
	box.Focused:Connect(function() tw(bst, 0.2, { Color = accA }) end)
	box.FocusLost:Connect(function() tw(bst, 0.25, { Color = LINE }) end)

	local go = button(c, { Text = "CLICK", Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 28),
		BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.fromRGB(10, 10, 12) })
	gradient(go)
	local status = txt(c, { Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 16), TextSize = 10, TextColor3 = DIM, Text = "Name, display name or part of one" })

	local function setStatus(t, col)
		status.Text = t
		status.TextColor3 = col
		tw(status, 0.3, { TextColor3 = DIM }).Completed:Connect(function() end)
	end
	local function find(q)
		q = string.lower(q):match("^%s*(.-)%s*$")
		if q == "" then return nil, 0 end
		local best, bestScore, bestLen, ties = nil, 0, math.huge, 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP then
				local n, d = p.Name:lower(), p.DisplayName:lower()
				local sc = 0
				if n == q or d == q then sc = 4
				elseif n:sub(1, #q) == q or d:sub(1, #q) == q then sc = 3
				elseif n:find(q, 1, true) or d:find(q, 1, true) then sc = 2 end
				if sc > 0 then
					local len = math.min(#n, #d)
					if sc > bestScore then best, bestScore, bestLen, ties = p, sc, len, 1
					elseif sc == bestScore then
						ties += 1
						if len < bestLen then best, bestLen = p, len end
					end
				end
			end
		end
		return best, ties
	end
	ctl.find = find
	local function doTP()
		local p, n = find(box.Text)
		if box.Text:match("^%s*$") then return setStatus("Type a name first", Color3.fromRGB(255, 120, 120)) end
		if not p then return setStatus("No player found", Color3.fromRGB(255, 120, 120)) end
		local myR = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		local tR = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not (myR and tR) then return setStatus(p.DisplayName .. " has no character", Color3.fromRGB(255, 120, 120)) end
		myR.CFrame = tR.CFrame * CFrame.new(0, 0, 4)
		setStatus(n > 1 and ("Teleported to " .. p.DisplayName .. " (" .. n .. " similar)") or ("Teleported to " .. p.DisplayName), GREEN)
	end
	go.MouseButton1Click:Connect(doTP)
	pickerFor(c, box)
	box.FocusLost:Connect(function(enter) if enter then doTP() end end)
end

-- Spectate ---------------------------------------------------------
do
	local c = card(playerSc, 122, 2)
	cardLabel(c, "Spectate")
	local box = new("TextBox", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		PlaceholderText = "Type Name", PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TEXT,
		ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, c)
	corner(box, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	local bst = stroke(box, LINE, 1)
	box.Focused:Connect(function() tw(bst, 0.2, { Color = accA }) end)
	box.FocusLost:Connect(function() tw(bst, 0.25, { Color = LINE }) end)
	local btn = button(c, { Text = "SPECTATE", Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 28),
		BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.fromRGB(10, 10, 12) })
	gradient(btn)
	local status = txt(c, { Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 16), TextSize = 10, TextColor3 = DIM, Text = "Not spectating" })
	local RED_ = Color3.fromRGB(255, 120, 120)
	function ctl.specUI(active, p)
		btn.Text = active and "STOP" or "SPECTATE"
		status.Text = active and ("Spectating " .. p.DisplayName) or "Not spectating"
		status.TextColor3 = active and GREEN or DIM
	end
	local function go()
		if ctl.specTarget then return ctl.specStop() end
		if box.Text:match("^%s*$") then status.Text, status.TextColor3 = "Type a name first", RED_ return end
		local p = ctl.find(box.Text)
		if not p then status.Text, status.TextColor3 = "No player found", RED_ return end
		ctl.specStart(p)
	end
	btn.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter and not ctl.specTarget then go() end end)
	pickerFor(c, box)
end

-- Force Reset ------------------------------------------------------
do
	local fr = button(colFor(playerSc, 113), { Text = "Force Reset", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 113,
		BackgroundColor3 = Color3.fromRGB(46, 18, 22), TextColor3 = Color3.fromRGB(255, 110, 115) })
	stroke(fr, Color3.fromRGB(150, 40, 50), 1)
	fr.MouseEnter:Connect(function() tw(fr, 0.15, { BackgroundColor3 = Color3.fromRGB(70, 24, 30) }) end)
	fr.MouseLeave:Connect(function() tw(fr, 0.2, { BackgroundColor3 = Color3.fromRGB(46, 18, 22) }) end)
	fr.MouseButton1Click:Connect(function() ctl.forceReset() end)
	ACT["force reset"] = function() ctl.forceReset() end
end

-- Follow / Respawn In Place ----------------------------------------
do
	local c = card(playerSc, 146, 3)
	cardLabel(c, "Follow")
	local box = new("TextBox", { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		PlaceholderText = "Type Name", PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TEXT,
		ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, c)
	corner(box, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	local bst = stroke(box, LINE, 1)
	box.Focused:Connect(function() tw(bst, 0.2, { Color = accA }) end)
	box.FocusLost:Connect(function() tw(bst, 0.25, { Color = LINE }) end)
	local btn = button(c, { Text = "FOLLOW", Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 28),
		BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.fromRGB(10, 10, 12) })
	gradient(btn)
	local status = txt(c, { Position = UDim2.fromOffset(10, 98), Size = UDim2.new(1, -20, 0, 14), TextSize = 10, TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "Distance to keep" })
	function ctl.followUI(active, p)
		btn.Text = active and "STOP" or "FOLLOW"
		status.Text = active and ("Following " .. p.DisplayName) or "Distance to keep"
		status.TextColor3 = active and GREEN or DIM
	end
	local function go()
		if ctl.followTarget then return ctl.followStop() end
		if box.Text:match("^%s*$") then status.Text, status.TextColor3 = "Type a name first", Color3.fromRGB(255, 120, 120) return end
		local p = ctl.find(box.Text)
		if not p then status.Text, status.TextColor3 = "No player found", Color3.fromRGB(255, 120, 120) return end
		ctl.followStart(p)
	end
	btn.MouseButton1Click:Connect(go)
	box.FocusLost:Connect(function(enter) if enter and not ctl.followTarget then go() end end)
	pickerFor(c, box)
	makeSlider(c, playerSc, { min = 2, max = 30, default = D.followDist, y = 126, onChange = function(v) S.followDist = v end })

	local rb = button(colFor(playerSc, 114), { Text = "Respawn In Place", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 114, BackgroundColor3 = CARD })
	stroke(rb, LINE, 1)
	rb.MouseEnter:Connect(function() tw(rb, 0.15, { BackgroundColor3 = Color3.fromRGB(32, 32, 40) }) end)
	rb.MouseLeave:Connect(function() tw(rb, 0.2, { BackgroundColor3 = CARD }) end)
	rb.MouseButton1Click:Connect(function() ctl.respawnHere() end)
	ACT["respawn in place"] = function() ctl.respawnHere() end
end

-- Flight -----------------------------------------------------------
do
	local c = card(mainSc, 68, 2)
	cardLabel(c, "Flight")
	makeToggle(c, function(v) F.fly = v end)
	ctl.flight = makeSlider(c, mainSc, { min = 0, max = 100, default = D.flight, onChange = function(v) S.flight = v end })
end
-- Noclip / Infinite Jump -------------------------------------------
do
	local c = card(mainSc, 40, 6)
	cardLabel(c, "Noclip")
	makeToggle(c, function(v) F.noclip = v end)
	local c2 = card(mainSc, 40, 5)
	cardLabel(c2, "Infinite Jump")
	makeToggle(c2, function(v) F.inf = v end)
end
-- Jump Power / Walkspeed -------------------------------------------
do
	local c = card(mainSc, 68, 4)
	cardLabel(c, "Jump Power")
	makeToggle(c, function(v)
		local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		F.jp = v
		if v and h then ctl.origJP = h.JumpPower elseif h and ctl.origJP then h.JumpPower = ctl.origJP end
	end)
	ctl.jump = makeSlider(c, mainSc, { min = 0, max = 300, default = D.jump, onChange = function(v) S.jump = v end })

	local c2 = card(mainSc, 68, 3)
	cardLabel(c2, "Walkspeed")
	makeToggle(c2, function(v)
		local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		F.ws = v
		if v and h then ctl.origWS = h.WalkSpeed elseif h and ctl.origWS then h.WalkSpeed = ctl.origWS end
	end)
	ctl.walk = makeSlider(c2, mainSc, { min = 0, max = 2000, default = D.walk, onChange = function(v) S.walk = v end })
end
-- No Gravity -------------------------------------------------------
do
	local c = card(mainSc, 56, 7)
	cardLabel(c, "No Gravity", "Jumps keep carrying you upward and falls drift down very slowly.")
	makeToggle(c, function(v)
		if v then ctl.origGrav = ctl.baseGrav elseif ctl.origGrav then workspace.Gravity = ctl.origGrav end
		F.grav = v
	end)
end
-- Spin / Anti-AFK --------------------------------------------------
do
	local c = card(mainSc, 68, 104)
	cardLabel(c, "Spin")
	makeToggle(c, function(v) F.spin = v end)
	ctl.spin = makeSlider(c, mainSc, { min = 1, max = 100, default = D.spin, onChange = function(v) S.spin = v end })

	local c2 = card(serverSc, 56, 4)
	cardLabel(c2, "Anti-AFK", "Nudges your character every 5 minutes so you don't get idle-kicked.")
	makeToggle(c2, function(v) F.afk = v; ctl.afkT = 0 end)

	local c3 = card(playerSc, 56, 101)
	cardLabel(c3, "Click TP", "Tap or click the world to teleport to that spot.")
	makeToggle(c3, function(v) F.ctp = v end)

	local c4 = card(playerSc, 40, 111)
	cardLabel(c4, "Sit")
	makeToggle(c4, function(v)
		F.sit = v
		if not v then
			local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if h then h.Sit = false end
		end
	end)

	local c6 = card(playerSc, 56, 112)
	cardLabel(c6, "Fling Guard", "Stops other players from flinging you.")
	makeToggle(c6, function(v)
		F.fg = v
		if not v then ctl.fgOff() end
	end)

	local c7 = card(mainSc, 56, 111)
	cardLabel(c7, "Commands", "Open a small box and type commands.")
	local ob = button(c7, { Text = "OPEN", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(52, 22),
		BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.fromRGB(10, 10, 12), TextSize = 11 })
	gradient(ob)
	ob.MouseButton1Click:Connect(function() ctl.cmdToggle(not ctl.cmdOpen) end)
end

-- Dash / Double Jump / Wall Climb ----------------------------------
do
	local c = card(mainSc, 68, 101)
	cardLabel(c, "Dash")
	local db = button(c, { Text = "DASH", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(60, 22),
		BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = Color3.fromRGB(10, 10, 12), TextSize = 11 })
	gradient(db)
	db.MouseButton1Click:Connect(function() ctl.dash() end)
	ACT["dash"] = function() ctl.dash() end
	makeSlider(c, mainSc, { min = 20, max = 300, default = D.dashPow, onChange = function(v) S.dashPow = v end })

	local c2 = card(mainSc, 68, 102)
	cardLabel(c2, "Dash Cooldown")
	makeSlider(c2, mainSc, { min = 0, max = 50, default = D.dashCd, fmt = function(v) return string.format("%.1fs", v / 10) end,
		onChange = function(v) S.dashCd = v end })

	local c4 = card(mainSc, 68, 103)
	cardLabel(c4, "Wall Climb")
	makeToggle(c4, function(v) F.wc = v end)
	makeSlider(c4, mainSc, { min = 5, max = 80, default = D.wcSpeed, onChange = function(v) S.wcSpeed = v end })

	local c5 = card(mainSc, 56, 8)
	cardLabel(c5, "Platform", "Walk on thin air. Jump to rise. Hold Q or Ctrl to lower.")
	makeToggle(c5, function(v)
		F.plat = v
		if not v then ctl.platOff() end
	end)

	local c6 = card(mainSc, 68, 9)
	cardLabel(c6, "Sprint Boost")
	makeToggle(c6, function(v)
		F.sprint = v
		if ctl.sprintBtn then ctl.sprintBtn.Visible = v end
	end)
	makeSlider(c6, mainSc, { min = 11, max = 40, default = D.sprintMul, fmt = function(v) return string.format("x%.1f", v / 10) end,
		onChange = function(v) S.sprintMul = v end })
end

-- ESP / FPS / FOV --------------------------------------------------
do
	local c = card(visSc, 56, 1)
	cardLabel(c, "ESP", "Names, distance and outlines through walls. Blue = team, red = enemy.")
	makeToggle(c, function(v) F.esp = v end)

	local cR = card(visSc, 56, 1)
	cardLabel(cR, "Role ESP", "Murder Mystery 2: murderer red, sheriff blue, innocent green.")
	makeToggle(cR, function(v)
		F.roles = v
		if v and TG["esp"] and not TG["esp"].state then TG["esp"].Set(true) end
	end)

	local c2 = card(visSc, 40, 111)
	cardLabel(c2, "FPS Counter")
	makeToggle(c2, function(v) F.fps = v; fpsLabel.Visible = v end)

	local c3 = card(visSc, 68, 4)
	cardLabel(c3, "FOV")
	local rst = button(c3, { Text = "Reset", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(52, 22),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 11 })
	stroke(rst, LINE, 1)
	rst.MouseEnter:Connect(function() tw(rst, 0.15, { BackgroundColor3 = Color3.fromRGB(44, 44, 54) }) end)
	rst.MouseLeave:Connect(function() tw(rst, 0.2, { BackgroundColor3 = Color3.fromRGB(30, 30, 38) }) end)
	ctl.fov = makeSlider(c3, visSc, { min = 30, max = 120, default = D.fov, onChange = function(v)
		S.fov = v
		F.fovActive, F.fovReturn = true, false
	end })
	function ctl.fovReset()
		S.fov = D.fov
		ctl.fov.Set(D.fov, true)
		F.fovActive, F.fovReturn = true, true
	end
	rst.MouseButton1Click:Connect(ctl.fovReset)

	local c4 = card(visSc, 40, 101)
	cardLabel(c4, "Fullbright")
	makeToggle(c4, function(v) ctl.fullbright(v) end)

	local c5 = card(visSc, 92, 5)
	cardLabel(c5, "Freecam", "Drone camera with on-screen controls. Menu minimizes while active.")
	ctl.fcT = makeToggle(c5, function(v) ctl.freecam(v) end)
	makeSlider(c5, visSc, { min = 10, max = 200, default = D.fcSpeed, y = 70, onChange = function(v) S.fcSpeed = v end })

	local c6 = card(visSc, 40, 112)
	cardLabel(c6, "Stats Overlay")
	makeToggle(c6, function(v) F.stats = v ctl.statsLabel.Visible = v end)

	local c7 = card(visSc, 56, 2)
	cardLabel(c7, "Hide Players", "Makes other players invisible on your screen only.")
	makeToggle(c7, function(v) F.hide = v end)

	local c8 = card(visSc, 56, 7)
	cardLabel(c8, "Noclip Camera", "The camera passes through walls so you can look through them.")
	makeToggle(c8, function(v) ctl.camNoclip(v) end)

	local c9 = card(visSc, 68, 102)
	cardLabel(c9, "X-Ray")
	makeToggle(c9, function(v) ctl.xray(v) end)
	makeSlider(c9, visSc, { min = 10, max = 95, default = D.xrayT, fmt = function(v) return v .. "%" end,
		onChange = function(v) S.xrayT = v ctl.xrayUpdate() end })

	local c10 = card(visSc, 40, 103)
	cardLabel(c10, "Sky")
	ctl.skyBtn = dropBtn(c10, 120, "Default", { "Default", "Sunset", "Night", "Galaxy", "Overcast", "Pink Dream", "Bright Day" }, function(i) ctl.setSky(i) end)

	local c11 = card(visSc, 40, 6)
	cardLabel(c11, "Camera Lock")
	ctl.camBtn = dropBtn(c11, 120, "Free", { "Free", "First Person", "Third Person" }, function(i) ctl.setCamMode(i) end)
end

-- Server -----------------------------------------------------------
do
	local function actionBtn(text, order)
		local b = button(colFor(serverSc, order), { Text = text, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = order, BackgroundColor3 = CARD })
		stroke(b, LINE, 1)
		b.MouseEnter:Connect(function() tw(b, 0.15, { BackgroundColor3 = Color3.fromRGB(32, 32, 40) }) end)
		b.MouseLeave:Connect(function() tw(b, 0.2, { BackgroundColor3 = CARD }) end)
		return b
	end
	local rj = actionBtn("Rejoin", 1)
	rj.MouseButton1Click:Connect(function() ctl.rejoin() end)
	local hop = actionBtn("Server Hop", 2)
	local st = txt(colFor(serverSc, 3), { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 3, TextSize = 10, TextColor3 = DIM, Text = "" })
	hop.MouseButton1Click:Connect(function()
		ctl.hop(function(t, col) st.Text, st.TextColor3 = t, col end)
	end)
	local c = card(serverSc, 56, 6)
	cardLabel(c, "FPS Boost", "Lowers shadows, effects and particles to raise FPS.")
	makeToggle(c, function(v) ctl.fpsBoost(v) end)

	local ca = card(serverSc, 40, 101)
	cardLabel(ca, "Join/Leave Alerts")
	makeToggle(ca, function(v) F.alerts = v end)

	local cr = card(serverSc, 112, 102)
	cardLabel(cr, "Auto Re-Execute")
	txt(cr, { Text = "Reloads Vision X after Rejoin or Server Hop. Paste your raw link, then press Save Settings.", Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 26), TextSize = 10, TextColor3 = DIM, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local ub = new("TextBox", { Position = UDim2.fromOffset(10, 58), Size = UDim2.new(1, -20, 0, 26), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		PlaceholderText = "https://pastebin.com/raw/...", PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = TEXT, ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd }, cr)
	corner(ub, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, ub)
	stroke(ub, LINE, 1)
	local ust = txt(cr, { Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -20, 0, 14), TextSize = 10, TextColor3 = DIM, Text = "" })
	ctl.urlBox = ub
	local arT = makeToggle(cr, function(v)
		if v then
			if S.url == "" then ust.Text, ust.TextColor3 = "Add your link first", Color3.fromRGB(255, 120, 120) return end
			local ok = ctl.queueReload()
			ust.Text, ust.TextColor3 = ok and "Queued for next teleport" or "Not supported by this executor", ok and GREEN or Color3.fromRGB(255, 120, 120)
		else
			ust.Text = ""
		end
	end)
	ub.FocusLost:Connect(function()
		S.url = ub.Text:match("^%s*(.-)%s*$")
		if arT.state then arT.Set(true) end
	end)
end

-- Settings ---------------------------------------------------------
do
	local c = card(custSc, 68, 1)
	cardLabel(c, "UI Theme")
	ctl.hue = makeSlider(c, setSc, { min = 0, max = 360, default = math.floor(D.hue * 360), rainbow = true,
		onChange = function(v) S.hue = v / 360; applyTheme() end })

	local c2 = card(custSc, 68, 5)
	cardLabel(c2, "Transparent")
	ctl.transp = makeSlider(c2, setSc, { min = 0, max = 100, default = 0, fmt = function(v) return v .. "%" end,
		onChange = function(v) S.transparency = v; applyTransparency() end })

	local c3 = card(custSc, 40, 103)
	cardLabel(c3, "Position Lock")
	ctl.lock = makeToggle(c3, function(v) S.lock = v; if v then stopDrag() end end)

	local cc = card(setSc, 56, 2)
	cardLabel(cc, "Chat Commands", "Type ;fly or ;ws 50 in chat. Other players can see what you type.")
	makeToggle(cc, function(v) F.chatCmd = v end)

	local cn = card(setSc, 56, 4)
	cardLabel(cn, "Notifications", "Small pop-up when you switch a feature on or off.")
	makeToggle(cn, function(v) S.notify = v end)

	local cso = card(setSc, 68, 3)
	cardLabel(cso, "Click Sounds")
	makeToggle(cso, function(v) S.sound = v end)
	makeSlider(cso, setSc, { min = 0, max = 100, default = D.soundVol, fmt = function(v) return v .. "%" end, onChange = function(v) S.soundVol = v end })

	local sv = button(colFor(setSc, 101), { Text = "Save Settings", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 101,
		BackgroundColor3 = Color3.fromRGB(24, 24, 30) })
	gradient(stroke(sv, Color3.new(1, 1, 1), 1.2, 0.15))
	sv.MouseEnter:Connect(function() tw(sv, 0.15, { BackgroundColor3 = Color3.fromRGB(36, 36, 46) }) end)
	sv.MouseLeave:Connect(function() tw(sv, 0.2, { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }) end)
	sv.MouseButton1Click:Connect(function()
		sv.Text = ctl.save() and "Saved \226\156\147" or "Saving not supported"
		task.delay(1.5, function() if sv.Parent then sv.Text = "Save Settings" end end)
	end)

	local rb = button(colFor(setSc, 102), { Text = "Reset All Settings", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 102,
		BackgroundColor3 = Color3.fromRGB(46, 18, 22), TextColor3 = Color3.fromRGB(255, 110, 115) })
	stroke(rb, Color3.fromRGB(150, 40, 50), 1)
	rb.MouseEnter:Connect(function() tw(rb, 0.15, { BackgroundColor3 = Color3.fromRGB(70, 24, 30) }) end)
	rb.MouseLeave:Connect(function() tw(rb, 0.2, { BackgroundColor3 = Color3.fromRGB(46, 18, 22) }) end)
	rb.MouseButton1Click:Connect(function()
		ctl.hue.Set(D.hue * 360)
		ctl.transp.Set(D.transparency)
		ctl.lock.Set(D.lock)
		ctl.flight.Set(D.flight)
		ctl.jump.Set(D.jump)
		ctl.walk.Set(D.walk)
		ctl.spin.Set(D.spin)
		ctl.resetCustom()
		ctl.fov.Set(D.fov, true)
		ctl.fovReset()
	end)
end

---------------------------------------------------------------------
-- Feature logic
---------------------------------------------------------------------
-- Favorites / Search / Changelog -----------------------------------
do
	local STAR = Color3.fromRGB(255, 210, 60)
	local favHint = txt(favSc, { Text = "Tap the star on any control to add it to this tab.", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = -1,
		TextSize = 11, TextColor3 = DIM, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	FAV.n = 0
	function FAV.set(e, on)
		on = on and true or false
		if (e.fav or false) == on then return end
		e.fav = on
		if on then
			FAV.n += 1
			e.card.Parent = favSc
			e.card.LayoutOrder = FAV.n
		else
			e.card.Parent = e.parent
			e.card.LayoutOrder = e.order
		end
		tw(e.star, 0.2, { TextColor3 = on and STAR or STAR_OFF })
		local list, cnt = {}, 0
		for _, x in ipairs(CARDS) do
			if x.fav then
				table.insert(list, x.name)
				cnt += 1
			end
		end
		S.favs = list
		favHint.Visible = cnt == 0
	end
	function FAV.toggle(e) FAV.set(e, not e.fav) end
	function FAV.setByName(n)
		for _, e in ipairs(CARDS) do
			if e.name == n then FAV.set(e, true) return end
		end
	end

	-- Search
	local sBox = new("TextBox", { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, BackgroundColor3 = Color3.fromRGB(12, 12, 16), PlaceholderText = "Search features...",
		PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TEXT, ClearTextOnFocus = false,
		BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, searchSc)
	corner(sBox, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, sBox)
	local sSt = stroke(sBox, LINE, 1)
	sBox.Focused:Connect(function() tw(sSt, 0.2, { Color = accA }) end)
	sBox.FocusLost:Connect(function() tw(sSt, 0.25, { Color = LINE }) end)
	local sHint = txt(searchSc, { Text = "Type to find any control. GO jumps straight to it.", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1,
		TextSize = 11, TextColor3 = DIM, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	local ON_C, OFF_C = Color3.fromRGB(26, 110, 56), Color3.fromRGB(46, 46, 54)

	local function goTo(card)
		local pg = card:FindFirstAncestorOfClass("CanvasGroup")
		local sc = card:FindFirstAncestorOfClass("ScrollingFrame")
		if not pg or not sc then return end
		switchTo(pg.Name)
		task.delay(0.12, function()
			if not card.Parent then return end
			local y = card.AbsolutePosition.Y - sc.AbsolutePosition.Y + sc.CanvasPosition.Y - 8
			tw(sc, 0.3, { CanvasPosition = Vector2.new(0, math.max(0, y)) })
			local st = card:FindFirstChildOfClass("UIStroke")
			if st then
				tw(st, 0.15, { Color = accA })
				task.delay(0.8, function() tw(st, 0.4, { Color = LINE }) end)
			end
		end)
	end
	local function addRow(order, e)
		local row = new("Frame", { Name = "Result", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order }, searchSc)
		rcorner(row, 8)
		stroke(row, LINE, 1)
		bg(row, 0, "card")
		local pg = e.card:FindFirstAncestorOfClass("CanvasGroup")
		txt(row, { Text = e.name, Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -118, 0, 18), Font = Enum.Font.GothamBold, TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd })
		txt(row, { Text = pg and pg.Name or "", Position = UDim2.fromOffset(10, 21), Size = UDim2.new(1, -118, 0, 14), TextSize = 10, TextColor3 = DIM })
		local go = button(row, { Text = "GO", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(38, 24),
			BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 11 })
		go.MouseButton1Click:Connect(function() goTo(e.card) end)
		local key = e.name:lower()
		if not e.isBtn and TG[key] then
			local t = TG[key]
			local tb = button(row, { Text = t.state and "ON" or "OFF", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0),
				Size = UDim2.fromOffset(38, 24), BackgroundColor3 = t.state and ON_C or OFF_C, TextSize = 11 })
			tb.MouseButton1Click:Connect(function()
				t.Set(not t.state)
				tb.Text = t.state and "ON" or "OFF"
				tw(tb, 0.2, { BackgroundColor3 = t.state and ON_C or OFF_C })
			end)
		elseif not e.isBtn and ACT[key] then
			local rb = button(row, { Text = "RUN", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(38, 24),
				BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 11 })
			rb.MouseButton1Click:Connect(function() ACT[key]() end)
		end
	end
	local function runSearch()
		for _, c in ipairs(searchSc:GetChildren()) do
			if c.Name == "Result" then c:Destroy() end
		end
		local q = sBox.Text:lower():match("^%s*(.-)%s*$")
		local list = {}
		if q ~= "" then
			for _, e in ipairs(CARDS) do
				if e.card.Parent and (e.name:lower():find(q, 1, true) or e.desc:lower():find(q, 1, true)) then table.insert(list, e) end
			end
			for name, pg in pairs(pages) do
				if name ~= "Search" then
					local sc = pg:FindFirstChildOfClass("ScrollingFrame")
					if sc then
						for _, ch in ipairs(sc:GetDescendants()) do
							if ch:IsA("TextButton") and ch.Parent and ch.Parent.Name == "Col" and ch.Text ~= "" and ch.Text:lower():find(q, 1, true) then
								table.insert(list, { name = ch.Text, desc = "", card = ch, isBtn = true })
							end
						end
					end
				end
			end
			table.sort(list, function(a, b) return a.name < b.name end)
			for i, e in ipairs(list) do
				if i <= 40 then addRow(10 + i, e) end
			end
		end
		sHint.Visible = q == "" or #list == 0
		sHint.Text = q == "" and "Type to find any control. GO jumps straight to it." or "No matches"
	end
	sBox:GetPropertyChangedSignal("Text"):Connect(runSearch)

	-- Changelog
	local function chg(order, ver, lines)
		local c = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order }, chgSc)
		rcorner(c, 8)
		stroke(c, LINE, 1)
		bg(c, 0, "card")
		new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, c)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, c)
		local t = txt(c, { Text = ver, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), LayoutOrder = 0 })
		gradient(t)
		txt(c, { Text = table.concat(lines, "\n"), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 11,
			TextColor3 = DIM, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1 })
	end
	chg(-4, "V12 (latest)", {
		"- Visual overhaul: soft window shadow, glossy sheen, animated accent line",
		"- Cards: depth gradient, glowing edge bar and toggle glow when a feature is on",
		"- Headings with accent underline, hover lift on buttons, glowing slider knob",
		"- Animated brand shimmer and a springier window open",
	})
	chg(-3, "V11", {
		"- Tap a player's name instead of typing it (TP, Spectate, Follow)",
		"- Freecam: speed slider plus UP and DOWN buttons",
		"- Features moved to the right tabs: Click TP, Sit and Fling Guard are in Player, Anti-AFK is in Server, Theme, Transparent and Position Lock are in Customize, Toggle Key is in Settings",
	})
	chg(-2, "V10", {
		"- Health bar and HP on ESP labels",
		"- Window buttons move to the left when the sidebar is on the right",
		"- Pop-up notifications when you switch features on or off",
		"- Cards flash when a feature turns on",
		"- Polish fixes for long titles and descriptions",
	})
	chg(-1, "V9", {
		"- New look: two-column pages, sidebar with sliding highlight, profile card",
		"- Dropdown menus for Sky, Camera Lock, Font and FPS position",
		"- Role ESP: Murder Mystery 2 (red murderer, blue sheriff, green innocent)",
		"- Cleaner toggles and sliders",
	})
	chg(0, "V8", {
		"- Cleaner menu design: bigger window, grouped sections, page titles",
		"- Redesigned sidebar with an active marker and quick Favorites / Search / Changelog buttons",
		"- Simpler sliders and quieter cards",
		"- Removed Double Jump",
	})
	chg(1, "V7", {
		"- Platform: walk on thin air",
		"- Sprint Boost (hold Shift or the SPRINT button)",
		"- X-Ray with a see-through slider",
		"- Sky changer and Camera Lock",
		"- Search and Favorites tabs",
		"- Chat commands (;fly, ;ws 50)",
		"- Click sounds",
		"- New dash animation",
		"- This changelog",
	})
	chg(2, "V6", {
		"- Customize tab: Rainbow, Background, GUI scale, Corners, Sidebar side, Font, Text size, Animation speed, Drag weight, Glow border, ESP colors, FPS color and position, Toggle key",
		"- Iron Man hover and Superman flight pose",
		"- Dash, Wall Climb, Follow, Respawn In Place",
		"- Stats Overlay, Hide Players, Noclip Camera, Join/Leave Alerts",
		"- Quick Buttons and Auto Re-Execute",
		"- Click TP, Sit, Freecam, Fling Guard, command box",
	})
	chg(3, "V5 and earlier", {
		"- Main, Player, Visuals, Server and Settings tabs",
		"- Flight, Noclip, Infinite Jump, Jump Power, Walkspeed, No Gravity",
		"- Teleport, Spectate, ESP, FPS counter, FOV, themes, transparency",
		"- Position lock, Save Settings, Reset All",
	})
end

-- Customize page ---------------------------------------------------
do
	local sc = custSc
	local function pct(v) return v .. "%" end
	ctl.noStop = { ["rainbow mode"] = true, ["glow border"] = true, ["sidebar right"] = true, ["position lock"] = true, ["auto re-execute"] = true, ["chat commands"] = true, ["click sounds"] = true, ["notifications"] = true }
	local GRAY, WHITE = Color3.fromRGB(70, 70, 82), Color3.new(1, 1, 1)

	local function swatchRow(c, y, colors, onPick)
		local row, sts = {}, {}
		for i, col in ipairs(colors) do
			local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = col, BorderSizePixel = 0,
				Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(10 + (i - 1) * 34, y) }, c)
			corner(b, 12)
			sts[i] = stroke(b, GRAY, 2, 0)
			b.MouseButton1Click:Connect(function() onPick(i) end)
		end
		function row.Select(i)
			for k, st in pairs(sts) do tw(st, 0.2, { Color = k == i and WHITE or GRAY }) end
		end
		return row
	end
	local function cycleBtn(c, w, text, onClick)
		local b = button(c, { Text = text, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(w, 22),
			BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 11 })
		stroke(b, LINE, 1)
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	-- Rainbow Mode
	local c1 = card(sc, 40, 2)
	cardLabel(c1, "Rainbow Mode")
	makeToggle(c1, function(v) F.rainbow = v end)

	-- Background Color
	local BGS = { Color3.fromRGB(22, 22, 26), Color3.fromRGB(10, 10, 12), Color3.fromRGB(14, 18, 36), Color3.fromRGB(26, 16, 38),
		Color3.fromRGB(14, 28, 22), Color3.fromRGB(36, 16, 20) }
	local c2 = card(sc, 66, 3)
	cardLabel(c2, "Background Color")
	local bgRow = swatchRow(c2, 34, BGS, function(i) ctl.setBg(i) end)
	function ctl.setBg(i)
		S.bg = i
		bgRow.Select(i)
		local col = BGS[i]
		BLACK = col
		PANEL = Color3.new(col.R + 5 / 255, col.G + 5 / 255, col.B + 7 / 255)
		CARD = Color3.new(col.R + 10 / 255, col.G + 10 / 255, col.B + 13 / 255)
		for _, e in ipairs(bgs) do
			local target_ = e.role == "main" and BLACK or e.role == "panel" and PANEL or e.role == "card" and CARD or nil
			if target_ then tw(e.o, 0.3, { BackgroundColor3 = target_ }) end
		end
		updateCats()
	end
	bgRow.Select(S.bg)

	-- GUI Scale
	local c3 = card(sc, 68, 7)
	cardLabel(c3, "GUI Scale")
	makeSlider(c3, sc, { min = 50, max = 150, default = D.guiScale, fmt = pct, onChange = function(v)
		S.guiScale = v
		target = clampPos(target)
		if not ctl.isMin() then tw(scale, 0.15, { Scale = gs() }) end
	end })

	-- Corner Roundness
	function ctl.applyCorner()
		for _, e in ipairs(rounds) do e.c.CornerRadius = UDim.new(0, math.floor(e.r * S.corner / 14 + 0.5)) end
	end
	local c4 = card(sc, 68, 8)
	cardLabel(c4, "Corner Roundness")
	makeSlider(c4, sc, { min = 0, max = 28, default = D.corner, onChange = function(v) S.corner = v ctl.applyCorner() end })

	-- Sidebar position
	local c5 = card(sc, 40, 9)
	cardLabel(c5, "Sidebar Right")
	makeToggle(c5, function(v)
		S.sbRight = v
		tw(sidebar, 0.3, { Position = v and UDim2.new(1, -180, 0, 12) or UDim2.fromOffset(12, 12) })
		tw(content, 0.3, { Position = v and UDim2.fromOffset(12, 52) or UDim2.fromOffset(192, 52) })
		tw(minBtn, 0.3, { Position = v and UDim2.new(0, 80, 0, 12) or UDim2.new(1, -50, 0, 12) })
		tw(closeBtn, 0.3, { Position = v and UDim2.new(0, 44, 0, 12) or UDim2.new(1, -14, 0, 12) })
	end)

	-- Font + Text Size
	local FONTS = {
		{ "Gotham", { Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.GothamBlack } },
		{ "Ubuntu", { Enum.Font.Ubuntu, Enum.Font.Ubuntu, Enum.Font.Ubuntu } },
		{ "Nunito", { Enum.Font.Nunito, Enum.Font.Nunito, Enum.Font.Nunito } },
		{ "Source", { Enum.Font.SourceSans, Enum.Font.SourceSansBold, Enum.Font.SourceSansBold } },
		{ "Code", { Enum.Font.Code, Enum.Font.Code, Enum.Font.Code } },
	}
	function ctl.applyText()
		local fs = FONTS[S.font][2]
		local mult = S.textSize / 100
		for _, o in ipairs(gui:GetDescendants()) do
			if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
				if o:GetAttribute("vxw") == nil then
					local w = 0
					if o.Font == Enum.Font.GothamBold then w = 1 elseif o.Font == Enum.Font.GothamBlack then w = 2 end
					o:SetAttribute("vxw", w)
					o:SetAttribute("vxs", o.TextSize)
				end
				o.Font = fs[o:GetAttribute("vxw") + 1]
				o.TextSize = math.max(8, math.floor(o:GetAttribute("vxs") * mult + 0.5))
			end
		end
	end
	local c6 = card(sc, 40, 10)
	cardLabel(c6, "Font")
	local fontNames = {}
	for i, f in ipairs(FONTS) do fontNames[i] = f[1] end
	local fontBtn = dropBtn(c6, 120, FONTS[S.font][1], fontNames, function(i) ctl.setFont(i) end)
	function ctl.setFont(i)
		S.font = i
		fontBtn.Text = FONTS[i][1]
		ctl.applyText()
	end
	local c7 = card(sc, 68, 11)
	cardLabel(c7, "Text Size")
	makeSlider(c7, sc, { min = 70, max = 140, default = D.textSize, fmt = pct, onChange = function(v) S.textSize = v ctl.applyText() end })

	-- Animation Speed + Drag Weight
	local c8 = card(sc, 68, 101)
	cardLabel(c8, "Animation Speed")
	makeSlider(c8, sc, { min = 50, max = 200, default = D.anim, fmt = pct, onChange = function(v) S.anim = v ANIM = v / 100 end })
	local c9 = card(sc, 68, 102)
	cardLabel(c9, "Drag Weight")
	makeSlider(c9, sc, { min = 0, max = 100, default = D.dragW, onChange = function(v) S.dragW = v dragRate = 35 - 0.3 * v end })

	-- Glow Border
	local c10 = card(sc, 40, 4)
	cardLabel(c10, "Glow Border")
	makeToggle(c10, function(v) F.glow = v end)
	local glowWas = false
	connect(RunService.RenderStepped, function(dt)
		if F.rainbow then
			S.hue = (S.hue + dt * 0.08) % 1
			applyTheme()
		end
		if F.glow then
			glowWas = true
			mainGrad.Rotation = (mainGrad.Rotation + dt * 90) % 360
			mainStroke.Thickness = 2.4 + math.sin(os.clock() * 3) * 0.8
			mainStroke.Transparency = 0.05
		elseif glowWas then
			glowWas = false
			mainStroke.Thickness, mainStroke.Transparency, mainGrad.Rotation = 1.3, 0.35, 30
		end
	end)

	-- ESP colours
	local function hueColor(v) return Color3.fromHSV(v / 360, 0.73, 1) end
	local c11 = card(sc, 68, 111)
	cardLabel(c11, "ESP Team Color")
	makeSlider(c11, sc, { min = 0, max = 360, default = D.espTeam, rainbow = true, colorOf = hueColor,
		onChange = function(v) S.espTeam = v ctl.espTeam = hueColor(v) end })
	local c12 = card(sc, 68, 112)
	cardLabel(c12, "ESP Enemy Color")
	makeSlider(c12, sc, { min = 0, max = 360, default = D.espEnemy, rainbow = true, colorOf = hueColor,
		onChange = function(v) S.espEnemy = v ctl.espEnemy = hueColor(v) end })

	-- FPS counter colour + position
	local FCOL = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 220, 255), Color3.fromRGB(60, 255, 120), Color3.fromRGB(255, 225, 60),
		Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 120, 220) }
	local c13 = card(sc, 66, 113)
	cardLabel(c13, "FPS Color")
	local fRow = swatchRow(c13, 34, FCOL, function(i) ctl.setFpsColor(i) end)
	function ctl.setFpsColor(i)
		S.fpsColor = i
		fRow.Select(i)
		tw(fpsLabel, 0.25, { TextColor3 = FCOL[i] })
		if ctl.statsLabel then tw(ctl.statsLabel, 0.25, { TextColor3 = FCOL[i] }) end
	end
	fRow.Select(S.fpsColor)
	local FPOS = {
		{ "Top Left", Vector2.new(0, 0), UDim2.fromOffset(12, 60), Enum.TextXAlignment.Left },
		{ "Top Right", Vector2.new(1, 0), UDim2.new(1, -12, 0, 60), Enum.TextXAlignment.Right },
		{ "Bottom Left", Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), Enum.TextXAlignment.Left },
		{ "Bottom Right", Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), Enum.TextXAlignment.Right },
	}
	local c14 = card(sc, 40, 114)
	cardLabel(c14, "FPS Position")
	local posBtn = dropBtn(c14, 120, FPOS[S.fpsPos][1], { "Top Left", "Top Right", "Bottom Left", "Bottom Right" }, function(i) ctl.setFpsPos(i) end)
	function ctl.setFpsPos(i)
		S.fpsPos = i
		local e = FPOS[i]
		fpsLabel.AnchorPoint, fpsLabel.Position, fpsLabel.TextXAlignment = e[2], e[3], e[4]
		posBtn.Text = e[1]
	end

	-- Toggle key
	local c15 = card(setSc, 40, 1)
	cardLabel(c15, "Toggle Key")
	local keyBtn
	keyBtn = cycleBtn(c15, 110, S.key, function()
		keyBtn.Text = "Press a key..."
		ctl.rebind = true
	end)
	function ctl.setKey(name)
		S.key = name
		keyBtn.Text = name
	end
	connect(UIS.InputBegan, function(i, gp)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if ctl.rebind then
			ctl.rebind = false
			if i.KeyCode ~= Enum.KeyCode.Escape then ctl.setKey(i.KeyCode.Name) else keyBtn.Text = S.key end
			return
		end
		if gp then return end
		if i.KeyCode.Name == S.key then
			if ctl.isMin() then ctl.restore() else ctl.minimize() end
		end
	end)

	-- Quick Buttons
	local cq = card(sc, 120, 121)
	cardLabel(cq, "Quick Buttons", "Pin features as floating buttons on your screen.")
	ctl.pinCard = cq
	ctl.pinHolder = new("Frame", { Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -20, 1, -58), BackgroundTransparency = 1 }, cq)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(70, 22), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }, ctl.pinHolder)

	function ctl.resetCustom()
		TG["rainbow mode"].Set(false)
		TG["glow border"].Set(false)
		TG["sidebar right"].Set(false)
		ctl.setBg(D.bg)
		ctl.setFont(D.font)
		ctl.setFpsColor(D.fpsColor)
		ctl.setFpsPos(D.fpsPos)
		ctl.setKey(D.key)
		SL["gui scale"].Set(D.guiScale)
		SL["corner roundness"].Set(D.corner)
		SL["text size"].Set(D.textSize)
		SL["animation speed"].Set(D.anim)
		SL["drag weight"].Set(D.dragW)
		SL["esp team color"].Set(D.espTeam)
		SL["esp enemy color"].Set(D.espEnemy)
	end
end

local function hum() return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") end
local function hrp() return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") end

-- Walkspeed / Jump Power / Gravity / FOV
connect(RunService.Heartbeat, function()
	local h = hum()
	if h then
		if F.ws then h.WalkSpeed = S.walk end
		if F.jp then h.UseJumpPower = true; h.JumpPower = S.jump end
	end
	if F.grav then workspace.Gravity = 4 end
end)
table.insert(cleanups, function()
	local h = hum()
	if h and ctl.origWS and F.ws then h.WalkSpeed = ctl.origWS end
	if h and ctl.origJP and F.jp then h.JumpPower = ctl.origJP end
	if F.grav and ctl.origGrav then workspace.Gravity = ctl.origGrav end
end)
connect(RunService.RenderStepped, function()
	if F.fovActive then
		local c = cam()
		c.FieldOfView += (S.fov - c.FieldOfView) * 0.2
		if F.fovReturn and math.abs(S.fov - c.FieldOfView) < 0.05 then
			c.FieldOfView = S.fov
			F.fovActive, F.fovReturn = false, false
		end
	end
end)

-- Infinite jump
connect(UIS.JumpRequest, function()
	if F.inf then
		local h = hum()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- Noclip
local origCollide = {}
connect(RunService.Stepped, function()
	local ch = LP.Character
	if F.noclip and ch then
		for _, p in ipairs(ch:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				origCollide[p] = true
				p.CanCollide = false
			end
		end
	elseif next(origCollide) then
		for p in pairs(origCollide) do if p.Parent then p.CanCollide = true end end
		origCollide = {}
	end
end)
table.insert(cleanups, function()
	for p in pairs(origCollide) do if p.Parent then p.CanCollide = true end end
end)

-- Flight (speed x10 studs/sec; Space/E up, Q/Ctrl down)
local flyBV, flyBG
local fp = { lean = 0, roll = 0, t = 0 }
local function flyStop()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local h = hum()
	if h then h.PlatformStand = false end
end
connect(RunService.RenderStepped, function(dt)
	local r, h = hrp(), hum()
	if not (F.fly and r and h) then
		if flyBV then flyStop() end
		return
	end
	if not (flyBV and flyBV.Parent) then
		flyStop()
		flyBV = new("BodyVelocity", { MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, r)
		flyBG = new("BodyGyro", { MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, CFrame = r.CFrame }, r)
		h.PlatformStand = true
	end
	local c = cam()
	local md = h.MoveDirection
	local dir = Vector3.zero
	if md.Magnitude > 0.01 then
		local l = c.CFrame:VectorToObjectSpace(md.Unit)
		dir = c.CFrame.LookVector * -l.Z + c.CFrame.RightVector * l.X
	end
	local up = 0
	if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) then up += 1 end
	if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then up -= 1 end
	dir += Vector3.new(0, up, 0)
	local v = dir.Magnitude > 0 and dir.Unit * S.flight * 10 or Vector3.zero
	flyBV.Velocity = flyBV.Velocity:Lerp(v, 1 - math.exp(-dt * 10))
	local look = c.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		local fu = flat.Unit
		local vel = flyBV.Velocity
		local maxv = math.max(S.flight * 10, 1)
		local fwdC = math.clamp(vel:Dot(fu) / maxv, -1, 1)
		local rightC = math.clamp(vel:Dot(Vector3.new(-fu.Z, 0, fu.X)) / maxv, -1, 1)
		local leanT = fwdC >= 0 and math.rad(78) * fwdC or math.rad(28) * fwdC
		local k = 1 - math.exp(-dt * 6)
		fp.lean += (leanT - fp.lean) * k
		fp.roll += (math.rad(25) * rightC - fp.roll) * k
		flyBG.CFrame = CFrame.lookAt(r.Position, r.Position + flat) * CFrame.Angles(-fp.lean, 0, -fp.roll)
	end
end)
table.insert(cleanups, flyStop)

-- Iron Man hover -> Superman flying pose (R15 tuned; R6 best effort)
local poseJ, poseChar, posed, poseAn = nil, nil, false, nil
local function poseSetup(ch)
	local h = ch:FindFirstChildOfClass("Humanoid")
	local r15 = h ~= nil and h.RigType == Enum.HumanoidRigType.R15
	local function J(n)
		if not n then return nil end
		local m = ch:FindFirstChild(n, true)
		return (m and m:IsA("Motor6D")) and m or nil
	end
	poseJ = {
		r15 = r15,
		rs = J(r15 and "RightShoulder" or "Right Shoulder"), ls = J(r15 and "LeftShoulder" or "Left Shoulder"),
		re = J(r15 and "RightElbow" or nil), le = J(r15 and "LeftElbow" or nil),
		rh = J(r15 and "RightHip" or "Right Hip"), lh = J(r15 and "LeftHip" or "Left Hip"),
		rk = J(r15 and "RightKnee" or nil), lk = J(r15 and "LeftKnee" or nil),
		nk = J("Neck"),
	}
	poseAn = ch:FindFirstChild("Animate")
	if poseAn then
		pcall(function() poseAn.Enabled = false end)
		pcall(function() poseAn.Disabled = true end)
	end
	local an = h and h:FindFirstChildOfClass("Animator")
	if an then for _, t in ipairs(an:GetPlayingAnimationTracks()) do t:Stop(0.1) end end
end
local function poseReset()
	if poseJ then
		for _, m in pairs(poseJ) do
			if typeof(m) == "Instance" and m.Parent then m.Transform = CFrame.new() end
		end
	end
	if poseAn and poseAn.Parent then
		pcall(function() poseAn.Enabled = true end)
		pcall(function() poseAn.Disabled = false end)
	end
	poseJ, poseChar, poseAn, posed = nil, nil, nil, false
	fp.lean, fp.roll = 0, 0
end
connect(RunService.RenderStepped, function(dt)
	local on = F.fly and flyBV ~= nil and flyBV.Parent ~= nil
	if not on then
		if posed then poseReset() end
		return
	end
	local ch = LP.Character
	if not ch then return end
	if poseChar ~= ch then
		poseSetup(ch)
		poseChar = ch
	end
	posed = true
	fp.t += dt
	local j = poseJ
	local rad, A = math.rad, CFrame.Angles
	local sf = math.clamp(fp.lean / rad(78), 0, 1) -- 0 = hover, 1 = full Superman
	local bob = math.sin(fp.t * 2.2)
	local armFwd = rad(-10) + (rad(165) - rad(-10)) * sf + bob * rad(3) * (1 - sf)
	local abd = rad(34) * (1 - sf) + rad(6) * sf + bob * rad(2) * (1 - sf)
	local elbow = rad(22) * (1 - sf)
	local spread = rad(9) * (1 - sf) + rad(2) * sf
	local back = rad(12) * (1 - sf) + rad(2) * sf + math.sin(fp.t * 2.2 + 1) * rad(2) * (1 - sf)
	local knee = rad(20) * (1 - sf) + rad(4) * sf
	local neck = fp.lean * 0.75
	if j.r15 then
		if j.rs then j.rs.Transform = A(armFwd, 0, abd) end
		if j.ls then j.ls.Transform = A(armFwd, 0, -abd) end
		if j.re then j.re.Transform = A(elbow, 0, 0) end
		if j.le then j.le.Transform = A(elbow, 0, 0) end
		if j.rh then j.rh.Transform = A(-back, 0, spread) end
		if j.lh then j.lh.Transform = A(-back, 0, -spread) end
		if j.rk then j.rk.Transform = A(-knee, 0, 0) end
		if j.lk then j.lk.Transform = A(-knee, 0, 0) end
		if j.nk then j.nk.Transform = A(neck, 0, 0) end
	else
		if j.rs then j.rs.Transform = A(-abd, 0, 0) * A(0, 0, armFwd) end
		if j.ls then j.ls.Transform = A(-abd, 0, 0) * A(0, 0, -armFwd) end
		if j.rh then j.rh.Transform = A(-spread, 0, 0) * A(0, 0, -back) end
		if j.lh then j.lh.Transform = A(-spread, 0, 0) * A(0, 0, back) end
		if j.nk then j.nk.Transform = A(-neck, 0, 0) end
	end
end)
table.insert(cleanups, function() if posed then poseReset() end end)

-- FPS counter
do
	local frames, t0 = 0, os.clock()
	connect(RunService.RenderStepped, function()
		frames += 1
		local now = os.clock()
		if now - t0 >= 0.5 then
			if F.fps then fpsLabel.Text = "FPS: " .. math.floor(frames / (now - t0) + 0.5) end
			frames, t0 = 0, now
		end
	end)
end

-- ESP
local espFolder = new("Folder", { Name = "VisionXESP" }, GuiRoot)
local espData = {}
local BLUE, RED = Color3.fromRGB(70, 150, 255), Color3.fromRGB(255, 70, 70)
local function espClear(p)
	local e = espData[p]
	if e then
		e.hl:Destroy()
		e.bb:Destroy()
		espData[p] = nil
	end
end
local function espClearAll() for p in pairs(espData) do espClear(p) end end
local function mm2Role(p)
	local ch, bp = p.Character, p:FindFirstChildOfClass("Backpack")
	local function has(n) return (ch and ch:FindFirstChild(n)) or (bp and bp:FindFirstChild(n)) end
	if has("Knife") then return "Murderer", Color3.fromRGB(255, 70, 70) end
	if has("Gun") then return "Sheriff", Color3.fromRGB(70, 150, 255) end
	return "Innocent", Color3.fromRGB(70, 230, 110)
end
local function espBuild(p, ch)
	local head = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local hl = new("Highlight", { Adornee = ch, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, FillTransparency = 0.75, OutlineTransparency = 0 }, espFolder)
	local bb = new("BillboardGui", { Adornee = head, AlwaysOnTop = true, Size = UDim2.fromOffset(230, 46), StudsOffset = Vector3.new(0, 2.6, 0),
		LightInfluence = 0, ResetOnSpawn = false, MaxDistance = math.huge }, espFolder)
	local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0 }, bb)
	corner(pill, 8)
	local pst = stroke(pill, Color3.new(1, 1, 1), 1, 0.2)
	local top = txt(pill, { Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 17), Font = Enum.Font.GothamBold, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, TextTruncate = Enum.TextTruncate.AtEnd })
	local bot = txt(pill, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3 })
	local hpBack = new("Frame", { Position = UDim2.new(0, 10, 1, -9), Size = UDim2.new(1, -20, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3, BorderSizePixel = 0 }, pill)
	corner(hpBack, 2)
	local hpFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 230, 110), BorderSizePixel = 0 }, hpBack)
	corner(hpFill, 2)
	espData[p] = { hl = hl, bb = bb, pill = pill, pst = pst, top = top, bot = bot, hpFill = hpFill, char = ch, head = head }
end
connect(Players.PlayerRemoving, espClear)
connect(RunService.Heartbeat, function()
	if not F.esp then
		if next(espData) then espClearAll() end
		return
	end
	local c = cam()
	local items = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local ch = p.Character
			local e = espData[p]
			if e and e.char ~= ch then espClear(p) e = nil end
			if ch and not e then espBuild(p, ch) e = espData[p] end
			if e and e.head.Parent then
				local col, roleTxt
				if F.roles then
					roleTxt, col = mm2Role(p)
				else
					col = (LP.Team ~= nil and p.Team == LP.Team) and ctl.espTeam or ctl.espEnemy
				end
				e.hl.FillColor, e.hl.OutlineColor = col, col
				e.pst.Color = col
				e.top.TextColor3 = col
				local nm = p.DisplayName == p.Name and p.Name or (p.DisplayName .. " (@" .. p.Name .. ")")
				e.top.Text = roleTxt and (nm .. "  [" .. roleTxt .. "]") or nm
				local origin = hrp() and hrp().Position or c.CFrame.Position
				local dist = (e.head.Position - origin).Magnitude
				local eh = e.char:FindFirstChildOfClass("Humanoid")
				local hpf = (eh and eh.MaxHealth > 0) and math.clamp(eh.Health / eh.MaxHealth, 0, 1) or 1
				tw(e.hpFill, 0.2, { Size = UDim2.new(hpf, 0, 1, 0), BackgroundColor3 = Color3.fromHSV(hpf * 0.33, 0.8, 1) })
				e.bot.Text = math.floor(dist + 0.5) .. " studs  \194\183  " .. (eh and math.floor(eh.Health + 0.5) or 0) .. " HP"
				local sp, on = c:WorldToViewportPoint(e.head.Position)
				if on then table.insert(items, { e = e, d = dist, x = sp.X, y = sp.Y }) end
			end
		end
	end
	table.sort(items, function(a, b) return a.d < b.d end)
	local placed = {}
	for _, it in ipairs(items) do
		local shift, moved, guard = 0, true, 0
		while moved and guard < 8 do
			moved, guard = false, guard + 1
			for _, pl in ipairs(placed) do
				if math.abs(pl.x - it.x) < 140 and math.abs((pl.y - pl.s) - (it.y - shift)) < 48 then
					shift += 48
					moved = true
					break
				end
			end
		end
		table.insert(placed, { x = it.x, y = it.y, s = shift })
		it.e.pill.Position = UDim2.new(0.5, 0, 1, -shift)
	end
end)
table.insert(cleanups, function() espClearAll() espFolder:Destroy() end)

---------------------------------------------------------------------
-- Player / Server / extra features
---------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local BAD = Color3.fromRGB(255, 120, 120)

-- Spectate
ctl.specTarget = nil
function ctl.specStop()
	ctl.specTarget = nil
	local h = hum()
	if h and cam() then cam().CameraSubject = h end
	if ctl.specUI then ctl.specUI(false) end
end
function ctl.specStart(p)
	ctl.specTarget = p
	if ctl.specUI then ctl.specUI(true, p) end
end
connect(RunService.RenderStepped, function()
	local p = ctl.specTarget
	if not p then return end
	if p.Parent ~= Players then return ctl.specStop() end
	local ph = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if ph and cam().CameraSubject ~= ph then cam().CameraSubject = ph end
end)
table.insert(cleanups, function() ctl.specTarget = nil local h = hum() if h then cam().CameraSubject = h end end)

-- Force reset
function ctl.forceReset()
	local h = hum()
	if h then h.Health = 0 end
	local ch = LP.Character
	if ch then pcall(function() ch:BreakJoints() end) end
end

-- Anti-AFK (idle hook + tiny nudge every 5 minutes)
ctl.afkT, ctl.afkDir = 0, 1
do
	local ok, VU = pcall(function() return game:GetService("VirtualUser") end)
	connect(LP.Idled, function()
		if F.afk and ok and VU then pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end) end
	end)
end
connect(RunService.Heartbeat, function(dt)
	if not F.afk then ctl.afkT = 0 return end
	ctl.afkT += dt
	if ctl.afkT >= 300 then
		ctl.afkT = 0
		local h = hum()
		if h then
			local dir = Vector3.new(ctl.afkDir, 0, 0)
			ctl.afkDir = -ctl.afkDir
			local t0 = os.clock()
			pcall(function() RunService:UnbindFromRenderStep("VisionXAfk") end)
			RunService:BindToRenderStep("VisionXAfk", Enum.RenderPriority.Character.Value + 1, function()
				if os.clock() - t0 > 0.25 or not h.Parent then RunService:UnbindFromRenderStep("VisionXAfk") return end
				h:Move(dir, false)
			end)
		end
	end
end)
table.insert(cleanups, function() pcall(function() RunService:UnbindFromRenderStep("VisionXAfk") end) end)

-- Spin
local spinAR
connect(RunService.RenderStepped, function(dt)
	local r, h = hrp(), hum()
	if F.spin and r and h then
		if spinAR == nil then spinAR = h.AutoRotate end
		h.AutoRotate = false
		r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(S.spin * 18) * dt, 0)
	elseif spinAR ~= nil then
		if h then h.AutoRotate = spinAR end
		spinAR = nil
	end
end)
table.insert(cleanups, function() local h = hum() if h and spinAR ~= nil then h.AutoRotate = spinAR end end)

-- Fullbright
local fbOrig
function ctl.fullbright(on)
	F.fb = on
	if on then
		fbOrig = fbOrig or { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd,
			GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	elseif fbOrig then
		for k, v in pairs(fbOrig) do Lighting[k] = v end
		fbOrig = nil
	end
end
connect(RunService.Heartbeat, function()
	if F.fb then
		Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd, Lighting.GlobalShadows = 2, 14, 1e6, false
		Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178), Color3.fromRGB(178, 178, 178)
	end
end)
table.insert(cleanups, function() ctl.fullbright(false) end)

-- FPS Boost
local fpsbSaved, fpsbQ = {}, nil
local function fpsbSet(inst, prop, val)
	local ok, old = pcall(function() return inst[prop] end)
	if ok then
		table.insert(fpsbSaved, { inst, prop, old })
		pcall(function() inst[prop] = val end)
	end
end
function ctl.fpsBoost(on)
	F.fpsb = on
	if on then
		fpsbSaved = {}
		pcall(function()
			fpsbQ = settings().Rendering.QualityLevel
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
		fpsbSet(Lighting, "GlobalShadows", false)
		for _, root in ipairs({ Lighting, cam() }) do
			for _, o in ipairs(root:GetChildren()) do
				if o:IsA("PostEffect") then fpsbSet(o, "Enabled", false) end
			end
		end
		pcall(function()
			for _, o in ipairs(workspace:GetDescendants()) do
				if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
					fpsbSet(o, "Enabled", false)
				end
			end
		end)
		local t = workspace:FindFirstChildOfClass("Terrain")
		if t then
			fpsbSet(t, "WaterWaveSize", 0)
			fpsbSet(t, "WaterWaveSpeed", 0)
			fpsbSet(t, "WaterReflectance", 0)
		end
	else
		for _, e in ipairs(fpsbSaved) do
			pcall(function() if e[1].Parent then e[1][e[2]] = e[3] end end)
		end
		fpsbSaved = {}
		pcall(function() if fpsbQ then settings().Rendering.QualityLevel = fpsbQ end end)
	end
end
table.insert(cleanups, function() if F.fpsb then ctl.fpsBoost(false) end end)

-- Rejoin / Server Hop
function ctl.rejoin()
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			LP:Kick("\nRejoining...")
			task.wait()
			TeleportService:Teleport(game.PlaceId, LP)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
		end
	end)
end
function ctl.hop(setStatus)
	task.spawn(function()
		setStatus("Searching servers...", DIM)
		local ok, res = pcall(function()
			return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId ..
				"/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"))
		end)
		if not ok or type(res) ~= "table" or not res.data then return setStatus("Couldn't fetch servers", BAD) end
		local list = {}
		for _, sv in ipairs(res.data) do
			if sv.id ~= game.JobId and sv.playing and sv.maxPlayers and sv.playing < sv.maxPlayers then table.insert(list, sv) end
		end
		if #list == 0 then return setStatus("No other servers found", BAD) end
		setStatus("Hopping...", GREEN)
		pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, list[math.random(1, #list)].id, LP) end)
	end)
end

-- New features: Dash, Double Jump, Wall Climb, Follow, Respawn In Place, Stats, Alerts, Hide Players, Noclip Camera, Quick Buttons, Auto Re-Execute
do
	local M1, TCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
	local WHITE = Color3.new(1, 1, 1)

	-- Dash
	ctl.dashT, ctl.dashUntil = 0, 0
	function ctl.dash()
		local r, h = hrp(), hum()
		if not r then return end
		if os.clock() - ctl.dashT < S.dashCd / 10 then return end
		ctl.dashT = os.clock()
		local dir = h and h.MoveDirection or Vector3.zero
		if dir.Magnitude < 0.1 then
			local lv = r.CFrame.LookVector
			dir = Vector3.new(lv.X, 0, lv.Z)
			if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
		end
		dir = dir.Unit
		ctl.dashUntil = os.clock() + 0.3
		local bv = new("BodyVelocity", { MaxForce = Vector3.new(1e5, 0, 1e5), Velocity = dir * S.dashPow }, r)
		task.delay(0.18, function() if bv.Parent then bv:Destroy() end end)
		ctl.dashFx(dir)
	end

	-- Wall Climb
	connect(RunService.Heartbeat, function()
		if not F.wc then return end
		local r, h = hrp(), hum()
		if not (r and h) then return end
		local md = h.MoveDirection
		if md.Magnitude < 0.1 then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { LP.Character }
		local res = workspace:Raycast(r.Position, md.Unit * 3, params)
		if res and res.Instance.CanCollide and math.abs(res.Normal.Y) < 0.5 then
			r.AssemblyLinearVelocity = Vector3.new(-res.Normal.X * 4, S.wcSpeed, -res.Normal.Z * 4)
		end
	end)

	-- Follow
	ctl.followTarget = nil
	function ctl.followStop()
		ctl.followTarget = nil
		pcall(function() RunService:UnbindFromRenderStep("VisionXFollow") end)
		if ctl.followUI then ctl.followUI(false) end
	end
	function ctl.followStart(p)
		ctl.followStop()
		ctl.followTarget = p
		RunService:BindToRenderStep("VisionXFollow", Enum.RenderPriority.Character.Value + 1, function()
			local t = ctl.followTarget
			if not t or t.Parent ~= Players then return ctl.followStop() end
			local r, h = hrp(), hum()
			local tr = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
			if not (r and h and tr) then return end
			local d = tr.Position - r.Position
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > S.followDist then
				h:Move(flat.Unit, false)
				if d.Y > 3 and flat.Magnitude < S.followDist + 12 then h.Jump = true end
			end
		end)
		if ctl.followUI then ctl.followUI(true, p) end
	end
	table.insert(cleanups, function() ctl.followStop() end)

	-- Respawn In Place
	function ctl.respawnHere()
		local r = hrp()
		if not r then return end
		local cf = r.CFrame
		ctl.forceReset()
		task.spawn(function()
			local ch = LP.CharacterAdded:Wait()
			local hr = ch:WaitForChild("HumanoidRootPart", 5)
			if not hr then return end
			local t0 = os.clock()
			while os.clock() - t0 < 0.6 and hr.Parent do
				hr.CFrame = cf
				RunService.Heartbeat:Wait()
			end
		end)
	end

	-- Stats Overlay
	local statsLbl = txt(gui, { Name = "Stats", Position = UDim2.fromOffset(12, 82), Size = UDim2.fromOffset(190, 48), TextSize = 11,
		TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.4, Visible = false, Text = "" })
	ctl.statsLabel = statsLbl
	local acc = 0
	connect(RunService.Heartbeat, function(dt)
		acc += dt
		if acc < 0.25 then return end
		acc = 0
		if not F.stats then return end
		local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
		local r = hrp()
		local p = r and r.Position or Vector3.zero
		local v = r and r.AssemblyLinearVelocity or Vector3.zero
		statsLbl.Text = string.format("Ping: %s ms\nPos: %d, %d, %d\nSpeed: %d", ok and tostring(math.floor(ping + 0.5)) or "?",
			math.floor(p.X), math.floor(p.Y), math.floor(p.Z), math.floor(Vector3.new(v.X, 0, v.Z).Magnitude + 0.5))
	end)

	-- Join/Leave alerts (toasts)
	local toastHold = new("Frame", { Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(240, 200), BackgroundTransparency = 1 }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toastHold)
	function ctl.toast(text, col)
		local shown = {}
		for _, k in ipairs(toastHold:GetChildren()) do
			if k:IsA("CanvasGroup") then table.insert(shown, k) end
		end
		if #shown >= 4 then shown[1]:Destroy() end
		local g = new("CanvasGroup", { Size = UDim2.fromOffset(210, 26), BackgroundColor3 = BLACK, BorderSizePixel = 0, GroupTransparency = 1 }, toastHold)
		corner(g, 8)
		gradient(stroke(g, WHITE, 1.2, 0.3))
		txt(g, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, RichText = true, TextSize = 12,
			Text = string.format('<font color="#%s">\226\151\143</font> %s', col:ToHex(), (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))), TextTruncate = Enum.TextTruncate.AtEnd })
		tw(g, 0.25, { GroupTransparency = 0 })
		task.delay(3, function()
			tw(g, 0.3, { GroupTransparency = 1 })
			task.delay(0.35, function() g:Destroy() end)
		end)
	end
	connect(Players.PlayerAdded, function(p) if F.alerts then ctl.toast(p.DisplayName .. " joined", GREEN) end end)
	connect(Players.PlayerRemoving, function(p) if F.alerts then ctl.toast(p.DisplayName .. " left", Color3.fromRGB(255, 100, 100)) end end)
	notifyFn = function(name, on)
		if S.notify then ctl.toast(name .. (on and "  ON" or "  OFF"), on and GREEN or Color3.fromRGB(170, 170, 185)) end
	end

	-- Hide Players (client-side only)
	local hideDecal, hideActive, hideT = {}, false, 0
	local function hideSet(on)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and p.Character then
				for _, o in ipairs(p.Character:GetDescendants()) do
					if o:IsA("BasePart") then
						o.LocalTransparencyModifier = on and 1 or 0
					elseif o:IsA("Decal") then
						if on then
							if hideDecal[o] == nil then hideDecal[o] = o.Transparency end
							o.Transparency = 1
						elseif hideDecal[o] ~= nil then
							o.Transparency = hideDecal[o]
							hideDecal[o] = nil
						end
					end
				end
			end
		end
		if not on then
			for o, v in pairs(hideDecal) do if o.Parent then o.Transparency = v end end
			hideDecal = {}
		end
	end
	connect(RunService.Heartbeat, function(dt)
		if F.hide then
			hideT += dt
			if hideT > 0.4 then
				hideT = 0
				hideActive = true
				hideSet(true)
			end
		elseif hideActive then
			hideActive = false
			hideSet(false)
		end
	end)
	table.insert(cleanups, function() if hideActive then hideSet(false) end end)

	-- Noclip Camera (camera passes through walls, walls fade out)
	pcall(function() ctl.camOrig = LP.DevCameraOcclusionMode end)
	function ctl.camNoclip(on)
		pcall(function()
			LP.DevCameraOcclusionMode = on and Enum.DevCameraOcclusionMode.Invisicam or (ctl.camOrig or Enum.DevCameraOcclusionMode.Zoom)
		end)
	end
	table.insert(cleanups, function() ctl.camNoclip(false) end)

	-- Auto Re-Execute
	function ctl.queueReload()
		local url = (S.url or ""):gsub('"', "")
		if url == "" then return false end
		local q = queue_on_teleport or (syn and syn.queue_on_teleport) or queueonteleport
		if not q then return false end
		return (pcall(q, 'loadstring(game:HttpGet("' .. url .. '"))()'))
	end

	-- Quick Buttons (floating, draggable)
	local qHold = new("Folder", { Name = "Quick" }, gui)
	ctl.pins = {}
	local qDrag, pinState = nil, {}
	local function qTitle(n) return (n:gsub("(%a)([%w'/%-]*)", function(a, b) return a:upper() .. b end)) end
	function ctl.pin(name, on)
		if on and not ctl.pins[name] then
			local count = 0
			for _ in pairs(ctl.pins) do count += 1 end
			local b = button(qHold, { Text = qTitle(name), Size = UDim2.fromOffset(92, 28), Position = UDim2.fromOffset(10, 130 + count * 34),
				BackgroundColor3 = BLACK, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd })
			gradient(stroke(b, WHITE, 1.2, 0.2))
			b.InputBegan:Connect(function(i)
				if i.UserInputType == M1 or i.UserInputType == TCH then
					qDrag = { b = b, input = i, start = Vector2.new(i.Position.X, i.Position.Y), origin = b.Position, moved = false, name = name }
				end
			end)
			ctl.pins[name] = b
		elseif not on and ctl.pins[name] then
			ctl.pins[name]:Destroy()
			ctl.pins[name], pinState[name] = nil, nil
		end
		if ctl.chips and ctl.chips[name] then tw(ctl.chips[name], 0.2, { Color = ctl.pins[name] and WHITE or LINE }) end
		local list = {}
		for n in pairs(ctl.pins) do table.insert(list, n) end
		table.sort(list)
		S.pins = list
	end
	connect(UIS.InputChanged, function(i)
		if qDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i == qDrag.input) then
			local d = Vector2.new(i.Position.X, i.Position.Y) - qDrag.start
			if d.Magnitude > 8 then qDrag.moved = true end
			if qDrag.moved then
				local vs = cam().ViewportSize
				qDrag.b.Position = UDim2.fromOffset(math.clamp(qDrag.origin.X.Offset + d.X, 0, vs.X - 92), math.clamp(qDrag.origin.Y.Offset + d.Y, 0, vs.Y - 30))
			end
		end
	end)
	connect(UIS.InputEnded, function(i)
		if qDrag and (i == qDrag.input or i.UserInputType == M1) then
			local d = qDrag
			qDrag = nil
			if not d.moved then
				local t = TG[d.name]
				if t then t.Set(not t.state) elseif ACT[d.name] then ACT[d.name]() end
			end
		end
	end)
	local qAcc = 0
	connect(RunService.Heartbeat, function(dt)
		qAcc += dt
		if qAcc < 0.15 then return end
		qAcc = 0
		for n, b in pairs(ctl.pins) do
			local t = TG[n]
			local on = t ~= nil and t.state
			if pinState[n] ~= on then
				pinState[n] = on
				tw(b, 0.2, { BackgroundColor3 = on and Color3.fromRGB(26, 110, 56) or BLACK })
			end
		end
	end)
	function ctl.buildPins()
		local skip = { ["rainbow mode"] = true, ["glow border"] = true, ["sidebar right"] = true, ["position lock"] = true, ["auto re-execute"] = true }
		local names = {}
		for k in pairs(TG) do if not skip[k] then table.insert(names, k) end end
		for k in pairs(ACT) do table.insert(names, k) end
		table.sort(names)
		ctl.chips = {}
		for i, n in ipairs(names) do
			local b = button(ctl.pinHolder, { Text = qTitle(n), BackgroundColor3 = Color3.fromRGB(30, 30, 38), TextSize = 10, LayoutOrder = i,
				TextTruncate = Enum.TextTruncate.AtEnd })
			ctl.chips[n] = stroke(b, LINE, 1)
			b.MouseButton1Click:Connect(function() ctl.pin(n, not ctl.pins[n]) end)
		end
		ctl.pinCard.Size = UDim2.new(1, 0, 0, 58 + math.ceil(#names / 3) * 26)
	end
	table.insert(cleanups, function() qHold:Destroy() end)
end

-- v7 features: Platform, Sprint Boost, X-Ray, Sky, Camera Lock, Chat Commands, Dash animation
do
	local M1, TCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch

	-- Platform (invisible floor that follows you)
	local platPart, platY
	function ctl.platOff()
		if platPart then platPart:Destroy() platPart = nil end
		platY = nil
	end
	connect(RunService.Heartbeat, function(dt)
		if not F.plat then return end
		local r, h = hrp(), hum()
		if not (r and h) then return end
		local off = h.RigType == Enum.HumanoidRigType.R6 and 3 or (h.HipHeight + r.Size.Y / 2)
		local feet = r.Position.Y - off
		if not platPart or not platPart.Parent then
			platPart = new("Part", { Name = "VXPlat", Size = Vector3.new(14, 1, 14), Anchored = true, CanCollide = true, Transparency = 1 }, cam())
			platY = feet
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { LP.Character, platPart }
		local res = workspace:Raycast(r.Position, Vector3.new(0, -(off + 3), 0), params)
		if res and res.Position.Y > platY + 0.25 then platY = res.Position.Y end
		if feet > platY + 1.2 and r.AssemblyLinearVelocity.Y <= 1 then platY = feet - 0.05 end -- jump apex: the floor catches you
		if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then platY -= 25 * dt end
		platPart.CFrame = CFrame.new(r.Position.X, platY - 0.5, r.Position.Z)
	end)
	table.insert(cleanups, function() ctl.platOff() end)

	-- Sprint Boost
	local btnHeld, shiftHeld, sprintOn, sprintBase = false, false, false, 16
	local spBtn = button(gui, { Text = "SPRINT", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.55, 0), Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, TextSize = 11, Visible = false })
	spBtn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 33)
	gradient(stroke(spBtn, Color3.new(1, 1, 1), 1.5, 0.1))
	ctl.sprintBtn = spBtn
	local spIn
	spBtn.InputBegan:Connect(function(i)
		if i.UserInputType == M1 or i.UserInputType == TCH then
			spIn, btnHeld = i, true
			tw(spBtn, 0.1, { BackgroundColor3 = Color3.fromRGB(26, 110, 56) })
		end
	end)
	connect(UIS.InputEnded, function(i)
		if spIn and (i == spIn or i.UserInputType == M1) then
			spIn, btnHeld = nil, false
			tw(spBtn, 0.2, { BackgroundColor3 = BLACK })
		end
		if i.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = false end
	end)
	connect(UIS.InputBegan, function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = true end
	end)
	connect(RunService.Heartbeat, function()
		local h = hum()
		if not h then return end
		if F.sprint and (btnHeld or shiftHeld) then
			if not sprintOn then
				sprintOn = true
				sprintBase = h.WalkSpeed
			end
			h.WalkSpeed = (F.ws and S.walk or sprintBase) * S.sprintMul / 10
		elseif sprintOn then
			sprintOn = false
			h.WalkSpeed = F.ws and S.walk or sprintBase
		end
	end)
	table.insert(cleanups, function()
		local h = hum()
		if h and sprintOn then h.WalkSpeed = F.ws and S.walk or sprintBase end
	end)

	-- X-Ray (client-side see-through world)
	local xr, xrConn = {}, nil
	local function xrAdd(p)
		if xr[p] ~= nil or not p:IsA("BasePart") or p.Transparency >= 0.95 then return end
		local m = p:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then return end
		xr[p] = true
		p.LocalTransparencyModifier = S.xrayT / 100
	end
	function ctl.xrayUpdate()
		for p in pairs(xr) do
			if p.Parent then p.LocalTransparencyModifier = S.xrayT / 100 end
		end
	end
	function ctl.xray(on)
		F.xray = on
		if xrConn then xrConn:Disconnect() xrConn = nil end
		if on then
			xrConn = workspace.DescendantAdded:Connect(function(d) if F.xray then xrAdd(d) end end)
			task.spawn(function()
				local n = 0
				for _, d in ipairs(workspace:GetDescendants()) do
					if not F.xray then return end
					xrAdd(d)
					n += 1
					if n % 500 == 0 then task.wait() end
				end
			end)
		else
			for p in pairs(xr) do
				if p.Parent then p.LocalTransparencyModifier = 0 end
			end
			xr = {}
		end
	end
	table.insert(cleanups, function() if F.xray then ctl.xray(false) end end)

	-- Sky changer
	local C = Color3.fromRGB
	ctl.SKY = {
		{ "Default" },
		{ "Sunset", clock = 18.2, amb = C(120, 80, 70), out = C(150, 100, 80), top = C(255, 150, 90), bot = C(255, 90, 60),
			atm = { c = C(255, 170, 110), d = C(255, 110, 70), den = 0.38, haze = 1.6, glare = 0.3 }, stars = 0 },
		{ "Night", clock = 0, amb = C(35, 38, 70), out = C(30, 34, 64), top = C(60, 80, 160), bot = C(20, 24, 50),
			atm = { c = C(60, 70, 120), d = C(40, 50, 100), den = 0.3, haze = 0.6, glare = 0 }, stars = 5000 },
		{ "Galaxy", clock = 0, amb = C(70, 40, 120), out = C(60, 30, 110), top = C(140, 80, 255), bot = C(60, 20, 120),
			atm = { c = C(130, 80, 220), d = C(90, 40, 170), den = 0.35, haze = 1, glare = 0 }, stars = 9000 },
		{ "Overcast", clock = 13, amb = C(110, 115, 125), out = C(120, 125, 135), top = C(170, 175, 185), bot = C(150, 155, 165),
			atm = { c = C(170, 175, 185), d = C(150, 155, 165), den = 0.45, haze = 2.4, glare = 0 }, stars = 0 },
		{ "Pink Dream", clock = 17.5, amb = C(140, 90, 120), out = C(160, 100, 140), top = C(255, 130, 200), bot = C(255, 170, 220),
			atm = { c = C(255, 170, 220), d = C(255, 120, 180), den = 0.35, haze = 1.2, glare = 0.2 }, stars = 0 },
		{ "Bright Day", clock = 13, amb = C(130, 130, 130), out = C(140, 140, 140), top = C(255, 255, 255), bot = C(255, 255, 255),
			atm = { c = C(199, 214, 235), d = C(106, 112, 125), den = 0.2, haze = 0, glare = 0 }, stars = 0 },
	}
	local skyOrig, atmOrig, starsOrig, madeAtm, madeSky
	function ctl.setSky(i)
		S.sky = i
		local p = ctl.SKY[i]
		if ctl.skyBtn then ctl.skyBtn.Text = p[1] end
		if not skyOrig then
			skyOrig = { ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
				ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom }
			local a0 = Lighting:FindFirstChildOfClass("Atmosphere")
			if a0 then atmOrig = { Color = a0.Color, Decay = a0.Decay, Density = a0.Density, Haze = a0.Haze, Glare = a0.Glare } end
			local s0 = Lighting:FindFirstChildOfClass("Sky")
			if s0 then starsOrig = s0.StarCount end
		end
		if i == 1 then
			tw(Lighting, 0.8, skyOrig)
			local a = Lighting:FindFirstChildOfClass("Atmosphere")
			if a then
				if madeAtm and a == madeAtm then madeAtm = nil a:Destroy() elseif atmOrig then tw(a, 0.8, atmOrig) end
			end
			local sk = Lighting:FindFirstChildOfClass("Sky")
			if sk then
				if madeSky and sk == madeSky then madeSky = nil sk:Destroy() elseif starsOrig then sk.StarCount = starsOrig end
			end
			skyOrig, atmOrig, starsOrig = nil, nil, nil
			return
		end
		tw(Lighting, 0.8, { ClockTime = p.clock, Ambient = p.amb, OutdoorAmbient = p.out, ColorShift_Top = p.top, ColorShift_Bottom = p.bot })
		local a = Lighting:FindFirstChildOfClass("Atmosphere")
		if not a then
			a = new("Atmosphere", { Density = 0, Haze = 0, Glare = 0 }, Lighting)
			madeAtm = a
		end
		tw(a, 0.8, { Color = p.atm.c, Decay = p.atm.d, Density = p.atm.den, Haze = p.atm.haze, Glare = p.atm.glare })
		local sk = Lighting:FindFirstChildOfClass("Sky")
		if not sk then
			sk = new("Sky", {}, Lighting)
			madeSky = sk
		end
		sk.StarCount = p.stars
	end
	table.insert(cleanups, function() if skyOrig then ctl.setSky(1) end end)

	-- Camera Lock
	local cmOrig
	local CAMS = { "Free", "First Person", "Third Person" }
	local function applyCam(i)
		pcall(function()
			if i == 1 then
				LP.CameraMode, LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance = cmOrig[1], cmOrig[2], cmOrig[3]
			elseif i == 2 then
				LP.CameraMode = Enum.CameraMode.LockFirstPerson
			else
				LP.CameraMode = Enum.CameraMode.Classic
				LP.CameraMinZoomDistance = 12
				LP.CameraMaxZoomDistance = math.max(cmOrig[3], 30)
			end
		end)
	end
	function ctl.setCamMode(i)
		S.camMode = i
		if ctl.camBtn then ctl.camBtn.Text = CAMS[i] end
		if not cmOrig then cmOrig = { LP.CameraMode, LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance } end
		applyCam(i)
	end
	local camAcc = 0
	connect(RunService.Heartbeat, function(dt)
		camAcc += dt
		if camAcc < 0.5 then return end
		camAcc = 0
		if S.camMode ~= 1 and cmOrig then applyCam(S.camMode) end
	end)
	table.insert(cleanups, function() if cmOrig then applyCam(1) end end)

	-- Chat commands (;command)
	local lastChat, lastChatT = "", 0
	local function onChat(text)
		if not F.chatCmd or type(text) ~= "string" or text:sub(1, 1) ~= ";" then return end
		if text == lastChat and os.clock() - lastChatT < 0.4 then return end
		lastChat, lastChatT = text, os.clock()
		local ok, m, good = pcall(ctl.runCommand, text:sub(2))
		if not ok then ctl.toast("Command failed", Color3.fromRGB(255, 100, 100))
		elseif m then ctl.toast(m, good and GREEN or Color3.fromRGB(255, 100, 100)) end
	end
	connect(LP.Chatted, onChat)
	pcall(function()
		local TCS = game:GetService("TextChatService")
		connect(TCS.MessageReceived, function(m)
			if m.TextSource and m.TextSource.UserId == LP.UserId then onChat(m.Text) end
		end)
	end)

	-- Dash animation: light trail, FOV punch, forward lean with arms swept back
	function ctl.dashFx(dir)
		local r, h, ch = hrp(), hum(), LP.Character
		if not (r and h and ch) then return end
		local a0 = new("Attachment", { Position = Vector3.new(0, 1.2, 0) }, r)
		local a1 = new("Attachment", { Position = Vector3.new(0, -1.2, 0) }, r)
		local tr = new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35, MinLength = 0, LightEmission = 1, FaceCamera = true,
			Color = ColorSequence.new(accA, accB),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) }) }, r)
		task.delay(0.8, function() tr:Destroy() a0:Destroy() a1:Destroy() end)
		local c = cam()
		if not F.fovActive then
			local f0 = c.FieldOfView
			tw(c, 0.07, { FieldOfView = f0 + 14 }, Enum.EasingStyle.Quad)
			task.delay(0.09, function() if not F.fovActive then tw(c, 0.35, { FieldOfView = f0 }) end end)
		end
		if F.fly then return end -- flight owns the body pose
		local function J(n)
			local m = ch:FindFirstChild(n, true)
			return (m and m:IsA("Motor6D")) and m or nil
		end
		local js = {}
		if h.RigType == Enum.HumanoidRigType.R15 then
			js = { rs = J("RightShoulder"), ls = J("LeftShoulder"), rh = J("RightHip"), lh = J("LeftHip"), nk = J("Neck") }
		end
		local gyro = new("BodyGyro", { MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 3e4, D = 800, CFrame = r.CFrame }, r)
		local t0, dur = os.clock(), 0.34
		pcall(function() RunService:UnbindFromRenderStep("VisionXDashFx") end)
		RunService:BindToRenderStep("VisionXDashFx", Enum.RenderPriority.Character.Value + 2, function()
			local k = (os.clock() - t0) / dur
			local rr = hrp()
			if k >= 1 or not rr or not gyro.Parent then
				RunService:UnbindFromRenderStep("VisionXDashFx")
				if gyro.Parent then gyro:Destroy() end
				for _, m in pairs(js) do
					if m.Parent then m.Transform = CFrame.new() end
				end
				return
			end
			local e = math.sin(math.pi * k)
			local A, rad = CFrame.Angles, math.rad
			gyro.CFrame = CFrame.lookAt(rr.Position, rr.Position + dir) * A(-rad(52) * e, 0, 0)
			if js.rs then js.rs.Transform = A(-rad(80) * e, 0, rad(12) * e) end
			if js.ls then js.ls.Transform = A(-rad(80) * e, 0, -rad(12) * e) end
			if js.rh then js.rh.Transform = A(rad(32) * e, 0, 0) end
			if js.lh then js.lh.Transform = A(-rad(32) * e, 0, 0) end
			if js.nk then js.nk.Transform = A(rad(34) * e, 0, 0) end
		end)
	end
	table.insert(cleanups, function() pcall(function() RunService:UnbindFromRenderStep("VisionXDashFx") end) end)
end

-- Save / load settings
local SAVE_FILE = "VisionX_settings.json"
function ctl.save()
	local data = { hue = S.hue, transparency = S.transparency, lock = S.lock, flight = S.flight, jump = S.jump,
		walk = S.walk, fov = S.fov, spin = S.spin,
		rainbow = F.rainbow, glow = F.glow, bg = S.bg, guiScale = S.guiScale, corner = S.corner, sbRight = S.sbRight, font = S.font,
		textSize = S.textSize, anim = S.anim, dragW = S.dragW, espTeam = S.espTeam, espEnemy = S.espEnemy, fpsColor = S.fpsColor,
		fpsPos = S.fpsPos, key = S.key, dashPow = S.dashPow, dashCd = S.dashCd, wcSpeed = S.wcSpeed, fcSpeed = S.fcSpeed, followDist = S.followDist,
		url = S.url, autoRe = TG["auto re-execute"] and TG["auto re-execute"].state or false, pins = S.pins,
		sprintMul = S.sprintMul, xrayT = S.xrayT, soundVol = S.soundVol, sound = S.sound, camMode = S.camMode, sky = S.sky, favs = S.favs, chatCmd = F.chatCmd, notify = S.notify }
	return (pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(data)) end))
end
function ctl.load()
	local ok, data = pcall(function()
		if isfile and isfile(SAVE_FILE) then return HttpService:JSONDecode(readfile(SAVE_FILE)) end
	end)
	if not ok or type(data) ~= "table" then return end
	if tonumber(data.hue) then ctl.hue.Set(data.hue * 360) end
	if tonumber(data.transparency) then ctl.transp.Set(data.transparency) end
	if data.lock ~= nil then ctl.lock.Set(data.lock == true) end
	if tonumber(data.flight) then ctl.flight.Set(data.flight) end
	if tonumber(data.jump) then ctl.jump.Set(data.jump) end
	if tonumber(data.walk) then ctl.walk.Set(data.walk) end
	if tonumber(data.spin) then ctl.spin.Set(data.spin) end
	if data.rainbow ~= nil then TG["rainbow mode"].Set(data.rainbow == true) end
	if data.glow ~= nil then TG["glow border"].Set(data.glow == true) end
	if data.sbRight ~= nil then TG["sidebar right"].Set(data.sbRight == true) end
	if tonumber(data.bg) then ctl.setBg(data.bg) end
	if tonumber(data.font) then ctl.setFont(data.font) end
	if tonumber(data.fpsColor) then ctl.setFpsColor(data.fpsColor) end
	if tonumber(data.fpsPos) then ctl.setFpsPos(data.fpsPos) end
	if type(data.key) == "string" then ctl.setKey(data.key) end
	if type(data.url) == "string" then S.url = data.url if ctl.urlBox then ctl.urlBox.Text = data.url end end
	if data.autoRe == true and TG["auto re-execute"] then TG["auto re-execute"].Set(true) end
	if type(data.pins) == "table" then
		for _, n in ipairs(data.pins) do if TG[n] or ACT[n] then ctl.pin(n, true) end end
	end
	for lbl, v in pairs({ ["sprint boost"] = data.sprintMul, ["x-ray"] = data.xrayT, ["click sounds"] = data.soundVol }) do
		if tonumber(v) and SL[lbl] then SL[lbl].Set(v) end
	end
	if data.sound ~= nil and TG["click sounds"] then TG["click sounds"].Set(data.sound == true) end
	if data.notify ~= nil and TG["notifications"] then
		S.notify = data.notify == true
		TG["notifications"].Set(S.notify, true)
	end
	if data.chatCmd ~= nil and TG["chat commands"] then TG["chat commands"].Set(data.chatCmd == true) end
	if tonumber(data.camMode) then ctl.setCamMode(data.camMode) end
	if tonumber(data.sky) and data.sky > 1 then ctl.setSky(data.sky) end
	if type(data.favs) == "table" then
		for _, n in ipairs(data.favs) do FAV.setByName(n) end
	end
	for lbl, v in pairs({ ["gui scale"] = data.guiScale, ["corner roundness"] = data.corner, ["text size"] = data.textSize,
		["animation speed"] = data.anim, ["drag weight"] = data.dragW, ["esp team color"] = data.espTeam, ["esp enemy color"] = data.espEnemy,
		["dash"] = data.dashPow, ["dash cooldown"] = data.dashCd, ["wall climb"] = data.wcSpeed, ["follow"] = data.followDist, ["freecam"] = data.fcSpeed }) do
		if tonumber(v) and SL[lbl] then SL[lbl].Set(v) end
	end
	if tonumber(data.fov) then ctl.fov.Set(data.fov, data.fov == D.fov) end
end

-- Sit
connect(RunService.Heartbeat, function()
	if F.sit then
		local h = hum()
		if h and not h.Sit then h.Sit = true end
	end
end)
table.insert(cleanups, function() local h = hum() if h and F.sit then h.Sit = false end end)

-- Fling Guard (other players stop colliding with you + launch speed is capped)
local fgOrig = {}
function ctl.fgOff()
	for part in pairs(fgOrig) do if part.Parent then part.CanCollide = true end end
	fgOrig = {}
end
connect(RunService.Stepped, function()
	if not F.fg then return end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and pl.Character then
			for _, part in ipairs(pl.Character:GetChildren()) do
				if part:IsA("BasePart") and part.CanCollide then
					fgOrig[part] = true
					part.CanCollide = false
				end
			end
		end
	end
end)
connect(RunService.Heartbeat, function()
	if not F.fg then return end
	local r, h = hrp(), hum()
	if not r or (h and h.SeatPart) or os.clock() < (ctl.dashUntil or 0) then return end
	local lim, up = 80, 150
	if F.ws then lim = math.max(lim, S.walk * 1.5) end
	if F.fly then lim = math.max(lim, S.flight * 15) up = math.max(up, S.flight * 15) end
	if F.jp then up = math.max(up, S.jump * 1.5) end
	local v = r.AssemblyLinearVelocity
	local hv = Vector3.new(v.X, 0, v.Z)
	if hv.Magnitude > lim or v.Y > up then
		if hv.Magnitude > lim then hv = hv.Unit * lim end
		r.AssemblyLinearVelocity = Vector3.new(hv.X, math.min(v.Y, up), hv.Z)
	end
	if r.AssemblyAngularVelocity.Magnitude > 30 then r.AssemblyAngularVelocity = Vector3.zero end
end)
table.insert(cleanups, function() F.fg = false ctl.fgOff() end)

-- Command box
do
	local M1, TCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
	local ALIAS = {
		fly = "flight", flight = "flight", noclip = "noclip", infjump = "infinite jump", infinitejump = "infinite jump", ij = "infinite jump",
		jp = "jump power", jumppower = "jump power", jump = "jump power", ws = "walkspeed", walkspeed = "walkspeed", speed = "walkspeed",
		nograv = "no gravity", nogravity = "no gravity", spin = "spin", sit = "sit", afk = "anti-afk", antiafk = "anti-afk",
		ctp = "click tp", clicktp = "click tp", esp = "esp", fps = "fps counter", fpscounter = "fps counter",
		fullbright = "fullbright", fb = "fullbright", freecam = "freecam", fc = "freecam", fpsboost = "fps boost", boost = "fps boost",
		lock = "position lock", positionlock = "position lock", rainbow = "rainbow mode", glow = "glow border", wc = "wall climb", wallclimb = "wall climb",
		stats = "stats overlay", alerts = "join/leave alerts", hide = "hide players", hideplayers = "hide players", noclipcam = "noclip camera", camnoclip = "noclip camera",
		plat = "platform", platform = "platform", sprint = "sprint boost", xray = "x-ray", sounds = "click sounds", clicksounds = "click sounds",
		chat = "chat commands", roles = "role esp", flingguard = "fling guard", antifling = "fling guard", fg = "fling guard",
	}
	local HELP = "flight/ws/jp/spin [n], noclip, infjump, nograv, sit, afk, ctp, esp, fps, fullbright, freecam, fpsboost, flingguard, lock, fov [n], transparent [n], tp <name>, spec <name>, reset, rejoin, hop, dash, rip, follow <name>, wc, stats, alerts, hide, noclipcam, plat, sprint [x10], xray, cam free|first|third, sky <name>. Stop with: stop <command> or stop all."
	local function title(n) return (n:gsub("^%l", string.upper)) end

	function ctl.runCommand(text)
		local words = {}
		for w in text:gmatch("%S+") do table.insert(words, w) end
		if #words == 0 then return nil end
		local cmd = words[1]:lower()
		local rest = table.concat(words, " ", 2)

		if cmd == "help" or cmd == "cmds" or cmd == "commands" then return HELP, true end

		if cmd == "stop" or cmd == "off" then
			local a = (words[2] or ""):lower()
			if a == "" then return "Usage: stop <command>  or  stop all", false end
			if a == "all" then
				for k, t in pairs(TG) do if t.state and not ctl.noStop[k] then t.Set(false) end end
				ctl.specStop()
				ctl.fovReset()
				return "Stopped everything", true
			end
			if a == "spec" or a == "spectate" then ctl.specStop() return "Stopped spectating", true end
			if a == "fov" then ctl.fovReset() return "FOV reset", true end
			if a == "follow" then ctl.followStop() return "Stopped following", true end
			local name = ALIAS[a]
			if name and TG[name] then
				if TG[name].state then TG[name].Set(false) end
				return title(name) .. " OFF", true
			end
			return "Unknown command: " .. a, false
		end

		if cmd == "follow" then
			if rest == "" then return "Type a player name", false end
			local fp_ = ctl.find(rest)
			if not fp_ then return "No player found", false end
			ctl.followStart(fp_)
			return "Following " .. fp_.DisplayName, true
		end
		if cmd == "dash" then ctl.dash() return "Dash", true end
		if cmd == "rip" then ctl.respawnHere() return "Respawning in place", true end
		if cmd == "cam" then
			local m = ({ free = 1, first = 2, third = 3 })[rest:lower()]
			if not m then return "Usage: cam free | first | third", false end
			ctl.setCamMode(m)
			return "Camera: " .. rest:lower(), true
		end
		if cmd == "sky" then
			for i, sk in ipairs(ctl.SKY) do
				if rest ~= "" and sk[1]:lower():find(rest:lower(), 1, true) then ctl.setSky(i) return "Sky: " .. sk[1], true end
			end
			return "Usage: sky default | sunset | night | galaxy | overcast | pink | bright", false
		end

		if cmd == "tp" or cmd == "spec" or cmd == "spectate" then
			if rest == "" then return "Type a player name", false end
			local p = ctl.find(rest)
			if not p then return "No player found", false end
			if cmd == "tp" then
				local r = hrp()
				local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if not (r and tr) then return p.DisplayName .. " has no character", false end
				r.CFrame = tr.CFrame * CFrame.new(0, 0, 4)
				return "Teleported to " .. p.DisplayName, true
			end
			ctl.specStart(p)
			return "Spectating " .. p.DisplayName, true
		end

		if cmd == "reset" or cmd == "respawn" then ctl.forceReset() return "Reset", true end
		if cmd == "rejoin" then ctl.rejoin() return "Rejoining...", true end
		if cmd == "hop" then
			ctl.hop(function(t, c) ctl.cmdSay(t, c) end)
			return "Searching servers...", true
		end

		local num = tonumber(words[2])
		if cmd == "fov" then
			if not num then return "Usage: fov <number>", false end
			SL["fov"].Set(num)
			return "FOV " .. SL["fov"].value, true
		end
		if cmd == "transparent" or cmd == "transparency" then
			if not num then return "Usage: transparent <0-100>", false end
			SL["transparent"].Set(num)
			return "Transparency " .. SL["transparent"].value .. "%", true
		end

		local name = ALIAS[cmd]
		if name and TG[name] then
			local extra = ""
			if name == "sprint boost" and num and num < 10 then num = num * 10 end
			if num and SL[name] then
				SL[name].Set(num)
				extra = " (" .. SL[name].value .. ")"
			end
			if not TG[name].state then TG[name].Set(true) end
			return title(name) .. " ON" .. extra, true
		end
		return "Unknown command. Type help", false
	end

	-- small window
	local vs0 = cam().ViewportSize
	local cbPos = Vector2.new(vs0.X / 2, 70)
	local cb = new("CanvasGroup", { Name = "Commands", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cbPos.X, cbPos.Y),
		Size = UDim2.fromOffset(300, 150), BackgroundColor3 = BLACK, BorderSizePixel = 0, Visible = false, GroupTransparency = 1, Active = true }, gui)
	rcorner(cb, 12)
	gradient(stroke(cb, Color3.new(1, 1, 1), 1.3, 0.35))
	bg(cb, 0, "main")
	local cs = new("UIScale", { Scale = 0.9 }, cb)

	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PANEL, BorderSizePixel = 0, Active = true }, cb)
	bg(head, 0, "panel")
	local tl = txt(head, { Text = "Commands", Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 120, 1, 0), Font = Enum.Font.GothamBlack,
		TextSize = 13, TextColor3 = Color3.new(1, 1, 1) })
	gradient(tl)
	local x = button(head, { Text = "X", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(46, 20, 24), TextColor3 = Color3.fromRGB(255, 100, 105), TextSize = 11 })
	x.MouseButton1Click:Connect(function() ctl.cmdToggle(false) end)

	local box = new("TextBox", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = Color3.fromRGB(12, 12, 16),
		PlaceholderText = "e.g. walkspeed 100  |  stop flight", PlaceholderColor3 = DIM, Text = "", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = TEXT, ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, cb)
	corner(box, 7)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	local bst = stroke(box, LINE, 1)
	box.Focused:Connect(function() tw(bst, 0.2, { Color = accA }) end)
	box.FocusLost:Connect(function() tw(bst, 0.25, { Color = LINE }) end)

	local msg = txt(cb, { Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 0, 72), TextSize = 11, TextColor3 = DIM, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Text = "Type a command and press enter. Type help for the list." })
	function ctl.cmdSay(t, col)
		msg.Text = t
		msg.TextColor3 = col or DIM
	end
	box.FocusLost:Connect(function(enter)
		if not enter then return end
		local text = box.Text
		box.Text = ""
		local ok, r1, r2 = pcall(ctl.runCommand, text)
		if not ok then ctl.cmdSay("Command failed", Color3.fromRGB(255, 120, 120))
		elseif r1 then ctl.cmdSay(r1, r2 and GREEN or Color3.fromRGB(255, 120, 120)) end
	end)

	-- drag by header
	local dr, dIn, dS, dO = false, nil, nil, nil
	head.InputBegan:Connect(function(i)
		if i.UserInputType == M1 or i.UserInputType == TCH then
			dr, dIn, dS, dO = true, i, Vector2.new(i.Position.X, i.Position.Y), cbPos
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i == dIn) then
			local v = cam().ViewportSize
			local np = dO + (Vector2.new(i.Position.X, i.Position.Y) - dS)
			cbPos = Vector2.new(math.clamp(np.X, 150, math.max(150, v.X - 150)), math.clamp(np.Y, 0, math.max(0, v.Y - 40)))
			cb.Position = UDim2.fromOffset(cbPos.X, cbPos.Y)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if dr and (i == dIn or i.UserInputType == M1) then dr = false end
	end)

	ctl.cmdOpen = false
	function ctl.cmdToggle(open)
		ctl.cmdOpen = open
		if open then
			cb.Visible = true
			cs.Scale = 0.9
			cb.GroupTransparency = 1
			tw(cb, 0.28, { GroupTransparency = 0 })
			tw(cs, 0.32, { Scale = 1 })
		else
			tw(cb, 0.2, { GroupTransparency = 1 })
			tw(cs, 0.2, { Scale = 0.92 })
			task.delay(0.22 / ANIM, function() if not ctl.cmdOpen then cb.Visible = false end end)
		end
	end
end

-- Freecam (drone) + Click TP
do
	local M1, TCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
	local fcOn = false

	local fc = new("Frame", { Name = "Freecam", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)

	-- 4 movement buttons (left side)
	local pad = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -28), Size = UDim2.fromOffset(170, 170),
		BackgroundTransparency = 1 }, fc)
	local held, heldIn, padBtns = { f = false, b = false, l = false, r = false, u = false, d = false }, {}, {}
	local function padBtn(key, label, x, y)
		local b = button(pad, { Text = label, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(56, 56), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, TextSize = 11 })
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 28)
		gradient(stroke(b, Color3.new(1, 1, 1), 1.5, 0.1))
		b.InputBegan:Connect(function(i)
			if i.UserInputType == M1 or i.UserInputType == TCH then
				held[key], heldIn[key] = true, i
				tw(b, 0.1, { BackgroundColor3 = Color3.fromRGB(46, 46, 58) })
			end
		end)
		padBtns[key] = b
	end
	padBtn("f", "FWD", 85, 30)
	padBtn("b", "BACK", 85, 140)
	padBtn("l", "LEFT", 30, 85)
	padBtn("r", "RIGHT", 140, 85)
	padBtn("u", "UP", 214, 56)
	padBtn("d", "DOWN", 214, 116)
	connect(UIS.InputEnded, function(i)
		for k, inp in pairs(heldIn) do
			if inp == i or (i.UserInputType == M1 and inp.UserInputType == M1) then
				held[k], heldIn[k] = false, nil
				tw(padBtns[k], 0.2, { BackgroundColor3 = BLACK })
			end
		end
	end)

	-- joystick (right side) + exit above it
	local base = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -34), Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = BLACK, BackgroundTransparency = 0.3, Active = true }, fc)
	corner(base, 65)
	gradient(stroke(base, Color3.new(1, 1, 1), 1.5, 0.1))
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, base)
	corner(knob, 26)
	gradient(knob)
	local exitBtn = button(fc, { Text = "EXIT", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(1, -95, 1, -176),
		Size = UDim2.fromOffset(90, 32), BackgroundColor3 = Color3.fromRGB(46, 20, 24), TextColor3 = Color3.fromRGB(255, 100, 105) })
	stroke(exitBtn, Color3.fromRGB(150, 40, 50), 1)
	exitBtn.MouseButton1Click:Connect(function() ctl.fcT.Set(false) end)

	local stick, sIn, sStart = Vector2.zero, nil, nil
	base.InputBegan:Connect(function(i)
		if i.UserInputType == M1 or i.UserInputType == TCH then
			sIn, sStart = i, Vector2.new(i.Position.X, i.Position.Y)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if sIn and (i.UserInputType == Enum.UserInputType.MouseMovement or i == sIn) then
			local d = Vector2.new(i.Position.X, i.Position.Y) - sStart
			if d.Magnitude > 45 then d = d.Unit * 45 end
			stick = d / 45
			knob.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if sIn and (i == sIn or i.UserInputType == M1) then
			sIn, stick = nil, Vector2.zero
			tw(knob, 0.18, { Position = UDim2.fromScale(0.5, 0.5) })
		end
	end)

	local fcPos, fcYaw, fcPitch, fcType
	function ctl.freecam(on)
		if on == fcOn then return end
		fcOn = on
		local c = cam()
		if on then
			fcPos = c.CFrame.Position
			fcPitch, fcYaw = c.CFrame:ToOrientation()
			fcType = c.CameraType
			c.CameraType = Enum.CameraType.Scriptable
			pcall(function()
				local pm = LP.PlayerScripts:FindFirstChild("PlayerModule")
				if pm then require(pm):GetControls():Disable() end
			end)
			fc.Visible = true
			ctl.fcMinned = not ctl.isMin()
			if ctl.fcMinned then ctl.minimize() end
		else
			fc.Visible = false
			for k in pairs(held) do held[k], heldIn[k] = false, nil end
			stick = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
			c.CameraType = fcType or Enum.CameraType.Custom
			local h = hum()
			if h then c.CameraSubject = h end
			pcall(function()
				local pm = LP.PlayerScripts:FindFirstChild("PlayerModule")
				if pm then require(pm):GetControls():Enable() end
			end)
			if ctl.fcMinned then ctl.restore() end
			ctl.fcMinned = false
		end
	end
	connect(RunService.RenderStepped, function(dt)
		if not fcOn then return end
		local c = cam()
		fcYaw -= stick.X * 2.2 * dt
		fcPitch = math.clamp(fcPitch - stick.Y * 1.6 * dt, -1.5, 1.5)
		local rot = CFrame.fromOrientation(fcPitch, fcYaw, 0)
		local fwd = (held.f and 1 or 0) - (held.b and 1 or 0)
		local side = (held.r and 1 or 0) - (held.l and 1 or 0)
		local vert = (held.u and 1 or 0) - (held.d and 1 or 0)
		fcPos += (rot.LookVector * fwd + rot.RightVector * side + Vector3.new(0, vert, 0)) * S.fcSpeed * dt
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = CFrame.new(fcPos) * rot
	end)
	table.insert(cleanups, function() ctl.freecam(false) end)

	-- Click TP (taps only, ignores GUI taps and camera drags)
	local recs = {}
	local function key(i) return i.UserInputType == TCH and i or "mouse" end
	connect(UIS.InputBegan, function(i, gp)
		if gp or not F.ctp then return end
		if i.UserInputType == M1 or i.UserInputType == TCH then
			recs[key(i)] = { p = Vector2.new(i.Position.X, i.Position.Y), t = os.clock() }
		end
	end)
	connect(UIS.InputEnded, function(i)
		if i.UserInputType ~= M1 and i.UserInputType ~= TCH then return end
		local rec = recs[key(i)]
		recs[key(i)] = nil
		if not rec or not F.ctp or fcOn then return end
		local pt = Vector2.new(i.Position.X, i.Position.Y)
		if (pt - rec.p).Magnitude > 12 or os.clock() - rec.t > 0.4 then return end
		local ray = cam():ScreenPointToRay(pt.X, pt.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { LP.Character }
		local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
		local r = hrp()
		if res and r then r.CFrame = CFrame.new(res.Position + Vector3.new(0, 3, 0)) * (r.CFrame - r.CFrame.Position) end
	end)
end

---------------------------------------------------------------------
-- Minimize / restore / close
---------------------------------------------------------------------
local bubble = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 46), Text = "V", TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = BLACK, AutoButtonColor = false, BorderSizePixel = 0, Visible = false }, gui)
corner(bubble, 14)
gradient(stroke(bubble, Color3.new(1, 1, 1), 1.5, 0.1))
bg(bubble, 0, "main")
local bScale = new("UIScale", { Scale = 0 }, bubble)

local minimized, busy, closed = false, false, false
local bubblePos, bubbleMoved = Vector2.zero, false
local function minimize()
	if busy or minimized or closed then return end
	busy, minimized = true, true
	local vs = cam().ViewportSize
	bubblePos = Vector2.new(math.clamp(pos.X, 25, vs.X - 25), math.clamp(pos.Y, 25, vs.Y - 25))
	bubbleMoved = false
	bubble.Position = UDim2.fromOffset(bubblePos.X, bubblePos.Y)
	tw(main, 0.3, { GroupTransparency = 1 }, Q, IN)
	tw(scale, 0.3, { Scale = 0.15 }, Q, IN)
	task.delay(0.22 / ANIM, function()
		bubble.Visible = true
		bScale.Scale = 0.2
		tw(bScale, 0.32, { Scale = 1 }, B)
	end)
	task.delay(0.34 / ANIM, function() main.Visible = false busy = false end)
end
local function restore()
	if busy or not minimized or closed then return end
	busy, minimized = true, false
	if bubbleMoved then
		pos = fitOnScreen(bubblePos)
		target = pos
		main.Position = UDim2.fromOffset(pos.X, pos.Y)
		bubbleMoved = false
	end
	main.Visible = true
	main.GroupTransparency = 1
	scale.Scale = 0.15
	tw(bScale, 0.18, { Scale = 0.2 }, Q, IN)
	task.delay(0.1 / ANIM, function()
		tw(main, 0.4, { GroupTransparency = 0 })
		tw(scale, 0.45, { Scale = gs() })
	end)
	task.delay(0.2 / ANIM, function() bubble.Visible = false end)
	task.delay(0.5 / ANIM, function() busy = false end)
end
minBtn.MouseButton1Click:Connect(minimize)
ctl.minimize, ctl.restore, ctl.isMin = minimize, restore, function() return minimized end
do
	local M1, TCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
	local bDrag, bInput, bStart, bOrigin, bDragged = false, nil, nil, nil, false
	bubble.InputBegan:Connect(function(i)
		if (i.UserInputType == M1 or i.UserInputType == TCH) and minimized then
			bDrag, bInput, bDragged = true, i, false
			bStart, bOrigin = Vector2.new(i.Position.X, i.Position.Y), bubblePos
		end
	end)
	connect(UIS.InputChanged, function(i)
		if bDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i == bInput) then
			local d = Vector2.new(i.Position.X, i.Position.Y) - bStart
			if d.Magnitude > 8 then bDragged = true end
			if bDragged then
				local vs = cam().ViewportSize
				bubblePos = Vector2.new(math.clamp(bOrigin.X + d.X, 25, vs.X - 25), math.clamp(bOrigin.Y + d.Y, 25, vs.Y - 25))
				bubble.Position = UDim2.fromOffset(bubblePos.X, bubblePos.Y)
			end
		end
	end)
	connect(UIS.InputEnded, function(i)
		if bDrag and (i == bInput or i.UserInputType == M1) then
			bDrag = false
			if bDragged then bubbleMoved = true else restore() end
		end
	end)
end
bubble.MouseEnter:Connect(function() tw(bScale, 0.15, { Scale = 1.08 }) end)
bubble.MouseLeave:Connect(function() tw(bScale, 0.2, { Scale = 1 }) end)

local function closeGui()
	if closed then return end
	closed = true
	stopDrag()
	for _, f in ipairs(cleanups) do pcall(f) end
	for _, c in ipairs(conns) do c:Disconnect() end
	pcall(function() main.Interactable = false bubble.Interactable = false end)
	fpsLabel.Visible = false
	if minimized then
		tw(bScale, 0.22, { Scale = 0 }, Q, IN)
	else
		tw(main, 0.25, { GroupTransparency = 1 }, Q, IN)
		tw(scale, 0.25, { Scale = 0.9 * gs() }, Q, IN)
	end
	task.delay(0.3 / ANIM, function() gui:Destroy() end)
end
closeBtn.MouseButton1Click:Connect(closeGui)
env.VisionXClose = closeGui

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
applyTheme()
applyTransparency()
current = nil
switchTo("Main")
do
	local vs = cam().ViewportSize
	local k = math.min(1, (vs.X - 24) / W, (vs.Y - 24) / H)
	if k < 1 and SL["gui scale"] then SL["gui scale"].Set(math.max(50, math.floor(k * 100))) end
end
if TG["notifications"] then TG["notifications"].Set(true, true) end
pcall(ctl.buildPins)
pcall(ctl.load)
if game.PlaceId == 142823291 and TG["role esp"] then TG["role esp"].Set(true) end
task.delay(0.9, function() if ctl.toast then ctl.toast("Vision X " .. VERSION .. " loaded", accA) end end)
tw(main, 0.45, { GroupTransparency = 0 })
tw(scale, 0.55, { Scale = gs() }, Enum.EasingStyle.Back)

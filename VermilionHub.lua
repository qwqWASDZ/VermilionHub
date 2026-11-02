--[[
	VERMILION HUB intro -> then Command Bar loads (LocalScript, client only)
	Put in: StarterPlayer > StarterPlayerScripts  (must be a LocalScript)

	Intro replay: press P (keyboard)
	Command bar: tap the bar (mobile) or press ; (keyboard), Enter to run, "cmds" for the list
	Click-teleport: "tpmouse" / "tm" (stays on)  ->  "untpmouse" / "untm" (off)
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

if not RunService:IsClient() then
	warn("[VermilionHub] This must be a LocalScript, not a Script.")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

print("[VermilionHub] Loaded")

local CONFIG = {
	Title = "VERMILION",
	Subtitle = "ACCESS GRANTED",
	HoldTime = 2,
	ReplayKey = Enum.KeyCode.P,
	PlayOnJoin = true,
	TitleFont = (function() local ok, f = pcall(function() return Enum.Font.Michroma end) return ok and f or Enum.Font.SciFi end)(), -- try Enum.Font.SciFi, Enum.Font.Arcade, Enum.Font.Bangers too
}

local TEAL = Color3.fromRGB(255, 45, 45)
local CYAN_TOP = Color3.fromRGB(10, 10, 12)
local CYAN_BOTTOM = Color3.fromRGB(70, 6, 12)

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- animated glow: a bright comet of light travels around every outline, with a slow breathing
-- on the thickness. Solid fills (accent bars, progress bars) breathe in brightness.
local glowStrokes, glowFills = {}, {}
local glowEnabled = true
local glowColor = Color3.fromRGB(227, 66, 52)
local glowSpeed = 2
local glowSeq, glowVer = nil, 0
local function buildGlowSeq()
	local dark = glowColor:Lerp(Color3.new(0, 0, 0), 0.72)
	local hot = glowColor:Lerp(Color3.new(1, 1, 1), 0.65)
	glowSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, dark),
		ColorSequenceKeypoint.new(0.30, glowColor:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(0.46, glowColor),
		ColorSequenceKeypoint.new(0.5, hot),
		ColorSequenceKeypoint.new(0.54, glowColor),
		ColorSequenceKeypoint.new(0.70, glowColor:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(1, dark),
	})
	glowVer += 1
end
buildGlowSeq()
local function glow(stroke, baseThickness)
	local grad = Instance.new("UIGradient")
	grad.Color = glowSeq
	grad.Parent = stroke
	stroke.Color = Color3.new(1, 1, 1)
	table.insert(glowStrokes, {
		stroke = stroke, grad = grad, base = baseThickness or stroke.Thickness,
		ver = glowVer, phase = (#glowStrokes * 67) % 360,
	})
	return stroke
end
local function glowFrame(inst, thickness)
	local st = Instance.new("UIStroke")
	st.Thickness = thickness or 2
	st.Parent = inst
	return glow(st)
end
local function glowFill(inst)
	table.insert(glowFills, inst)
	return inst
end
task.spawn(function()
	while true do
		local t = os.clock()
		local rot = (t * glowSpeed * 70) % 360
		local breathe = (math.sin(t * glowSpeed * 1.3) + 1) / 2
		local dim = glowColor:Lerp(Color3.new(0, 0, 0), 0.4)
		local col = dim:Lerp(glowColor, breathe)
		for n = #glowStrokes, 1, -1 do
			local g = glowStrokes[n]
			if not g.stroke.Parent then
				table.remove(glowStrokes, n)
			elseif glowEnabled then
				g.grad.Enabled = true
				g.stroke.Color = Color3.new(1, 1, 1)
				if g.ver ~= glowVer then g.grad.Color = glowSeq g.ver = glowVer end
				g.grad.Rotation = (rot + g.phase) % 360
				g.stroke.Thickness = g.base * (0.95 + 0.25 * breathe)
			else
				g.grad.Enabled = false
				g.stroke.Color = glowColor
				g.stroke.Thickness = g.base
			end
		end
		for n = #glowFills, 1, -1 do
			local f = glowFills[n]
			if not f.Parent then table.remove(glowFills, n)
			else f.BackgroundColor3 = glowEnabled and col or glowColor end
		end
		RunService.Heartbeat:Wait()
	end
end)

-- fonts: every UI font is remapped to a cooler built-in one (Michroma headings, Jura text, Sarpanch for command text).
-- Uses Roblox's built-in Enum.Font so nothing can fail to load; missing ones fall back to the original font.
local FONT_DIR = "rbxasset://fonts/families/"
local function pickFont(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end
local fontMap = {
	[Enum.Font.Code] = pickFont("Sarpanch", Enum.Font.Code),
	[Enum.Font.GothamBlack] = pickFont("Michroma", Enum.Font.GothamBlack),
	[Enum.Font.GothamBold] = pickFont("Jura", Enum.Font.GothamBold),
	[Enum.Font.GothamMedium] = pickFont("Jura", Enum.Font.GothamMedium),
	[Enum.Font.Gotham] = pickFont("Jura", Enum.Font.Gotham),
}
local function restyleFont(o)
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		local f = fontMap[o.Font]
		if f and f ~= o.Font then o.Font = f end
	end
end
local function restyleTree(root)
	for _, d in ipairs(root:GetDescendants()) do restyleFont(d) end
	root.DescendantAdded:Connect(function(d) task.defer(restyleFont, d) end)
end

--==================================================================
-- COMMAND BAR (loads once, after the intro animation ends)
--==================================================================
local commandBarLoaded = false

local function loadCommandBar()
if commandBarLoaded then return end
commandBarLoaded = true

print("[CommandBar] starting")

local commands, COMMAND_LIST, descriptions = {}, {}, {}

---------------------------------------------------------------- GUI
local old = playerGui:FindFirstChild("TopCommandGui")
if old then old:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TopCommandGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
restyleTree(screenGui)

-- everything in the hub is drawn smaller (change with the "uiscale" command)
local UI_SCALE = 0.78
local mainScale = Instance.new("UIScale")
mainScale.Name = "MainScale"
mainScale.Scale = UI_SCALE * 0.6
mainScale.Parent = screenGui
tween(mainScale, 0.8, { Scale = UI_SCALE }, Enum.EasingStyle.Back)

-- animation helpers: one UIScale per object drives hover / press / pop-in / pulse
local function animScale(obj)
	local sc = obj:FindFirstChild("AnimScale")
	if not sc then
		sc = Instance.new("UIScale")
		sc.Name = "AnimScale"
		sc.Parent = obj
	end
	return sc
end
local function pulse(obj, amount)
	local sc = animScale(obj)
	sc.Scale = 1 + (amount or 0.06)
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
local function animateButton(b)
	if b:GetAttribute("Animated") then return end
	b:SetAttribute("Animated", true)
	local sc = animScale(b)
	b.MouseEnter:Connect(function() tween(sc, 0.15, { Scale = 1.08 }, Enum.EasingStyle.Quad) end)
	b.MouseLeave:Connect(function() tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.08, { Scale = 0.9 }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.25, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
end
local function popOnShow(obj)
	if obj:GetAttribute("Pop") then return end
	obj:SetAttribute("Pop", true)
	local sc = animScale(obj)
	obj:GetPropertyChangedSignal("Visible"):Connect(function()
		if obj.Visible then
			sc.Scale = 0.55
			tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end
local function autoAnimate(d)
	if d:IsA("TextButton") then animateButton(d) end
	-- anything that starts hidden (fly buttons, AIM panel, HUD...) pops in when it's shown
	if d:IsA("GuiObject") and not d.Visible and not d:IsA("ScrollingFrame") then popOnShow(d) end
end
for _, d in ipairs(screenGui:GetDescendants()) do autoAnimate(d) end
screenGui.DescendantAdded:Connect(autoAnimate)

local outerFrame = Instance.new("Frame")
outerFrame.Name = "OuterFrame"
outerFrame.Size = UDim2.new(0, 260, 0, 36)
outerFrame.AnchorPoint = Vector2.new(0.5, 0)
outerFrame.Position = UDim2.new(0.5, 0, 0, 50)
outerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
outerFrame.BorderSizePixel = 0
outerFrame.Parent = screenGui
Instance.new("UICorner", outerFrame).CornerRadius = UDim.new(0, 4)

local outerStroke = Instance.new("UIStroke")
outerStroke.Color = Color3.fromRGB(227, 66, 52)
outerStroke.Thickness = 2
outerStroke.Parent = outerFrame
glow(outerStroke)


local cmdBar = Instance.new("TextBox")
cmdBar.Name = "CommandBar"
cmdBar.Size = UDim2.new(1, -12, 1, -14)
cmdBar.Position = UDim2.new(0, 6, 0, 4)
cmdBar.BackgroundColor3 = Color3.fromRGB(29, 29, 33)
cmdBar.BackgroundTransparency = 0.1
cmdBar.TextColor3 = Color3.fromRGB(237, 237, 240)
cmdBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 128)
cmdBar.PlaceholderText = "type a command"
cmdBar.Text = ""
cmdBar.TextSize = 14
cmdBar.Font = Enum.Font.Code
cmdBar.ClearTextOnFocus = false
cmdBar.TextXAlignment = Enum.TextXAlignment.Left
cmdBar.Parent = outerFrame
Instance.new("UICorner", cmdBar).CornerRadius = UDim.new(0, 3)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 4)
accentBar.Position = UDim2.new(0, 0, 1, -4)
accentBar.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
accentBar.BorderSizePixel = 0
accentBar.Parent = outerFrame
glowFill(accentBar)

local suggestionsFrame = Instance.new("ScrollingFrame")
suggestionsFrame.Size = UDim2.new(1, 0, 0, 0)
suggestionsFrame.Position = UDim2.new(0, 0, 1, 4)
suggestionsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
suggestionsFrame.BorderSizePixel = 0
suggestionsFrame.Visible = false
suggestionsFrame.ScrollBarThickness = 3
suggestionsFrame.ZIndex = 5
suggestionsFrame.Parent = outerFrame
Instance.new("UICorner", suggestionsFrame).CornerRadius = UDim.new(0, 4)

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = suggestionsFrame

-- FPS label
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 90, 0, 22)
fpsLabel.Position = UDim2.new(0, 8, 0, 50)
fpsLabel.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
fpsLabel.BackgroundTransparency = 0.3
fpsLabel.TextColor3 = Color3.fromRGB(237, 237, 240)
fpsLabel.Font = Enum.Font.Code
fpsLabel.TextSize = 13
fpsLabel.Text = "FPS: --"
fpsLabel.Visible = false
fpsLabel.Parent = screenGui
Instance.new("UICorner", fpsLabel).CornerRadius = UDim.new(0, 4)

-- Command list panel
local helpPanel = Instance.new("ScrollingFrame")
helpPanel.Size = UDim2.new(0, 300, 0, 280)
helpPanel.AnchorPoint = Vector2.new(0.5, 0)
helpPanel.Position = UDim2.new(0.5, 0, 1, 10)
helpPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
helpPanel.BackgroundTransparency = 0.1
helpPanel.BorderSizePixel = 0
helpPanel.ScrollBarThickness = 4
helpPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
helpPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
helpPanel.Visible = false
helpPanel.Parent = outerFrame
Instance.new("UICorner", helpPanel).CornerRadius = UDim.new(0, 6)
glowFrame(helpPanel, 2)

local helpText = Instance.new("TextLabel")
helpText.Size = UDim2.new(1, -12, 0, 0)
helpText.Position = UDim2.new(0, 6, 0, 6)
helpText.AutomaticSize = Enum.AutomaticSize.Y
helpText.BackgroundTransparency = 1
helpText.TextColor3 = Color3.fromRGB(237, 237, 240)
helpText.Font = Enum.Font.Code
helpText.TextSize = 13
helpText.TextXAlignment = Enum.TextXAlignment.Left
helpText.TextYAlignment = Enum.TextYAlignment.Top
helpText.TextWrapped = true
helpText.Text = ""
helpText.Parent = helpPanel

local function updateSuggestions()
	local wasOpen = suggestionsFrame.Visible
	for _, c in ipairs(suggestionsFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local text = cmdBar.Text:lower():gsub("^%s+", "")
	text = text:gsub("^[;:/]", "")
	local firstWord = text:match("%S+") or ""
	if firstWord == "" or text:find("%s") then
		suggestionsFrame.Visible = false
		return
	end

	local matches = {}
	for _, cmd in ipairs(COMMAND_LIST) do
		if cmd:sub(1, #firstWord) == firstWord or cmd:find(firstWord, 1, true) then
			table.insert(matches, cmd)
		end
	end
	if #matches == 0 then
		suggestionsFrame.Visible = false
		return
	end

	for _, m in ipairs(matches) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -6, 0, 22)
		btn.BackgroundColor3 = Color3.fromRGB(29, 29, 33)
		btn.TextColor3 = Color3.fromRGB(237, 237, 240)
		btn.Text = "  " .. m
		btn.TextSize = 13
		btn.Font = Enum.Font.Code
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BorderSizePixel = 0
		btn.Parent = suggestionsFrame
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
		if not wasOpen then -- first appearance: rows slide/fade in one after another
			local idx = #suggestionsFrame:GetChildren()
			btn.BackgroundTransparency, btn.TextTransparency = 1, 1
			task.delay(math.min(idx, 8) * 0.025, function()
				if btn.Parent then
					tween(btn, 0.25, { BackgroundTransparency = 0, TextTransparency = 0 })
				end
			end)
		end
		btn.MouseButton1Click:Connect(function()
			cmdBar.Text = m .. " "
			cmdBar:CaptureFocus()
		end)
	end

	local targetH = math.min(#matches * 24, 120)
	suggestionsFrame.CanvasSize = UDim2.new(0, 0, 0, #matches * 24)
	if not wasOpen then
		suggestionsFrame.Size = UDim2.new(1, 0, 0, 0)
		suggestionsFrame.Visible = true
	end
	tween(suggestionsFrame, 0.22, { Size = UDim2.new(1, 0, 0, targetH) }, Enum.EasingStyle.Quint)
end
cmdBar:GetPropertyChangedSignal("Text"):Connect(updateSuggestions)

---------------------------------------------------------------- helpers
local function add(names, desc, fn)
	local list = type(names) == "table" and names or { names }
	table.insert(COMMAND_LIST, list[1])
	descriptions[list[1]] = desc
	for _, n in ipairs(list) do commands[n] = fn end
end

local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(1, 0)
toastHolder.Position = UDim2.new(1, -10, 0, 84)
toastHolder.Size = UDim2.fromOffset(200, 0)
toastHolder.AutomaticSize = Enum.AutomaticSize.Y
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 50
toastHolder.Parent = screenGui
do
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = toastHolder
end
local toastCount = 0
local function notify(text)
	toastCount += 1
	local slot = Instance.new("Frame")
	slot.LayoutOrder = toastCount
	slot.Size = UDim2.new(1, 0, 0, 28)
	slot.BackgroundTransparency = 1
	slot.Parent = toastHolder
	local kids = toastHolder:GetChildren()
	for n = 1, #kids - 6 do if kids[n]:IsA("Frame") then kids[n]:Destroy() end end

	local card = Instance.new("Frame")
	card.Position = UDim2.new(1.25, 0, 0, 0)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
	card.BorderSizePixel = 0
	card.ZIndex = 50
	card.Parent = slot
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	glowFrame(card, 1.5)
	local accent = Instance.new("Frame")
	accent.Position = UDim2.new(0, 6, 0, 6)
	accent.Size = UDim2.new(0, 2, 1, -12)
	accent.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
	accent.BorderSizePixel = 0
	accent.ZIndex = 51
	accent.Parent = card
	Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 14, 0, 0)
	label.Size = UDim2.new(1, -20, 1, -3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = Color3.fromRGB(237, 237, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextWrapped = true
	label.Text = tostring(text)
	label.ZIndex = 51
	label.Parent = card
	local life = Instance.new("Frame")
	life.Position = UDim2.new(0, 8, 1, -3)
	life.Size = UDim2.new(1, -16, 0, 1)
	life.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
	life.BorderSizePixel = 0
	life.ZIndex = 51
	life.Parent = card

	tween(card, 0.45, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
	tween(life, 3.6, { Size = UDim2.new(0, 0, 0, 1) }, Enum.EasingStyle.Linear)
	task.delay(3.7, function()
		if not card.Parent then return end
		tween(card, 0.3, { Position = UDim2.new(1.25, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.3)
		slot:Destroy()
	end)
end

local function getChar()
	local char = player.Character
	if not char then return end
	return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function findPlayer(name)
	if not name then return nil end
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
end

local function targetHrp(name)
	local t = findPlayer(name)
	return t, t and t.Character and t.Character:FindFirstChild("HumanoidRootPart")
end

local lastCF, savedCF
local function teleport(cf)
	local _, _, hrp = getChar()
	if not hrp then return end
	lastCF = hrp.CFrame
	hrp.CFrame = cf
end

local state = { godding = false, noclipping = false, infjump = false, spin = 0, lockspeed = nil, clicktp = false }

---------------------------------------------------------------- fly
local flying, flySpeed = false, 60
local bv, bg
local flyUp, flyDown = false, false

-- on-screen buttons (hold to fly up/down) - they only show while flying
local function makeFlyButton(text, yOffset, onChange)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -14, 0.5, yOffset)
	b.Size = UDim2.fromOffset(52, 52)
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
	b.TextColor3 = Color3.fromRGB(237, 237, 240)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 22
	b.Text = text
	b.Visible = false
	b.AutoButtonColor = true
	b.Parent = screenGui
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(227, 66, 52)
	s.Thickness = 1.5
	s.Parent = b

	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	b.InputBegan:Connect(function(input)
		if isPress(input) then onChange(true) end
	end)
	b.InputEnded:Connect(function(input)
		if isPress(input) then onChange(false) end
	end)
	return b
end

local upBtn = makeFlyButton("▲", -30, function(v) flyUp = v end)
local downBtn = makeFlyButton("▼", 30, function(v) flyDown = v end)

local function stopFlying()
	flying = false
	flyUp, flyDown = false, false
	upBtn.Visible = false
	downBtn.Visible = false
	RunService:UnbindFromRenderStep("CmdFly")
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local _, hum = getChar()
	if hum then hum.PlatformStand = false end
end

local function startFlying()
	stopFlying()
	local _, hum, hrp = getChar()
	if not hrp then return end
	flying = true
	upBtn.Visible = true
	downBtn.Visible = true

	bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp

	bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bg.P = 1e4
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	hum.PlatformStand = true

	RunService:BindToRenderStep("CmdFly", Enum.RenderPriority.Character.Value + 1, function()
		if not flying or not hrp.Parent then return stopFlying() end
		local cam = workspace.CurrentCamera
		local typing = UIS:GetFocusedTextBox() ~= nil
		local goUp = flyUp or (not typing and (UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E)))
		local goDown = flyDown or (not typing and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q)))
		local up = (goUp and flySpeed or 0) - (goDown and flySpeed or 0)
		bv.Velocity = hum.MoveDirection * flySpeed + Vector3.new(0, up, 0)
		bg.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector * Vector3.new(1, 0, 1))
	end)
end

---------------------------------------------------------------- loops
RunService.Stepped:Connect(function()
	if not state.noclipping then return end
	local char = getChar()
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)

RunService.Heartbeat:Connect(function()
	local _, hum, hrp = getChar()
	if not hum then return end
	if state.godding and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
	if state.lockspeed then hum.WalkSpeed = state.lockspeed end
	if state.spin ~= 0 and hrp then hrp.CFrame *= CFrame.Angles(0, math.rad(state.spin), 0) end
end)

UIS.JumpRequest:Connect(function()
	if not state.infjump then return end
	local _, hum = getChar()
	if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

local frames, lastT = 0, os.clock()
RunService.RenderStepped:Connect(function()
	if not fpsLabel.Visible then return end
	frames += 1
	local now = os.clock()
	if now - lastT >= 0.5 then
		fpsLabel.Text = "FPS: " .. math.floor(frames / (now - lastT) + 0.5)
		frames, lastT = 0, now
	end
end)

---------------------------------------------------------------- COMMANDS: movement
add("fly", "fly [speed] - Space/E up, Shift/Q down, or the on-screen ▲ ▼ buttons", function(a)
	if tonumber(a[1]) then flySpeed = tonumber(a[1]) end
	startFlying()
end)
add("unfly", "stop flying", stopFlying)
add({ "speed", "ws" }, "speed <n> - walk speed", function(a)
	local _, hum = getChar()
	if hum then hum.WalkSpeed = tonumber(a[1]) or 50 end
end)
add({ "jumppower", "jp" }, "jumppower <n>", function(a)
	local _, hum = getChar()
	if hum then hum.UseJumpPower = true hum.JumpPower = tonumber(a[1]) or 100 end
end)
add("lockspeed", "lockspeed <n> - keep speed even if game resets it", function(a)
	state.lockspeed = tonumber(a[1]) or 50
end)
add("unlockspeed", "stop lockspeed", function() state.lockspeed = nil end)
add("hipheight", "hipheight <n>", function(a)
	local _, hum = getChar()
	if hum then hum.HipHeight = tonumber(a[1]) or 2 end
end)
add("infjump", "infinite jump on", function() state.infjump = true end)
add("uninfjump", "infinite jump off", function() state.infjump = false end)
add("noclip", "walk through walls", function() state.noclipping = true end)
add({ "clip", "unnoclip" }, "turn noclip off", function() state.noclipping = false end)
add("spin", "spin [speed]", function(a) state.spin = tonumber(a[1]) or 10 end)
add("unspin", "stop spinning", function() state.spin = 0 end)
add("sit", "sit down", function()
	local _, hum = getChar()
	if hum then hum.Sit = true end
end)
add("jump", "jump once", function()
	local _, hum = getChar()
	if hum then hum.Jump = true end
end)
add("trip", "fall over", function()
	local _, hum = getChar()
	if hum then hum:ChangeState(Enum.HumanoidStateType.FallingDown) end
end)
add("getup", "stand back up", function()
	local _, hum = getChar()
	if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
end)
add("autojump", "toggle auto jump", function()
	local _, hum = getChar()
	if hum then hum.AutoJumpEnabled = not hum.AutoJumpEnabled end
end)
add("freeze", "anchor yourself", function()
	local _, _, hrp = getChar()
	if hrp then hrp.Anchored = true end
end)
add({ "unfreeze", "thaw" }, "unanchor yourself", function()
	local _, _, hrp = getChar()
	if hrp then hrp.Anchored = false end
end)

---------------------------------------------------------------- COMMANDS: health
add({ "kill", "reset" }, "die", function()
	local _, hum = getChar()
	if hum then hum.Health = 0 end
end)
add("god", "keep health full", function() state.godding = true end)
add("ungod", "god off", function() state.godding = false end)
add("heal", "refill health", function()
	local _, hum = getChar()
	if hum then hum.Health = hum.MaxHealth end
end)
add("maxhealth", "maxhealth <n>", function(a)
	local _, hum = getChar()
	if hum then hum.MaxHealth = tonumber(a[1]) or 100 end
end)
add("sethealth", "sethealth <n>", function(a)
	local _, hum = getChar()
	if hum then hum.Health = tonumber(a[1]) or hum.MaxHealth end
end)
add("health", "show your health", function()
	local _, hum = getChar()
	if hum then notify("Health: " .. math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)) end
end)
add("hidehealth", "hide health bar above you", function()
	local _, hum = getChar()
	if hum then hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end
end)
add("showhealth", "show health bar when damaged", function()
	local _, hum = getChar()
	if hum then hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged end
end)

---------------------------------------------------------------- COMMANDS: appearance (local only)
local function setInvisible(on)
	local char = getChar()
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" then
			d.Transparency = on and 1 or 0
		end
	end
end
add({ "invisible", "invis" }, "hide your character (only you see it)", function() setInvisible(true) end)
add({ "visible", "vis" }, "show your character", function() setInvisible(false) end)
add("nohats", "remove your accessories (local)", function()
	local char = getChar()
	if not char then return end
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("Accessory") then d:Destroy() end
	end
end)
add("nameoff", "hide your name tag", function()
	local _, hum = getChar()
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end)
add("nameon", "show your name tag", function()
	local _, hum = getChar()
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end
end)

---------------------------------------------------------------- COMMANDS: teleport
add("spawn", "go to a spawn point", function()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then return teleport(d.CFrame + Vector3.new(0, 4, 0)) end
	end
	notify("No SpawnLocation found")
end)
add("savepos", "save your position", function()
	local _, _, hrp = getChar()
	if hrp then savedCF = hrp.CFrame notify("Position saved") end
end)
add("loadpos", "go to saved position", function()
	if savedCF then teleport(savedCF) else notify("Nothing saved") end
end)
add("back", "return to where you were before last teleport", function()
	if lastCF then teleport(lastCF) else notify("No previous position") end
end)
add("up", "up <studs>", function(a)
	local _, _, hrp = getChar()
	if hrp then hrp.CFrame += Vector3.new(0, tonumber(a[1]) or 20, 0) end
end)
add("down", "down <studs>", function(a)
	local _, _, hrp = getChar()
	if hrp then hrp.CFrame -= Vector3.new(0, tonumber(a[1]) or 20, 0) end
end)
add("forward", "forward <studs>", function(a)
	local _, _, hrp = getChar()
	if hrp then hrp.CFrame *= CFrame.new(0, 0, -(tonumber(a[1]) or 20)) end
end)
add("face", "face <player>", function(a)
	local _, _, hrp = getChar()
	local _, thrp = targetHrp(a[1])
	if hrp and thrp then
		hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(thrp.Position.X, hrp.Position.Y, thrp.Position.Z))
	end
end)

---------------------------------------------------------------- freecam
local fcOn = false
local fcYaw, fcPitch, fcPos = 0, 0, Vector3.zero
local fcSpeed = 50
local fcUp, fcDown = false, false
local fcConns = {}
local fcWasAnchored = false
local fcLookTouches = {}

local fcUpBtn = makeFlyButton("▲", -30, function(v) fcUp = v end)
local fcDownBtn = makeFlyButton("▼", 30, function(v) fcDown = v end)

local function stopFreecam()
	if not fcOn then return end
	fcOn = false
	fcUp, fcDown = false, false
	fcUpBtn.Visible = false
	fcDownBtn.Visible = false
	RunService:UnbindFromRenderStep("CmdFreecam")
	for _, c in ipairs(fcConns) do c:Disconnect() end
	table.clear(fcConns)
	UIS.MouseBehavior = Enum.MouseBehavior.Default

	local _, hum, hrp = getChar()
	if hrp then hrp.Anchored = fcWasAnchored end
	local c = workspace.CurrentCamera
	c.CameraType = Enum.CameraType.Custom
	if hum then c.CameraSubject = hum end
end

local function startFreecam()
	stopFlying()
	if fcOn then return end
	local c = workspace.CurrentCamera
	local _, _, hrp = getChar()

	fcOn = true
	fcWasAnchored = hrp and hrp.Anchored or false
	if hrp then hrp.Anchored = true end -- your character stays put while you look around

	local cf = c.CFrame
	fcPos = cf.Position
	fcPitch, fcYaw = cf:ToOrientation()
	c.CameraType = Enum.CameraType.Scriptable
	fcUpBtn.Visible = true
	fcDownBtn.Visible = true

	-- look: hold right mouse + move (PC), or drag your finger on the screen (mobile)
	table.clear(fcLookTouches)
	table.insert(fcConns, UIS.InputBegan:Connect(function(input, gpe)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.Touch then
			-- only touches that start on the right side of the screen look around
			-- (the left side is the move stick, which used to tilt the camera up)
			if not gpe and input.Position.X > workspace.CurrentCamera.ViewportSize.X * 0.4 then
				fcLookTouches[input] = true
			end
		end
	end))
	table.insert(fcConns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.UserInputType == Enum.UserInputType.Touch then
			fcLookTouches[input] = nil
		end
	end))
	table.insert(fcConns, UIS.InputChanged:Connect(function(input, gpe)
		local look = false
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			look = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			look = fcLookTouches[input] == true
		end
		if look then
			fcYaw -= math.rad(input.Delta.X * 0.3)
			fcPitch = math.clamp(fcPitch - math.rad(input.Delta.Y * 0.3), -1.5, 1.5)
		end
	end))

	RunService:BindToRenderStep("CmdFreecam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not fcOn then return end
		local _, hum = getChar()
		local rot = CFrame.fromOrientation(fcPitch, fcYaw, 0)

		-- WASD / thumbstick -> level movement (never changes height; use Space/E and Shift/Q or the buttons for that)
		local dir = hum and hum.MoveDirection or Vector3.zero

		local typing = UIS:GetFocusedTextBox() ~= nil
		local goUp = fcUp or (not typing and (UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E)))
		local goDown = fcDown or (not typing and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.Q)))
		local vert = (goUp and 1 or 0) - (goDown and 1 or 0)
		local boost = (not typing and UIS:IsKeyDown(Enum.KeyCode.LeftControl)) and 3 or 1

		fcPos += (dir + Vector3.new(0, vert, 0)) * fcSpeed * boost * dt
		workspace.CurrentCamera.CFrame = CFrame.new(fcPos) * rot
	end)
end

add({ "freecam", "fc" }, "freecam [speed] - WASD/stick move, right-click or drag to look, Space/E up, Shift/Q down, Ctrl faster", function(a)
	if tonumber(a[1]) then fcSpeed = tonumber(a[1]) end
	startFreecam()
end)
add({ "unfreecam", "unfc" }, "leave freecam", stopFreecam)

---------------------------------------------------------------- ESP / tracers / aimbot
local espOn, tracersOn = false, false
local teamCheck = false
local espObjects = {}   -- [Player] = { hl, bb, label }
local tracerLines = {}  -- [Player] = Frame

local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = screenGui

local function sameTeam(p)
	return teamCheck and p.Team ~= nil and p.Team == player.Team
end

local function clearEsp(p)
	local o = espObjects[p]
	if not o then return end
	if o.hl then o.hl:Destroy() end
	if o.bb then o.bb:Destroy() end
	espObjects[p] = nil
end

local function buildEsp(p)
	clearEsp(p)
	local char = p.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end

	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.FillColor = Color3.fromRGB(227, 66, 52)
	hl.FillTransparency = 0.6
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = espFolder

	local bb = Instance.new("BillboardGui")
	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(150, 36)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.Parent = espFolder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.Text = ""
	label.Parent = bb

	espObjects[p] = { hl = hl, bb = bb, label = label }
end

local function clearAllEsp()
	for p in pairs(espObjects) do clearEsp(p) end
end

-- keep ESP up to date (also rebuilds after respawns)
local espClock = 0
RunService.Heartbeat:Connect(function(dt)
	espClock += dt
	if espClock < 0.2 then return end
	espClock = 0
	if not espOn then return end

	local _, _, myHrp = getChar()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local char = p.Character
			local o = espObjects[p]
			if char and char:FindFirstChild("Head") then
				if not o or o.hl.Adornee ~= char then
					buildEsp(p)
					o = espObjects[p]
				end
				if o then
					local hide = sameTeam(p)
					o.hl.Enabled = not hide
					o.bb.Enabled = not hide
					local hum = char:FindFirstChildOfClass("Humanoid")
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local dist = (myHrp and hrp) and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
					o.label.Text = ("%s\n[%d studs] [%d HP]"):format(p.DisplayName, dist, hum and math.floor(hum.Health) or 0)
				end
			elseif o then
				clearEsp(p)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	clearEsp(p)
	local line = tracerLines[p]
	if line then line:Destroy() tracerLines[p] = nil end
end)

-- tracers: a line from the bottom-center of the screen to each player
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local vp = camera.ViewportSize
	local from = Vector2.new(vp.X / 2, vp.Y)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local line = tracerLines[p]
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if tracersOn and hrp and not sameTeam(p) then
				local sp = camera:WorldToViewportPoint(hrp.Position)
				if sp.Z > 0 then
					if not line then
						line = Instance.new("Frame")
						line.AnchorPoint = Vector2.new(0.5, 0.5)
						line.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
						line.BorderSizePixel = 0
						line.Parent = screenGui
						tracerLines[p] = line
					end
					local to = Vector2.new(sp.X, sp.Y)
					local delta = to - from
					line.Visible = true
					line.Size = UDim2.fromOffset(delta.Magnitude / mainScale.Scale, 2 / mainScale.Scale)
					line.Position = UDim2.fromOffset((from.X + to.X) / 2 / mainScale.Scale, (from.Y + to.Y) / 2 / mainScale.Scale)
					line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				elseif line then
					line.Visible = false
				end
			elseif line then
				line.Visible = false
			end
		end
	end
end)

-- aimbot: hold right mouse (PC) or hold the AIM button (mobile)
local aim = { on = false, fov = 150, smooth = 0.3, part = "Head", wall = true, held = false }

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(aim.fov * 2 / mainScale.Scale, aim.fov * 2 / mainScale.Scale)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = screenGui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.new(1, 1, 1)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.3
fovStroke.Parent = fovCircle
glow(fovStroke)

-- settings button (shows once you run "aimbot") + panel with ON/OFF and circle size
local CYAN_LIGHT = Color3.fromRGB(20, 20, 23)
local TEAL_TEXT = Color3.fromRGB(237, 237, 240)
local TEAL_LINE = Color3.fromRGB(227, 66, 52)

local function styleBox(inst, radius)
	Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius or 6)
	local s = Instance.new("UIStroke")
	s.Color = TEAL_LINE
	s.Thickness = 2
	s.Parent = inst
	glow(s)
end

local aimGear = Instance.new("TextButton")
aimGear.AnchorPoint = Vector2.new(1, 0.5)
aimGear.Position = UDim2.new(1, -14, 0.5, 90)
aimGear.Size = UDim2.fromOffset(52, 52)
aimGear.BackgroundColor3 = CYAN_LIGHT
aimGear.TextColor3 = TEAL_TEXT
aimGear.Font = Enum.Font.GothamBlack
aimGear.TextSize = 16
aimGear.Text = "AIM"
aimGear.Visible = false
aimGear.Parent = screenGui
styleBox(aimGear, 8)

local aimPanel = Instance.new("Frame")
aimPanel.AnchorPoint = Vector2.new(1, 0.5)
aimPanel.Position = UDim2.new(1, -74, 0.5, 90)
aimPanel.Size = UDim2.fromOffset(176, 0)
aimPanel.AutomaticSize = Enum.AutomaticSize.Y
aimPanel.BackgroundColor3 = CYAN_LIGHT
aimPanel.Visible = false
aimPanel.Parent = screenGui
styleBox(aimPanel, 8)
local aimPad = Instance.new("UIPadding")
aimPad.PaddingLeft = UDim.new(0, 8)
aimPad.PaddingRight = UDim.new(0, 8)
aimPad.PaddingTop = UDim.new(0, 8)
aimPad.PaddingBottom = UDim.new(0, 8)
aimPad.Parent = aimPanel
local aimLayout = Instance.new("UIListLayout")
aimLayout.SortOrder = Enum.SortOrder.LayoutOrder
aimLayout.Padding = UDim.new(0, 6)
aimLayout.Parent = aimPanel

local aimTitle = Instance.new("TextLabel")
aimTitle.LayoutOrder = 1
aimTitle.Size = UDim2.new(1, 0, 0, 18)
aimTitle.BackgroundTransparency = 1
aimTitle.Font = Enum.Font.GothamBlack
aimTitle.TextSize = 14
aimTitle.TextColor3 = TEAL_TEXT
aimTitle.Text = "AIMBOT SETTINGS"
aimTitle.Parent = aimPanel

local aimToggle = Instance.new("TextButton")
aimToggle.LayoutOrder = 2
aimToggle.Size = UDim2.new(1, 0, 0, 34)
aimToggle.Font = Enum.Font.GothamBlack
aimToggle.TextSize = 14
aimToggle.TextColor3 = TEAL_TEXT
aimToggle.Parent = aimPanel
styleBox(aimToggle, 6)

local aimSizeRow = Instance.new("Frame")
aimSizeRow.LayoutOrder = 3
aimSizeRow.Size = UDim2.new(1, 0, 0, 34)
aimSizeRow.BackgroundTransparency = 1
aimSizeRow.Parent = aimPanel

local function sizeButton(text, anchorX)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(anchorX, 0)
	b.Position = UDim2.fromScale(anchorX, 0)
	b.Size = UDim2.new(0, 44, 1, 0)
	b.BackgroundColor3 = CYAN_LIGHT
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 20
	b.TextColor3 = TEAL_TEXT
	b.Text = text
	b.Parent = aimSizeRow
	styleBox(b, 6)
	return b
end
local aimMinus = sizeButton("-", 0)
local aimPlus = sizeButton("+", 1)

local aimSizeLabel = Instance.new("TextLabel")
aimSizeLabel.AnchorPoint = Vector2.new(0.5, 0)
aimSizeLabel.Position = UDim2.fromScale(0.5, 0)
aimSizeLabel.Size = UDim2.new(1, -96, 1, 0)
aimSizeLabel.BackgroundTransparency = 1
aimSizeLabel.Font = Enum.Font.GothamBold
aimSizeLabel.TextSize = 13
aimSizeLabel.TextColor3 = TEAL_TEXT
aimSizeLabel.Parent = aimSizeRow

local function refreshAimUI()
	aimToggle.Text = aim.on and "AIMBOT: ON" or "AIMBOT: OFF"
	aimToggle.BackgroundColor3 = aim.on and Color3.fromRGB(227, 66, 52) or Color3.fromRGB(52, 52, 58)
	aimSizeLabel.Text = "Box: " .. aim.fov
	fovCircle.Size = UDim2.fromOffset(aim.fov * 2 / mainScale.Scale, aim.fov * 2 / mainScale.Scale)
	fovCircle.Visible = aim.on and aimGear.Visible
end

local function setAimFov(n)
	aim.fov = math.clamp(math.floor(n), 20, 800)
	refreshAimUI()
end

-- drag the AIM button anywhere; the settings panel follows it.
-- a short tap still opens/closes the panel, a drag (> 6px) just moves it.
local aimMoved = false
do
	local PANEL_GAP = 60 -- panel sits this many px left of the button
	local dragging, dragStart, startPos = false, nil, nil

	local function placePanel()
		local p = aimGear.Position
		aimPanel.Position = UDim2.new(p.X.Scale, p.X.Offset - PANEL_GAP, p.Y.Scale, p.Y.Offset)
	end

	aimGear.InputBegan:Connect(function(input)
		if dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		aimMoved = false
		dragStart = input.Position
		startPos = aimGear.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local d = input.Position - dragStart
		if not aimMoved and d.Magnitude < 6 then return end
		aimMoved = true

		-- keep the button on screen
		local vp = workspace.CurrentCamera.ViewportSize
		local k = mainScale.Scale
		local x = startPos.X.Offset + d.X / k
		local y = startPos.Y.Offset + d.Y / k
		local absX = startPos.X.Scale * vp.X + x * k   -- right edge (AnchorPoint x = 1)
		local absY = startPos.Y.Scale * vp.Y + y * k   -- vertical center
		x += (math.clamp(absX, 52 * k, vp.X) - absX) / k
		y += (math.clamp(absY, 26 * k, vp.Y - 26 * k) - absY) / k

		aimGear.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
		placePanel()
	end)
end

aimGear.Activated:Connect(function()
	if aimMoved then aimMoved = false return end -- it was a drag, not a tap
	aimPanel.Visible = not aimPanel.Visible
end)
aimToggle.Activated:Connect(function()
	aim.on = not aim.on
	refreshAimUI()
end)
aimMinus.Activated:Connect(function() setAimFov(aim.fov - 25) end)
aimPlus.Activated:Connect(function() setAimFov(aim.fov + 25) end)
refreshAimUI()

local function getAimTarget()
	local camera = workspace.CurrentCamera
	local center = camera.ViewportSize / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = player.Character and { player.Character } or {}

	local best, bestDist
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if p ~= player and char and not sameTeam(p) then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local part = char:FindFirstChild(aim.part) or char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				local sp, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if d <= aim.fov and (not bestDist or d < bestDist) then
						local visible = true
						if aim.wall then
							local origin = camera.CFrame.Position
							local hit = workspace:Raycast(origin, part.Position - origin, params)
							visible = hit == nil or hit.Instance:IsDescendantOf(char)
						end
						if visible then best, bestDist = part, d end
					end
				end
			end
		end
	end
	return best
end

RunService:BindToRenderStep("CmdAimbot", Enum.RenderPriority.Camera.Value + 2, function()
	if not aim.on or fcOn then return end
	local target = getAimTarget()
	if not target then return end
	local camera = workspace.CurrentCamera
	local cf = camera.CFrame
	camera.CFrame = cf:Lerp(CFrame.lookAt(cf.Position, target.Position), aim.smooth)
end)

add("esp", "esp - highlight players through walls with name, distance and health", function()
	espOn = true
end)
add("unesp", "turn ESP off", function()
	espOn = false
	clearAllEsp()
end)
add("tracers", "draw lines from the bottom of the screen to players", function() tracersOn = true end)
add("untracers", "turn tracers off", function()
	tracersOn = false
	for _, line in pairs(tracerLines) do line.Visible = false end
end)
add("aimbot", "aimbot [smooth 0.05-1] - auto-aims, tap the AIM button for settings", function(a)
	if tonumber(a[1]) then aim.smooth = math.clamp(tonumber(a[1]), 0.05, 1) end
	aim.on = true
	aimGear.Visible = true
	refreshAimUI()
end)
add("unaimbot", "turn aimbot off and hide its button", function()
	aim.on = false
	aimGear.Visible = false
	aimPanel.Visible = false
	refreshAimUI()
end)
add("aimfov", "aimfov <pixels> - size of the aim box", function(a)
	setAimFov(tonumber(a[1]) or 150)
end)
add("aimsmooth", "aimsmooth <0.05-1> - lower is smoother, 1 is instant", function(a)
	aim.smooth = math.clamp(tonumber(a[1]) or 0.3, 0.05, 1)
end)
add("aimpart", "aimpart <head|torso>", function(a)
	local v = (a[1] or "head"):lower()
	aim.part = (v == "torso" or v == "body") and "HumanoidRootPart" or "Head"
	notify("Aiming at " .. (aim.part == "Head" and "head" or "torso"))
end)
add("wallcheck", "toggle: aimbot ignores players behind walls", function()
	aim.wall = not aim.wall
	notify("Wallcheck " .. (aim.wall and "on" or "off"))
end)
add("teamcheck", "toggle: ESP, tracers and aimbot skip your teammates", function()
	teamCheck = not teamCheck
	notify("Teamcheck " .. (teamCheck and "on" or "off"))
end)

local antiAfkOn = false
add("antiafk", "stop the idle kick", function()
	if antiAfkOn then return end
	antiAfkOn = true
	local VirtualUser = game:GetService("VirtualUser")
	player.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
	notify("Anti-AFK on")
end)

---------------------------------------------------------------- ANTI-CHEAT - type "ac"
--[[
	Watches every other player and highlights (red, through walls) anyone who looks like they are cheating.
	Once someone is flagged they STAY highlighted, even after respawning, until they leave the game,
	you run "acclear", or you press CLR on the panel.

	Detects:
	  TRANSPARENT - every part of their character is see-through (invisibility)
	  UNDERGROUND - hiding below the map surface with no floor under them
	  FLY         - hovering in the air with no floor under them
	  SPEED       - moving much faster than a normal walk speed
	  NOCLIP      - moving around inside solid walls
	  TELEPORT    - jumping long distances again and again
	These are heuristics, so a player in a weird spot, or a game with fast vehicles / portals,
	can occasionally be flagged. Tune the numbers in the AC table below.
]]
local AC = {
	interval = 0.5,        -- seconds between scans
	hold = {               -- seconds a behaviour must last before it counts
		TRANSPARENT = 1.5,
		UNDERGROUND = 1.5,
		FLY = 3,
		SPEED = 2,
		NOCLIP = 3,
		TELEPORT = 0,
	},
	buryDepth = 6,         -- studs below the surface above them to count as underground
	maxSpeed = 45,         -- studs/second on flat ground (normal walk speed is 16)
	teleportDist = 120,    -- studs moved in a single scan to count as one teleport
	teleportCount = 3,     -- this many teleports...
	teleportWindow = 20,   -- ...within this many seconds = TELEPORT
}

local acAlive = false
local acData = {} -- [Player] = { since, order, flagged, tps, last, hl, bb, label }
local acGui, acList, acConn

local function acRayParams()
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then ignore[#ignore + 1] = p.Character end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params, ignore
end

-- returns a set of the suspicious things this player is doing right now
local function acCheck(plr, data, now, params, ignore)
	local reasons = {}
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		data.last = nil
		return reasons
	end

	-- how far did they move since the last scan?
	local pos = root.Position
	local last = data.last
	data.last = { char = char, pos = pos, t = now }
	local speed = 0
	if last and last.char == char and now > last.t then
		local delta = pos - last.pos
		speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / (now - last.t)
		if delta.Magnitude >= AC.teleportDist then
			table.insert(data.tps, now)
		end
	end
	while data.tps[1] and now - data.tps[1] > AC.teleportWindow do
		table.remove(data.tps, 1)
	end
	if #data.tps >= AC.teleportCount then reasons.TELEPORT = true end

	-- fully transparent character
	local parts, visible = 0, false
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			parts += 1
			if d.Transparency < 0.9 then visible = true break end
		end
	end
	if parts > 0 and not visible then reasons.TRANSPARENT = true end

	-- skip the rest while seated / climbing / swimming (vehicles, ladders, water)
	if hum.Sit then return reasons end
	local okState, st = pcall(function() return hum:GetState() end)
	if okState and (st == Enum.HumanoidStateType.Climbing or st == Enum.HumanoidStateType.Swimming) then
		return reasons
	end

	-- no floor under them: underground or flying
	local floorBelow = workspace:Raycast(pos, Vector3.new(0, -12, 0), params)
	if not floorBelow and math.abs(root.AssemblyLinearVelocity.Y) < 3 then
		local surface = workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
		if surface and surface.Position.Y > pos.Y + AC.buryDepth then
			reasons.UNDERGROUND = true
		else
			reasons.FLY = true
		end
	end

	-- too fast
	if speed > AC.maxSpeed then reasons.SPEED = true end

	-- moving while inside solid, anchored walls
	if speed > 4 then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = ignore
		local hits = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(1.4, 1.4, 1), overlap)
		for _, h in ipairs(hits) do
			if h.CanCollide and h.Anchored and not h:IsA("Terrain") then
				reasons.NOCLIP = true
				break
			end
		end
	end

	return reasons
end

local function acUnmark(data)
	if data.hl then data.hl:Destroy() end
	if data.bb then data.bb:Destroy() end
	data.hl, data.bb, data.label = nil, nil, nil
end

local function acRefreshList()
	if not acList then return end
	local lines = {}
	for plr, data in pairs(acData) do
		if #data.order > 0 then
			table.insert(lines, plr.DisplayName .. " - " .. table.concat(data.order, ", "))
		end
	end
	table.sort(lines)
	acList.Text = #lines > 0 and table.concat(lines, "\n") or "No cheaters detected"
end

-- put (or refresh) the highlight; it is rebuilt automatically after they respawn
local function acMark(plr, data)
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local text = ("%s - CHEATING (%s)"):format(plr.DisplayName, table.concat(data.order, ", "))

	if data.hl and data.hl.Parent and data.hl.Adornee == char and data.label then
		data.label.Text = text
		return
	end
	acUnmark(data)

	local hl = Instance.new("Highlight")
	hl.Name = "CheaterHighlight"
	hl.Adornee = char
	hl.FillColor = Color3.fromRGB(227, 66, 52)
	hl.OutlineColor = Color3.fromRGB(255, 255, 85)
	hl.FillTransparency = 0.35
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = char

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 30)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	bb.Parent = acGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(240, 110, 95)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = bb

	data.hl, data.bb, data.label = hl, bb, label
end

local function acScan()
	local now = os.clock()
	local params, ignore = acRayParams()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local data = acData[plr]
			if not data then
				data = { since = {}, order = {}, flagged = {}, tps = {} }
				acData[plr] = data
			end

			local reasons = acCheck(plr, data, now, params, ignore)
			for reason in pairs(reasons) do
				data.since[reason] = data.since[reason] or now
				if not data.flagged[reason] and now - data.since[reason] >= (AC.hold[reason] or 0) then
					data.flagged[reason] = true
					table.insert(data.order, reason)
					pcall(function()
						StarterGui:SetCore("SendNotification", {
							Title = "Anti-cheat",
							Text = plr.DisplayName .. " flagged: " .. reason,
							Duration = 5,
						})
					end)
				end
			end
			for reason in pairs(data.since) do
				if not reasons[reason] then data.since[reason] = nil end
			end

			-- flagged players stay highlighted
			if #data.order > 0 then acMark(plr, data) end
		end
	end
	acRefreshList()
end

local function acClear()
	for _, data in pairs(acData) do
		acUnmark(data)
		data.order, data.flagged, data.since, data.tps = {}, {}, {}, {}
	end
	acRefreshList()
end

local function stopAC()
	if not acAlive then return end
	acAlive = false
	if acConn then acConn:Disconnect() acConn = nil end
	for _, data in pairs(acData) do acUnmark(data) end
	acData = {}
	if acGui then acGui:Destroy() acGui = nil end
	acList = nil
end

local function startAC()
	if acAlive then return end
	acAlive = true

	local oldAc = playerGui:FindFirstChild("InvisDetector")
	if oldAc then oldAc:Destroy() end

	acGui = Instance.new("ScreenGui")
	acGui.Name = "InvisDetector"
	acGui.ResetOnSpawn = false
	acGui.DisplayOrder = 98
	acGui.Parent = playerGui

	-- movable status panel
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(240, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Position = UDim2.new(0, 10, 0.5, -60)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
	panel.BorderSizePixel = 0
	panel.Parent = acGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
	do -- pop in
		local sc = Instance.new("UIScale")
		sc.Scale = 0.5
		sc.Parent = panel
		tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(227, 66, 52)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel
	glow(panelStroke)
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Parent = panel

	local titleBar = Instance.new("Frame")
	titleBar.LayoutOrder = 1
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel
	Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -84, 1, 0)
	title.Position = UDim2.fromOffset(10, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(237, 237, 240)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ANTI-CHEAT (drag)"
	title.Parent = titleBar

	local function titleButton(text, offsetX, width)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, offsetX, 0.5, 0)
		b.Size = UDim2.fromOffset(width, 26)
		b.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
		b.Font = Enum.Font.GothamBlack
		b.TextSize = 12
		b.TextColor3 = Color3.fromRGB(237, 237, 240)
		b.Text = text
		b.Parent = titleBar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
		return b
	end
	titleButton("X", -4, 26).Activated:Connect(stopAC)
	titleButton("CLR", -34, 38).Activated:Connect(acClear)

	acList = Instance.new("TextLabel")
	acList.LayoutOrder = 2
	acList.Size = UDim2.new(1, 0, 0, 0)
	acList.AutomaticSize = Enum.AutomaticSize.Y
	acList.BackgroundTransparency = 1
	acList.Font = Enum.Font.GothamBold
	acList.TextSize = 13
	acList.TextColor3 = Color3.fromRGB(237, 237, 240)
	acList.TextXAlignment = Enum.TextXAlignment.Left
	acList.TextYAlignment = Enum.TextYAlignment.Top
	acList.TextWrapped = true
	acList.Text = "No cheaters detected"
	acList.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = acList

	-- drag by the title bar (mouse + touch)
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = panel.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if not acAlive or not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			panel.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)

	acConn = Players.PlayerRemoving:Connect(function(plr)
		local data = acData[plr]
		if data then acUnmark(data) end
		acData[plr] = nil
	end)

	task.spawn(function()
		while acAlive do
			pcall(acScan)
			task.wait(AC.interval)
		end
	end)
end

add({ "ac", "anticheat" }, "toggle the anti-cheat (flags invis/fly/speed/noclip/teleport, movable panel)", function()
	if acAlive then
		stopAC()
		notify("Anti-cheat off")
	else
		startAC()
		notify("Anti-cheat on")
	end
end)
add("unac", "turn the anti-cheat off", function()
	stopAC()
end)
add("acclear", "clear everyone the anti-cheat has flagged", function()
	acClear()
	notify("Anti-cheat list cleared")
end)

---------------------------------------------------------------- COMMANDS: camera
local function cam() return workspace.CurrentCamera end
add("fov", "fov <1-120>", function(a)
	cam().FieldOfView = math.clamp(tonumber(a[1]) or 70, 1, 120)
end)
add("zoom", "zoom <max distance>", function(a)
	player.CameraMaxZoomDistance = tonumber(a[1]) or 128
end)
add("minzoom", "minzoom <distance>", function(a)
	player.CameraMinZoomDistance = tonumber(a[1]) or 0.5
end)
add({ "spectate", "view" }, "spectate <player>", function(a)
	local t = findPlayer(a[1])
	local hum = t and t.Character and t.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam().CameraSubject = hum else notify("Player not found") end
end)
add("unspectate", "go back to your camera", function()
	local _, hum = getChar()
	if hum then cam().CameraSubject = hum end
end)
add("fixcam", "reset camera", function()
	local _, hum = getChar()
	cam().CameraType = Enum.CameraType.Custom
	if hum then cam().CameraSubject = hum end
	cam().FieldOfView = 70
end)

---------------------------------------------------------------- COMMANDS: world / lighting (local only)
local fbOrig
add("time", "time <0-24>", function(a) Lighting.ClockTime = tonumber(a[1]) or 14 end)
add("day", "set daytime", function() Lighting.ClockTime = 14 end)
add("night", "set nighttime", function() Lighting.ClockTime = 0 end)
add("brightness", "brightness <n>", function(a) Lighting.Brightness = tonumber(a[1]) or 2 end)
add("fullbright", "light everything up", function()
	if not fbOrig then
		fbOrig = {
			Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd,
			Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient,
		}
	end
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 1e6
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.new(1, 1, 1)
	Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
end)
add("unfullbright", "undo fullbright", function()
	if not fbOrig then return end
	Lighting.Brightness, Lighting.ClockTime, Lighting.FogEnd = fbOrig[1], fbOrig[2], fbOrig[3]
	Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient = fbOrig[4], fbOrig[5], fbOrig[6]
	fbOrig = nil
end)
add("fog", "fog <end distance>", function(a) Lighting.FogEnd = tonumber(a[1]) or 200 end)
add("nofog", "remove fog", function()
	Lighting.FogEnd = 1e6
	for _, v in ipairs(Lighting:GetChildren()) do
		if v:IsA("Atmosphere") then v.Density = 0 end
	end
end)
add("shadows", "toggle shadows", function() Lighting.GlobalShadows = not Lighting.GlobalShadows end)
add("ambient", "ambient <r> <g> <b> (0-255)", function(a)
	Lighting.Ambient = Color3.fromRGB(tonumber(a[1]) or 128, tonumber(a[2]) or 128, tonumber(a[3]) or 128)
end)
add("gravity", "gravity <n> (default 196.2)", function(a)
	workspace.Gravity = tonumber(a[1]) or 196.2
end)

---------------------------------------------------------------- COMMANDS: interface
local function coreToggle(coreType)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreType, not StarterGui:GetCoreGuiEnabled(coreType))
	end)
end
add("hidegui", "hide Roblox UI", function()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
end)
add("showgui", "show Roblox UI", function()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
end)
add("chat", "toggle chat window", function() coreToggle(Enum.CoreGuiType.Chat) end)
add("playerlist", "toggle player list", function() coreToggle(Enum.CoreGuiType.PlayerList) end)
add("glow", "toggle the animated red glow outline", function()
	glowEnabled = not glowEnabled
	notify("Glow " .. (glowEnabled and "on" or "off"))
end)
add("fps", "toggle FPS counter", function() fpsLabel.Visible = not fpsLabel.Visible end)
add({ "cmds", "help" }, "show this list", function()
	if not helpPanel.Visible then
		local lines = {}
		for _, name in ipairs(COMMAND_LIST) do
			table.insert(lines, name .. " - " .. (descriptions[name] or ""))
		end
		helpText.Text = table.concat(lines, "\n")
	end
	if helpPanel.Visible then
		tween(helpPanel, 0.2, { Size = UDim2.new(0, 300, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(0.2, function()
			if helpPanel.Size.Y.Offset == 0 then helpPanel.Visible = false end
		end)
	else
		helpPanel.Size = UDim2.new(0, 300, 0, 0)
		helpPanel.Visible = true
		tween(helpPanel, 0.35, { Size = UDim2.new(0, 300, 0, 280) }, Enum.EasingStyle.Back)
	end
end)

---------------------------------------------------------------- COMMANDS: info / misc
add("notify", "notify <text>", function(a) notify(table.concat(a, " ")) end)
add("say", "say <text> - send a chat message", function(a)
	local text = table.concat(a, " ")
	local channels = TextChatService:FindFirstChild("TextChannels")
	local ch = channels and channels:FindFirstChild("RBXGeneral")
	if ch and text ~= "" then ch:SendAsync(text) end
end)
add("players", "list players in the server", function()
	local names = {}
	for _, p in ipairs(Players:GetPlayers()) do table.insert(names, p.Name) end
	notify(#names .. ": " .. table.concat(names, ", "))
end)
add("userid", "userid <player>", function(a)
	local t = findPlayer(a[1]) or player
	notify(t.Name .. ": " .. t.UserId)
end)
add("distance", "distance <player>", function(a)
	local _, _, hrp = getChar()
	local t, thrp = targetHrp(a[1])
	if hrp and thrp then notify(t.Name .. ": " .. math.floor((hrp.Position - thrp.Position).Magnitude) .. " studs") end
end)
add("pos", "show your position", function()
	local _, _, hrp = getChar()
	if hrp then
		local p = hrp.Position
		notify(("%d, %d, %d"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
	end
end)
add("rejoin", "rejoin this server", function()
	TeleportService:Teleport(game.PlaceId, player)
end)

---------------------------------------------------------------- COMMANDS: more
add("ping", "show your ping", function()
	local ok, ms = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	notify(ok and ("Ping: " .. math.floor(ms) .. " ms") or "Ping unavailable")
end)

add("serverinfo", "players, place id and job id", function()
	local job = game.JobId ~= "" and game.JobId or "studio"
	notify(("%d/%d players | PlaceId %d | %s"):format(#Players:GetPlayers(), Players.MaxPlayers, game.PlaceId, job))
end)

add("light", "light [range] - glow around you", function(a)
	local _, _, hrp = getChar()
	if not hrp then return end
	local l = hrp:FindFirstChild("CmdLight") or Instance.new("PointLight")
	l.Name = "CmdLight"
	l.Range = tonumber(a[1]) or 30
	l.Brightness = 2
	l.Parent = hrp
end)
add("unlight", "remove your light", function()
	local _, _, hrp = getChar()
	local l = hrp and hrp:FindFirstChild("CmdLight")
	if l then l:Destroy() end
end)

local bhopOn = false
RunService.Heartbeat:Connect(function()
	if not bhopOn then return end
	local _, hum = getChar()
	if hum and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0 then
		hum.Jump = true
	end
end)
add("bhop", "keep jumping automatically while you move", function() bhopOn = true end)
add("unbhop", "turn bhop off", function() bhopOn = false end)

local function setXray(amount)
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(chars, p.Character) end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("Terrain") then
			local isChar = false
			for _, c in ipairs(chars) do
				if d:IsDescendantOf(c) then isChar = true break end
			end
			if not isChar then d.LocalTransparencyModifier = amount end
		end
	end
end
add("xray", "see through the map (only you)", function() setXray(0.6) end)
add("unxray", "turn xray off", function() setXray(0) end)

add("boost", "lower graphics to raise FPS", function()
	Lighting.GlobalShadows = false
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke")
			or d:IsA("Fire") or d:IsA("Sparkles") then
			d.Enabled = false
		end
	end
	notify("Graphics lowered")
end)

local followTarget
add("follow", "follow <player> - walks after them", function(a)
	local t = findPlayer(a[1])
	if not t then return notify("Player not found") end
	followTarget = t
	task.spawn(function()
		while followTarget == t do
			local _, hum = getChar()
			local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
			if hum and thrp then hum:MoveTo(thrp.Position) end
			task.wait(0.25)
		end
	end)
end)
add("unfollow", "stop following", function() followTarget = nil end)

add("hidenames", "hide other players' name tags", function()
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p ~= player and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	end
end)
add("shownames", "show other players' name tags again", function()
	for _, p in ipairs(Players:GetPlayers()) do
		local hum = p ~= player and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end
	end
end)

local crosshair
add("crosshair", "show a red dot in the middle of the screen", function()
	if crosshair then return end
	crosshair = Instance.new("Frame")
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(6, 6)
	crosshair.BackgroundColor3 = Color3.fromRGB(227, 66, 52)
	crosshair.BorderSizePixel = 0
	Instance.new("UICorner", crosshair).CornerRadius = UDim.new(1, 0)
	crosshair.Parent = screenGui
end)
add("uncrosshair", "remove the crosshair", function()
	if crosshair then crosshair:Destroy() crosshair = nil end
end)

---------------------------------------------------------------- run
table.sort(COMMAND_LIST)

local function executeCommand(fullText, fromChat)
	suggestionsFrame.Visible = false
	fullText = fullText:gsub("^%s+", ""):gsub("%s+$", "")
	if fullText == "" then return end

	local args = {}
	for w in fullText:gmatch("%S+") do table.insert(args, w) end

	local name = table.remove(args, 1):lower():gsub("^[;:/]", "")
	local fn = commands[name]
	if fn then
		local ok, err = pcall(fn, args)
		if not ok then notify("Error: " .. tostring(err)) warn("[CommandBar]", err) end
	else
		notify("Unknown command: " .. name)
	end
	pulse(outerFrame, 0.05)
	if not fromChat then cmdBar.Text = "" end
end

cmdBar.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		executeCommand(cmdBar.Text)
	else
		task.delay(0.15, function() suggestionsFrame.Visible = false end)
	end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.Semicolon then
		task.defer(function()
			cmdBar:CaptureFocus()
			cmdBar.Text = ""
		end)
	end
end)

player.CharacterAdded:Connect(stopFlying)
player.CharacterAdded:Connect(stopFreecam)

---------------------------------------------------------------- run commands typed in Roblox chat (;fly, ;speed 50, ...)
local lastChatText, lastChatTime = "", 0

local function handleChat(text)
	if type(text) ~= "string" or text:sub(1, 1) ~= ";" then return end

	-- both listeners below can fire for the same message, so ignore duplicates
	local now = os.clock()
	if text == lastChatText and now - lastChatTime < 0.5 then return end
	lastChatText, lastChatTime = text, now

	local cmd = text:sub(2)
	if cmd:match("^%s*$") then return end
	executeCommand(cmd, true)
end

-- new chat (TextChatService)
pcall(function()
	TextChatService.SendingMessage:Connect(function(msg)
		handleChat(msg.Text)
	end)
end)

-- old chat + backup
player.Chatted:Connect(handleChat)

---------------------------------------------------------------- COMMANDS: hub / theme / utility
do -- scoped so these locals don't count toward Luau's 200-local limit
local GLOW_COLORS = {
	red = Color3.fromRGB(227, 66, 52), crimson = Color3.fromRGB(200, 30, 70),
	orange = Color3.fromRGB(255, 120, 20), purple = Color3.fromRGB(170, 60, 255),
	blue = Color3.fromRGB(50, 120, 255), cyan = Color3.fromRGB(40, 230, 255),
	green = Color3.fromRGB(50, 255, 100), white = Color3.fromRGB(255, 255, 255),
	pink = Color3.fromRGB(255, 70, 170),
}
add("glowcolor", "glowcolor <red|crimson|orange|purple|blue|cyan|green|white|pink> or <r g b>", function(a)
	local c = GLOW_COLORS[(a[1] or ""):lower()]
	if not c and tonumber(a[1]) and tonumber(a[2]) and tonumber(a[3]) then
		c = Color3.fromRGB(math.clamp(tonumber(a[1]), 0, 255), math.clamp(tonumber(a[2]), 0, 255), math.clamp(tonumber(a[3]), 0, 255))
	end
	glowColor = c or GLOW_COLORS.red
	buildGlowSeq()
	notify("Glow color set")
end)
add("glowspeed", "glowspeed <0.5-10> - how fast the glow pulses", function(a)
	glowSpeed = math.clamp(tonumber(a[1]) or 3, 0.5, 10)
end)
add("uiscale", "uiscale <0.5-2> - resize the whole hub", function(a)
	local sc = screenGui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", screenGui)
	sc.Scale = math.clamp(tonumber(a[1]) or UI_SCALE, 0.4, 2)
	notify("UI scale " .. sc.Scale)
end)
add("resetbar", "put the command bar back at the top", function()
	outerFrame.Position = UDim2.new(0.5, 0, 0, 50)
end)

add({ "respawn", "reset" }, "kill your character so you respawn", function()
	local _, hum = getChar()
	if hum then hum.Health = 0 end
end)
add({ "wp", "waypoint" }, "wp set|go|del <name> / wp list - save places and return to them", function(a)
	state.waypoints = state.waypoints or {}
	local act, name = (a[1] or ""):lower(), (a[2] or "default"):lower()
	local _, _, hrp = getChar()
	if act == "set" and hrp then
		state.waypoints[name] = hrp.CFrame
		notify("Saved waypoint " .. name)
	elseif act == "go" then
		if state.waypoints[name] then teleport(state.waypoints[name]) else notify("No waypoint " .. name) end
	elseif act == "del" then
		state.waypoints[name] = nil
		notify("Deleted " .. name)
	else
		local names = {}
		for n in pairs(state.waypoints) do table.insert(names, n) end
		notify(#names > 0 and ("Waypoints: " .. table.concat(names, ", ")) or "No waypoints saved")
	end
end)
add("clock", "show the current time", function()
	notify(os.date("%I:%M:%S %p"))
end)
local stopwatchStart
add("timer", "timer start|stop - simple stopwatch", function(a)
	if (a[1] or "start"):lower() == "stop" then
		notify(stopwatchStart and string.format("Elapsed: %.1fs", os.clock() - stopwatchStart) or "Timer not running")
		stopwatchStart = nil
	else
		stopwatchStart = os.clock()
		notify("Timer started")
	end
end)
add("firstperson", "lock the camera to first person", function()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end)
add("thirdperson", "go back to third person", function()
	player.CameraMode = Enum.CameraMode.Classic
end)
add("moon", "low gravity", function() workspace.Gravity = 60 end)
add("sunset", "sunset lighting", function() Lighting.ClockTime = 18.2 end)
add("dawn", "dawn lighting", function() Lighting.ClockTime = 5.8 end)

add({ "tp", "tpto", "goto" }, "tp <player> or tp <x> <y> <z> - teleport to a player or coordinates", function(a)
	local _, _, hrp = getChar()
	if not hrp then return end
	if tonumber(a[1]) and tonumber(a[2]) and tonumber(a[3]) then
		teleport(CFrame.new(tonumber(a[1]), tonumber(a[2]), tonumber(a[3])))
		return
	end
	local t, thrp = targetHrp(a[1])
	if thrp then
		teleport(thrp.CFrame * CFrame.new(0, 0, 3))
		notify("Teleported to " .. t.Name)
	else
		notify("Player not found")
	end
end)

-- click / tap teleport: TM turns it on and it STAYS on until UnTM
local function teleportToScreenPoint(pos, isViewport)
	local cam = workspace.CurrentCamera
	local ray = isViewport and cam:ViewportPointToRay(pos.X, pos.Y) or cam:ScreenPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = player.Character and { player.Character } or {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if hit then teleport(CFrame.new(hit.Position + Vector3.new(0, 3, 0))) end
end
local tpMouseOn = false
add({ "tpmouse", "taptp", "tm" }, "tm / tpmouse - click (PC) or tap (mobile) to teleport, stays on until untm", function()
	tpMouseOn = true
	notify("Click-TP ON (untm / untpmouse to stop)")
end)
add({ "untpmouse", "untaptp", "untm" }, "untm / untpmouse - turn click-teleport off", function()
	tpMouseOn = false
	notify("Click-TP OFF")
end)
UIS.TouchTapInWorld:Connect(function(pos, processed)
	if not tpMouseOn or processed then return end
	teleportToScreenPoint(pos)
end)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe or not tpMouseOn then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		teleportToScreenPoint(UIS:GetMouseLocation(), true)
	end
end)

local sprintSpeed, sprintOn, sprintBase = 32, false, nil
add("sprint", "sprint [speed] - hold Left Shift to run faster", function(a)
	sprintSpeed = tonumber(a[1]) or 32
	sprintOn = true
	notify("Hold Shift to sprint")
end)
add("unsprint", "turn sprint off", function() sprintOn = false end)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe or not sprintOn or input.KeyCode ~= Enum.KeyCode.LeftShift then return end
	local _, hum = getChar()
	if hum then sprintBase = hum.WalkSpeed hum.WalkSpeed = sprintSpeed end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.LeftShift or not sprintBase then return end
	local _, hum = getChar()
	if hum then hum.WalkSpeed = sprintBase end
	sprintBase = nil
end)

add("volume", "volume <0-10> - master game volume", function(a)
	game:GetService("SoundService").Volume = math.clamp(tonumber(a[1]) or 1, 0, 10)
end)
add("mute", "mute all game sound", function() game:GetService("SoundService").Volume = 0 end)
add("unmute", "restore game sound", function() game:GetService("SoundService").Volume = 1 end)
add("memory", "show how much memory the game is using", function()
	notify(string.format("Memory: %d MB", game:GetService("Stats"):GetTotalMemoryUsageMb()))
end)
add("fogcolor", "fogcolor <r> <g> <b> (0-255)", function(a)
	Lighting.FogColor = Color3.fromRGB(tonumber(a[1]) or 255, tonumber(a[2]) or 40, tonumber(a[3]) or 40)
end)
add("skyred", "dark red sky and ambience (only you)", function()
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(90, 10, 10)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 10, 10)
	Lighting.FogColor = Color3.fromRGB(60, 0, 0)
end)

local vermilionTint
add("redworld", "tint the whole screen red (only you)", function()
	if not vermilionTint then
		vermilionTint = Instance.new("ColorCorrectionEffect")
		vermilionTint.Name = "VermilionTint"
		vermilionTint.Parent = Lighting
	end
	vermilionTint.TintColor = Color3.fromRGB(255, 150, 150)
	vermilionTint.Saturation = 0.15
	vermilionTint.Contrast = 0.15
end)
add("unredworld", "remove the red tint", function()
	if vermilionTint then vermilionTint:Destroy() vermilionTint = nil end
end)
local bloomFx
add("bloom", "bloom [intensity] - make lights glow", function(a)
	bloomFx = bloomFx or Instance.new("BloomEffect", Lighting)
	bloomFx.Intensity = tonumber(a[1]) or 1.2
	bloomFx.Size = 32
	bloomFx.Threshold = 0.8
end)
add("unbloom", "turn bloom off", function()
	if bloomFx then bloomFx:Destroy() bloomFx = nil end
end)
local blurFx
add("blur", "blur <0-56> - blur the screen", function(a)
	blurFx = blurFx or Instance.new("BlurEffect", Lighting)
	blurFx.Size = math.clamp(tonumber(a[1]) or 12, 0, 56)
end)
add("unblur", "remove blur", function()
	if blurFx then blurFx:Destroy() blurFx = nil end
end)

end

---------------------------------------------------------------- COMMANDS: big pack (v2)
do
local fx = {
	parachute = false, antivoid = false, autowalk = false, regen = 0,
	orbit = nil, headsit = nil, rainbowChar = false, rainbowGlow = false,
	timelapse = nil, floatPart = nil, loopToken = 0,
}
local safeCF
local binds, aliases = {}, {}
local sessionStart = os.clock()

-- per-frame effects
local orbitAngle = 0
RunService.Heartbeat:Connect(function(dt)
	local _, hum, hrp = getChar()
	if not hum or not hrp then return end
	if fx.parachute then
		local v = hrp.AssemblyLinearVelocity
		if v.Y < -14 then hrp.AssemblyLinearVelocity = Vector3.new(v.X, -14, v.Z) end
	end
	if fx.antivoid then
		if safeCF and hrp.Position.Y < workspace.FallenPartsDestroyHeight + 60 then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = safeCF
		elseif hum.FloorMaterial ~= Enum.Material.Air then
			safeCF = hrp.CFrame + Vector3.new(0, 3, 0)
		end
	end
	if fx.autowalk then hum:Move(Vector3.new(0, 0, -1), true) end
	if fx.regen > 0 and hum.Health > 0 and hum.Health < hum.MaxHealth then
		hum.Health = math.min(hum.MaxHealth, hum.Health + fx.regen * dt)
	end
	if fx.orbit then
		local thrp = fx.orbit.player.Character and fx.orbit.player.Character:FindFirstChild("HumanoidRootPart")
		if thrp then
			orbitAngle += dt * fx.orbit.speed
			local c = thrp.Position
			local pos = c + Vector3.new(math.cos(orbitAngle) * fx.orbit.radius, 0, math.sin(orbitAngle) * fx.orbit.radius)
			hrp.CFrame = CFrame.lookAt(pos, c)
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
	if fx.headsit then
		local thrp = fx.headsit.Character and fx.headsit.Character:FindFirstChild("HumanoidRootPart")
		if thrp then
			hrp.CFrame = thrp.CFrame * CFrame.new(0, 2.4, 0)
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
	if fx.floatPart and fx.floatPart.Parent then
		fx.floatPart.Position = Vector3.new(hrp.Position.X, fx.floatY, hrp.Position.Z)
	end
end)

local hue, tickAcc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	hue = (hue + dt * 0.25) % 1
	tickAcc += dt
	if tickAcc < 0.08 then return end
	local step = tickAcc
	tickAcc = 0
	if fx.rainbowGlow then
		glowColor = Color3.fromHSV(hue, 0.85, 1)
		buildGlowSeq()
	end
	if fx.rainbowChar then
		local char = getChar()
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = Color3.fromHSV(hue, 0.8, 1) end
			end
		end
	end
	if fx.timelapse then Lighting.ClockTime = (Lighting.ClockTime + step * fx.timelapse) % 24 end
end)

---- movement / physics
add("dash", "dash [power] - burst forward", function(a)
	local _, _, hrp = getChar()
	if hrp then hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * (tonumber(a[1]) or 120) + Vector3.new(0, 15, 0) end
end)
add("launch", "launch [power] - shoot yourself upward", function(a)
	local _, _, hrp = getChar()
	if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, tonumber(a[1]) or 140, 0) end
end)
add("slam", "slam - smash straight down", function()
	local _, _, hrp = getChar()
	if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, -250, 0) end
end)
add("blink", "blink [studs] - instantly jump forward", function(a)
	local _, _, hrp = getChar()
	if hrp then teleport(hrp.CFrame * CFrame.new(0, 0, -(tonumber(a[1]) or 30))) end
end)
add("flip", "flip upside down once", function()
	local _, _, hrp = getChar()
	if hrp then hrp.CFrame *= CFrame.Angles(math.pi, 0, 0) end
end)
add("autowalk", "keep walking forward", function() fx.autowalk = true end)
add("unautowalk", "stop auto walking", function()
	fx.autowalk = false
	local _, hum = getChar()
	if hum then hum:Move(Vector3.zero, true) end
end)
add("parachute", "slow your falling", function() fx.parachute = true end)
add("unparachute", "normal falling", function() fx.parachute = false end)
add("antivoid", "return you to the last safe ground if you fall off the map", function()
	fx.antivoid = true
	notify("Anti-void on")
end)
add("unantivoid", "turn anti-void off", function() fx.antivoid = false end)
add("regen", "regen <hp per second> - heal over time", function(a) fx.regen = tonumber(a[1]) or 10 end)
add("unregen", "stop regen", function() fx.regen = 0 end)
add("float", "float - invisible platform at your current height", function()
	local _, _, hrp = getChar()
	if not hrp then return end
	if fx.floatPart then fx.floatPart:Destroy() end
	local p = Instance.new("Part")
	p.Name = "CmdFloat"
	p.Anchored = true
	p.Size = Vector3.new(8, 1, 8)
	p.Transparency = 0.8
	p.Material = Enum.Material.Neon
	p.Color = glowColor
	p.Parent = workspace
	fx.floatY = hrp.Position.Y - 3.5
	p.Position = Vector3.new(hrp.Position.X, fx.floatY, hrp.Position.Z)
	fx.floatPart = p
end)
add("unfloat", "remove the float platform", function()
	if fx.floatPart then fx.floatPart:Destroy() fx.floatPart = nil end
end)
add("zerog", "no gravity", function() workspace.Gravity = 0 end)
add("highg", "heavy gravity", function() workspace.Gravity = 400 end)
add("normalg", "normal gravity", function() workspace.Gravity = 196.2 end)
add("defaults", "reset speed, jump, gravity and fov", function()
	local _, hum = getChar()
	if hum then hum.WalkSpeed = 16 hum.UseJumpPower = true hum.JumpPower = 50 end
	state.lockspeed = nil
	workspace.Gravity = 196.2
	workspace.CurrentCamera.FieldOfView = 70
	notify("Defaults restored")
end)

---- teleport / players
add({ "rtp", "randomtp" }, "teleport to a random player", function()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then list[#list + 1] = p end
	end
	if #list == 0 then return notify("No other players") end
	local t = list[math.random(#list)]
	teleport(t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
	notify("Teleported to " .. t.Name)
end)
local function nearestPlayer()
	local _, _, hrp = getChar()
	if not hrp then return end
	local best, bd
	for _, p in ipairs(Players:GetPlayers()) do
		local t = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if t then
			local d = (t.Position - hrp.Position).Magnitude
			if not bd or d < bd then best, bd = p, d end
		end
	end
	return best, bd
end
add("nearest", "show the closest player", function()
	local p, d = nearestPlayer()
	notify(p and (p.Name .. " - " .. math.floor(d) .. " studs") or "No other players")
end)
add("tpnearest", "teleport to the closest player", function()
	local p = nearestPlayer()
	if p then teleport(p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)) else notify("No other players") end
end)
add("orbit", "orbit <player> [radius] [speed] - circle around someone", function(a)
	local t = findPlayer(a[1])
	if not t then return notify("Player not found") end
	fx.headsit = nil
	fx.orbit = { player = t, radius = tonumber(a[2]) or 12, speed = tonumber(a[3]) or 2 }
end)
add("unorbit", "stop orbiting", function() fx.orbit = nil end)
add("headsit", "headsit <player> - ride on someone's head", function(a)
	local t = findPlayer(a[1])
	if not t then return notify("Player not found") end
	fx.orbit = nil
	fx.headsit = t
end)
add("unheadsit", "get off", function() fx.headsit = nil end)
add({ "inspect", "info" }, "inspect <player> - age, team, distance", function(a)
	local t = findPlayer(a[1])
	if not t then return notify("Player not found") end
	local _, _, hrp = getChar()
	local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
	local d = (hrp and thrp) and math.floor((hrp.Position - thrp.Position).Magnitude) or "?"
	notify(("%s | %d days old | team %s | %s studs"):format(t.Name, t.AccountAge, t.Team and t.Team.Name or "none", tostring(d)))
end)
add("teams", "list the teams", function()
	local names = {}
	for _, tm in ipairs(game:GetService("Teams"):GetTeams()) do names[#names + 1] = tm.Name end
	notify(#names > 0 and ("Teams: " .. table.concat(names, ", ")) or "No teams")
end)
add("myteam", "show your team", function()
	notify(player.Team and ("Team: " .. player.Team.Name) or "No team")
end)
add("sessiontime", "how long you've been in this server", function()
	local s = math.floor(workspace.DistributedGameTime)
	notify(("In server: %dm %ds"):format(math.floor(s / 60), s % 60))
end)
add("playercount", "how many players are in the server", function()
	notify(#Players:GetPlayers() .. " / " .. Players.MaxPlayers .. " players")
end)

---- tools / emotes
add("tools", "list the tools in your backpack", function()
	local names = {}
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") then names[#names + 1] = t.Name end
	end
	notify(#names > 0 and table.concat(names, ", ") or "No tools in backpack")
end)
add("equip", "equip <tool name> - equip a tool from your backpack", function(a)
	local _, hum = getChar()
	local q = table.concat(a, " "):lower()
	for _, t in ipairs(player.Backpack:GetChildren()) do
		if t:IsA("Tool") and t.Name:lower():find(q, 1, true) then
			if hum then hum:EquipTool(t) end
			return
		end
	end
	notify("Tool not found")
end)
add("unequip", "put your tool away", function()
	local _, hum = getChar()
	if hum then hum:UnequipTools() end
end)
local function emote(name)
	local _, hum = getChar()
	if not hum then return end
	if not pcall(function() hum:PlayEmote(name) end) then notify("Emote failed") end
end
add("emote", "emote <dance|dance2|dance3|wave|point|laugh|cheer>", function(a) emote(a[1] or "dance") end)
for _, e in ipairs({ "dance", "dance2", "dance3", "wave", "point", "laugh", "cheer" }) do
	add(e, e .. " emote", function() emote(e) end)
end

---- character looks (local only)
local function eachPart(fn)
	local char = getChar()
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then fn(p) end
	end
end
add("neon", "make your character glow neon", function() eachPart(function(p) p.Material = Enum.Material.Neon end) end)
add("unneon", "back to plastic", function() eachPart(function(p) p.Material = Enum.Material.Plastic end) end)
add("ghost", "see-through character", function() eachPart(function(p) p.Transparency = 0.6 end) end)
add("unghost", "solid character", function() eachPart(function(p) p.Transparency = 0 end) end)
add("colorchar", "colorchar <r> <g> <b> - paint your character", function(a)
	local c = Color3.fromRGB(tonumber(a[1]) or 255, tonumber(a[2]) or 40, tonumber(a[3]) or 40)
	eachPart(function(p) p.Color = c end)
end)
add("rainbowchar", "cycle your character through rainbow colors", function() fx.rainbowChar = true end)
add("unrainbowchar", "stop the rainbow character", function() fx.rainbowChar = false end)
add("headless", "hide your head", function()
	local char = getChar()
	local head = char and char:FindFirstChild("Head")
	if head then
		head.Transparency = 1
		for _, d in ipairs(head:GetChildren()) do if d:IsA("Decal") then d.Transparency = 1 end end
	end
end)
local function addEffect(kind)
	local _, _, hrp = getChar()
	if not hrp then return end
	local old = hrp:FindFirstChild("Cmd_" .. kind)
	if old then old:Destroy() end
	local e
	if kind == "fire" then e = Instance.new("Fire") e.Size = 8 e.Heat = 10
	elseif kind == "smoke" then e = Instance.new("Smoke")
	else e = Instance.new("Sparkles") end
	e.Name = "Cmd_" .. kind
	e.Parent = hrp
end
add("fire", "set yourself on fire (only you see it)", function() addEffect("fire") end)
add("smoke", "smoke around you", function() addEffect("smoke") end)
add("sparkles", "sparkles around you", function() addEffect("sparkles") end)
add("trail", "leave a glowing trail behind you", function()
	local _, _, hrp = getChar()
	if not hrp then return end
	for _, n in ipairs({ "Cmd_trail", "Cmd_a0", "Cmd_a1" }) do
		local o = hrp:FindFirstChild(n)
		if o then o:Destroy() end
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "Cmd_a0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "Cmd_a1"
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = hrp
	local tr = Instance.new("Trail")
	tr.Name = "Cmd_trail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 1.2
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(glowColor, Color3.new(0, 0, 0))
	tr.Transparency = NumberSequence.new(0, 1)
	tr.Parent = hrp
end)
add({ "unfx", "untrail" }, "remove fire / smoke / sparkles / trail", function()
	local _, _, hrp = getChar()
	if not hrp then return end
	for _, c in ipairs(hrp:GetChildren()) do
		if c.Name:sub(1, 4) == "Cmd_" then c:Destroy() end
	end
end)

---- screen / world effects (local only)
local fxCC, fxSun
local function cc()
	if not fxCC then
		fxCC = Instance.new("ColorCorrectionEffect")
		fxCC.Name = "VermilionCC"
		fxCC.Parent = Lighting
	end
	fxCC.TintColor = Color3.new(1, 1, 1)
	fxCC.Brightness, fxCC.Contrast, fxCC.Saturation = 0, 0, 0
	return fxCC
end
add("noir", "black and white screen", function() local c = cc() c.Saturation = -1 c.Contrast = 0.2 end)
add("vivid", "punchy saturated colors", function() local c = cc() c.Saturation = 0.6 c.Contrast = 0.15 end)
add("sepia", "old photo look", function() local c = cc() c.TintColor = Color3.fromRGB(255, 225, 185) c.Saturation = -0.4 c.Contrast = 0.1 end)
add("nightvision", "green night vision", function()
	local c = cc()
	c.TintColor = Color3.fromRGB(130, 255, 150)
	c.Brightness = 0.12
	c.Contrast = 0.25
	c.Saturation = -0.3
end)
add("cleanfx", "remove screen effects made by these commands", function()
	if fxCC then fxCC:Destroy() fxCC = nil end
	if fxSun then fxSun:Destroy() fxSun = nil end
end)
add("sunrays", "sunrays [intensity]", function(a)
	fxSun = fxSun or Instance.new("SunRaysEffect", Lighting)
	fxSun.Intensity = tonumber(a[1]) or 0.4
	fxSun.Spread = 0.8
end)
add("density", "density <0-1> - atmosphere thickness", function(a)
	for _, v in ipairs(Lighting:GetChildren()) do
		if v:IsA("Atmosphere") then v.Density = math.clamp(tonumber(a[1]) or 0.3, 0, 1) end
	end
end)
add("nosky", "remove the skybox (local)", function()
	for _, v in ipairs(Lighting:GetChildren()) do
		if v:IsA("Sky") then v:Destroy() end
	end
end)
add("noclouds", "hide clouds", function()
	local c = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if c then c.Enabled = false end
end)
add("timelapse", "timelapse [hours per second] - fast day/night cycle", function(a) fx.timelapse = tonumber(a[1]) or 1.5 end)
add("untimelapse", "stop the day/night cycle", function() fx.timelapse = nil end)
add("quality", "quality <1-10> - graphics level", function(a)
	local n = math.clamp(math.floor(tonumber(a[1]) or 5), 1, 21)
	pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel["Level" .. string.format("%02d", n)] end)
end)
add("potato", "flatten materials + hide textures (rejoin to undo)", function()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
	end
	notify("Potato mode (rejoin to undo)")
end)

local bars
add("cinematic", "cinematic black bars", function()
	if bars then return end
	bars = {}
	for i = 1, 2 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, i - 1)
		f.Position = UDim2.fromScale(0, i - 1)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = -5
		f.Parent = screenGui
		tween(f, 0.6, { Size = UDim2.fromScale(1, 0.12) })
		bars[i] = f
	end
end)
add("uncinematic", "remove the black bars", function()
	if not bars then return end
	local b = bars
	bars = nil
	for _, f in ipairs(b) do
		tween(f, 0.4, { Size = UDim2.fromScale(1, 0) }).Completed:Connect(function() f:Destroy() end)
	end
end)
add("topdown", "topdown [height] - camera looks straight down at you", function(a)
	local h = tonumber(a[1]) or 60
	RunService:UnbindFromRenderStep("CmdTopDown")
	cam().CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("CmdTopDown", Enum.RenderPriority.Camera.Value + 1, function()
		local _, _, hrp = getChar()
		if hrp then cam().CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, h, 0.01), hrp.Position) end
	end)
end)
add("untopdown", "back to the normal camera", function()
	RunService:UnbindFromRenderStep("CmdTopDown")
	local _, hum = getChar()
	cam().CameraType = Enum.CameraType.Custom
	if hum then cam().CameraSubject = hum end
end)

---- HUD / interface
local hud = Instance.new("TextLabel")
hud.Size = UDim2.fromOffset(190, 40)
hud.Position = UDim2.new(0, 8, 0, 78)
hud.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
hud.BackgroundTransparency = 0.3
hud.TextColor3 = Color3.fromRGB(237, 237, 240)
hud.Font = Enum.Font.Code
hud.TextSize = 13
hud.Text = ""
hud.Visible = false
hud.Parent = screenGui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 4)
RunService.RenderStepped:Connect(function()
	if not hud.Visible then return end
	local _, _, hrp = getChar()
	if not hrp then return end
	local p, v = hrp.Position, hrp.AssemblyLinearVelocity
	hud.Text = ("XYZ %d %d %d\nSPD %d"):format(p.X, p.Y, p.Z, Vector3.new(v.X, 0, v.Z).Magnitude)
end)
add({ "hud", "coords" }, "toggle a live position + speed readout", function() hud.Visible = not hud.Visible end)

local mark = Instance.new("TextLabel")
mark.Size = UDim2.fromOffset(160, 20)
mark.AnchorPoint = Vector2.new(1, 1)
mark.Position = UDim2.new(1, -8, 1, -8)
mark.BackgroundTransparency = 1
mark.TextColor3 = Color3.fromRGB(227, 66, 52)
mark.TextTransparency = 0.3
mark.Font = Enum.Font.GothamBlack
mark.TextSize = 12
mark.TextXAlignment = Enum.TextXAlignment.Right
mark.Text = "VERMILION"
mark.Visible = false
mark.Parent = screenGui
add("watermark", "toggle the VERMILION watermark", function() mark.Visible = not mark.Visible end)
add("clearnotifs", "clear all notifications", function()
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end)

local THEMES = {
	blood = Color3.fromRGB(200, 20, 30), ice = Color3.fromRGB(120, 210, 255),
	toxic = Color3.fromRGB(120, 255, 60), royal = Color3.fromRGB(140, 90, 255),
	gold = Color3.fromRGB(255, 200, 60), sunset = Color3.fromRGB(255, 110, 70),
	mint = Color3.fromRGB(80, 255, 190), rose = Color3.fromRGB(255, 100, 160),
}
add("theme", "theme <blood|ice|toxic|royal|gold|sunset|mint|rose>", function(a)
	local c = THEMES[(a[1] or ""):lower()]
	if not c then
		local names = {}
		for n in pairs(THEMES) do names[#names + 1] = n end
		table.sort(names)
		return notify("Themes: " .. table.concat(names, ", "))
	end
	fx.rainbowGlow = false
	glowColor = c
	buildGlowSeq()
	notify("Theme: " .. a[1]:lower())
end)
add("rainbowglow", "rainbow cycling UI glow", function() fx.rainbowGlow = true end)
add("unrainbowglow", "stop the rainbow glow", function()
	fx.rainbowGlow = false
	glowColor = Color3.fromRGB(227, 66, 52)
	buildGlowSeq()
end)

---- tools for the command bar itself
add({ "find", "search" }, "find <text> - search the command list", function(a)
	local q = (a[1] or ""):lower()
	if q == "" then return notify("Usage: find <text>") end
	local out = {}
	for _, n in ipairs(COMMAND_LIST) do
		if n:find(q, 1, true) or (descriptions[n] or ""):lower():find(q, 1, true) then out[#out + 1] = n end
	end
	notify(#out > 0 and (#out .. " found: " .. table.concat(out, ", ")) or "No match")
end)
add("cmdcount", "how many commands there are", function() notify(#COMMAND_LIST .. " commands") end)

add("alias", "alias <name> <command...> - make your own shortcut", function(a)
	local name = (a[1] or ""):lower()
	if name == "" or #a < 2 then return notify("Usage: alias <name> <command...>") end
	if commands[name] and not aliases[name] then return notify("That name is taken") end
	local line = table.concat(a, " ", 2)
	if not commands[name] then
		table.insert(COMMAND_LIST, name)
		table.sort(COMMAND_LIST)
	end
	aliases[name] = true
	descriptions[name] = "alias: " .. line
	commands[name] = function(extra) executeCommand(line .. " " .. table.concat(extra, " "), true) end
	notify("Alias saved: " .. name)
end)

local function resolveKey(s)
	for _, cand in ipairs({ s:upper(), s:sub(1, 1):upper() .. s:sub(2):lower(), s }) do
		local ok, k = pcall(function() return Enum.KeyCode[cand] end)
		if ok and k then return k end
	end
end
add("bind", "bind <key> <command...> - press a key to run a command", function(a)
	local key = a[1] and resolveKey(a[1])
	if not key or #a < 2 then return notify("Usage: bind <key> <command...>") end
	binds[key] = table.concat(a, " ", 2)
	notify("Bound " .. key.Name)
end)
add("unbind", "unbind <key>", function(a)
	local key = a[1] and resolveKey(a[1])
	if key then binds[key] = nil notify("Unbound " .. key.Name) end
end)
add("binds", "list your key binds", function()
	local out = {}
	for k, line in pairs(binds) do out[#out + 1] = k.Name .. "=" .. line end
	notify(#out > 0 and table.concat(out, " | ") or "No binds")
end)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local line = binds[input.KeyCode]
	if line then executeCommand(line, true) end
end)

add({ "repeat", "rep" }, "repeat <times> <command...>", function(a)
	local n = math.clamp(math.floor(tonumber(a[1]) or 1), 1, 50)
	local line = table.concat(a, " ", 2)
	if line == "" then return end
	task.spawn(function()
		for _ = 1, n do
			executeCommand(line, true)
			task.wait(0.1)
		end
	end)
end)
add({ "delay", "after" }, "delay <seconds> <command...> - run a command later", function(a)
	local s = math.clamp(tonumber(a[1]) or 1, 0, 600)
	local line = table.concat(a, " ", 2)
	if line == "" then return end
	task.delay(s, function() executeCommand(line, true) end)
end)
add("loop", "loop <seconds> <command...> - run a command over and over", function(a)
	local s = math.clamp(tonumber(a[1]) or 1, 0.1, 600)
	local line = table.concat(a, " ", 2)
	if line == "" then return end
	fx.loopToken += 1
	local token = fx.loopToken
	task.spawn(function()
		while fx.loopToken == token do
			executeCommand(line, true)
			task.wait(s)
		end
	end)
end)
add("unloop", "stop the loop", function() fx.loopToken += 1 end)

---- fun / utility
add("roll", "roll [sides] - roll a die", function(a)
	notify("Rolled " .. math.random(1, math.max(2, math.floor(tonumber(a[1]) or 6))))
end)
add("coin", "flip a coin", function() notify(math.random(2) == 1 and "Heads" or "Tails") end)
add("random", "random <min> <max>", function(a)
	local lo, hi = math.floor(tonumber(a[1]) or 1), math.floor(tonumber(a[2]) or 100)
	if lo > hi then lo, hi = hi, lo end
	notify("Random: " .. math.random(lo, hi))
end)
add("8ball", "8ball <question>", function()
	local answers = { "Yes.", "No.", "Definitely.", "Not a chance.", "Ask again later.", "Signs point to yes.", "Very doubtful.", "It is certain." }
	notify(answers[math.random(#answers)])
end)

local function calcEval(str)
	str = str:gsub("%s+", "")
	local pos = 1
	local expr
	local function peek() return str:sub(pos, pos) end
	local function factor()
		if peek() == "(" then
			pos += 1
			local v = expr()
			if peek() ~= ")" then error("missing )") end
			pos += 1
			return v
		end
		if peek() == "-" then pos += 1 return -factor() end
		local s, e = str:find("^%d*%.?%d+", pos)
		if not s then error("bad number") end
		pos = e + 1
		return tonumber(str:sub(s, e))
	end
	local function power()
		local b = factor()
		if peek() == "^" then pos += 1 return b ^ power() end
		return b
	end
	local function term()
		local v = power()
		while peek() == "*" or peek() == "/" or peek() == "%" do
			local op = peek()
			pos += 1
			local r = power()
			if op == "*" then v *= r elseif op == "/" then v /= r else v %= r end
		end
		return v
	end
	expr = function()
		local v = term()
		while peek() == "+" or peek() == "-" do
			local op = peek()
			pos += 1
			local r = term()
			if op == "+" then v += r else v -= r end
		end
		return v
	end
	local v = expr()
	if pos <= #str then error("unexpected " .. peek()) end
	return v
end
add("calc", "calc <math> - e.g. calc (2+3)*4^2", function(a)
	local ok, v = pcall(calcEval, table.concat(a, " "))
	notify(ok and ("= " .. tostring(v)) or "Bad expression")
end)

add({ "panic", "alloff" }, "turn EVERYTHING off at once", function()
	for _, n in ipairs({
		"unfly", "unfc", "unnoclip", "uninfjump", "unspin", "ungod", "unesp", "untracers", "unaimbot", "untm",
		"unfreeze", "unbhop", "unfollow", "unxray", "unlight", "unorbit", "unheadsit", "unautowalk", "unfloat",
		"unparachute", "unantivoid", "unrainbowchar", "unrainbowglow", "untimelapse", "unsprint", "cleanfx",
		"uncinematic", "untopdown", "unfullbright", "unlockspeed", "unredworld", "unloop", "unregen", "unfx", "closewidgets",
	}) do
		executeCommand(n, true)
	end
	notify("Everything off")
end)

---- interactive widgets (real on-screen objects you can touch)
do
local rng = Random.new()
local floats = {}
local WHITE_T = Color3.fromRGB(237, 237, 240)
local RED = Color3.fromRGB(227, 66, 52)

local function closeFloat(name)
	local f = floats[name]
	floats[name] = nil
	if f and f.Parent then
		tween(animScale(f), 0.25, { Scale = 0.05 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
			f:Destroy()
		end)
	end
end

local function popIn(f)
	local sc = animScale(f)
	sc.Scale = 0.3
	tween(sc, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function closeButton(parent, name, pos)
	local x = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = pos, Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(20, 20, 23), TextColor3 = WHITE_T,
		Font = Enum.Font.GothamBlack, TextSize = 12, Text = "X", ZIndex = 30,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, x)
	make("UIStroke", { Color = RED, Thickness = 1.5 }, x)
	x.Activated:Connect(function() closeFloat(name) end)
end

-- free-floating object with a small X and an optional hint line under it
local function newFloat(name, w, h, hintText)
	local old = floats[name]
	if old and old.Parent then old:Destroy() end
	local f = make("Frame", {
		Name = "F_" .. name, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, rng:NextInteger(-40, 40), 0.5, rng:NextInteger(-30, 30)),
		Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ZIndex = 20,
	}, screenGui)
	floats[name] = f
	closeButton(f, name, UDim2.new(1, 8, 0, -8))
	if hintText then
		make("TextLabel", {
			Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8),
			Size = UDim2.fromOffset(math.max(w, 190), 16), BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(150, 150, 158), Font = Enum.Font.Code, TextSize = 12, Text = hintText,
		}, f)
	end
	popIn(f)
	return f
end
local function setHint(f, text)
	local h = f:FindFirstChild("Hint")
	if h then h.Text = text end
end

-- dark panel with a title and an X (drag it anywhere)
local drag
local function newPanel(name, w, h, title)
	local old = floats[name]
	if old and old.Parent then old:Destroy() end
	local p = make("Frame", {
		Name = "F_" .. name, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, rng:NextInteger(-40, 40), 0.5, rng:NextInteger(-30, 30)),
		Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(20, 20, 23), BorderSizePixel = 0, ZIndex = 20,
	}, screenGui)
	floats[name] = p
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, p)
	glowFrame(p, 2)
	make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -40, 0, 16), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = WHITE_T, Text = title,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
	}, p)
	closeButton(p, name, UDim2.new(1, -6, 0, 6))
	popIn(p)
	drag(p, p, {})
	return p
end

local function smallBtn(parent, text, pos, size, cb)
	local b = make("TextButton", {
		Position = pos, Size = size, BackgroundColor3 = Color3.fromRGB(29, 29, 33), TextColor3 = WHITE_T,
		Font = Enum.Font.GothamBold, TextSize = 14, Text = text, AutoButtonColor = true, ZIndex = 22,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	make("UIStroke", { Color = RED, Thickness = 1.2 }, b)
	b.Activated:Connect(cb)
	return b
end

-- drag `handle` to move `target`. hooks: onMove(step, now), onTap(), onRelease(moved)
drag = function(handle, target, hooks)
	local dragging, moved, startIn, startPos = false, false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if dragging then return end
		dragging, moved = true, false
		startIn, startPos = input.Position, target.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End and dragging then
				dragging = false
				if not moved and hooks.onTap then hooks.onTap() end
				if hooks.onRelease then hooks.onRelease(moved) end
			end
		end)
	end)
	local conn = UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local d = input.Position - startIn
		if not moved and d.Magnitude < 6 then return end
		moved = true
		local k = mainScale.Scale
		target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X / k, startPos.Y.Scale, startPos.Y.Offset + d.Y / k)
		if hooks.onMove then hooks.onMove(input.Delta, os.clock()) end
	end)
	target.Destroying:Connect(function() conn:Disconnect() end)
end

----------------------------------------------------------------- 8 BALL
local ANSWERS = {
	"It is certain.", "Without a doubt.", "Yes, definitely.", "You may rely on it.", "As I see it, yes.",
	"Most likely.", "Outlook good.", "Yes.", "Signs point to yes.", "Reply hazy, try again.",
	"Ask again later.", "Better not tell you now.", "Cannot predict now.", "Concentrate and ask again.",
	"Don't count on it.", "My reply is no.", "My sources say no.", "Outlook not so good.", "Very doubtful.",
}
local function open8Ball()
	local f = newFloat("8ball", 150, 150, "think of a question, then drag + shake the ball")
	local ball = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ball)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(86, 86, 98), Color3.fromRGB(6, 6, 8)), Rotation = 55 }, ball)
	glowFrame(ball, 2)
	local shine = make("Frame", {
		Position = UDim2.fromScale(0.2, 0.1), Size = UDim2.fromScale(0.3, 0.16), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78, BorderSizePixel = 0, Rotation = -30, ZIndex = 22,
	}, ball)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, shine)
	local win = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(240, 240, 244), BorderSizePixel = 0, ZIndex = 22,
	}, ball)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, win)
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.84, 0.84),
		BackgroundTransparency = 1, Text = "8", TextColor3 = Color3.fromRGB(10, 10, 12), Font = Enum.Font.GothamBlack,
		TextScaled = true, TextWrapped = true, ZIndex = 23,
	}, win)

	local shaking = false
	local function reveal()
		if shaking then return end
		shaking = true
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.6 and ball.Parent do
				local k = 1 - (os.clock() - t0) / 0.6
				ball.Rotation = rng:NextInteger(-14, 14) * k
				ball.Position = UDim2.new(0.5, rng:NextInteger(-8, 8) * k, 0.5, rng:NextInteger(-8, 8) * k)
				RunService.Heartbeat:Wait()
			end
			if ball.Parent then
				ball.Rotation = 0
				ball.Position = UDim2.fromScale(0.5, 0.5)
			end
		end)
		tween(label, 0.25, { TextTransparency = 1 })
		task.delay(0.55, function()
			if not label.Parent then return end
			label.Text = ANSWERS[rng:NextInteger(1, #ANSWERS)]
			label.TextColor3 = Color3.new(1, 1, 1)
			tween(win, 0.45, { BackgroundColor3 = Color3.fromRGB(28, 38, 150), Size = UDim2.fromScale(0.62, 0.62) }, Enum.EasingStyle.Back)
			tween(label, 0.5, { TextTransparency = 0 })
			pulse(ball, 0.1)
			shaking = false
		end)
	end

	local lastX, lastY, revs = 0, 0, {}
	drag(ball, f, {
		onMove = function(step, now)
			local sx = math.abs(step.X) >= 3 and (step.X > 0 and 1 or -1) or 0
			local sy = math.abs(step.Y) >= 3 and (step.Y > 0 and 1 or -1) or 0
			if sx ~= 0 then
				if lastX ~= 0 and sx ~= lastX then table.insert(revs, now) end
				lastX = sx
			end
			if sy ~= 0 then
				if lastY ~= 0 and sy ~= lastY then table.insert(revs, now) end
				lastY = sy
			end
			while revs[1] and now - revs[1] > 0.8 do table.remove(revs, 1) end
			if #revs >= 4 then
				revs = {}
				reveal()
			end
			if not shaking then ball.Rotation = math.clamp(step.X * 1.5, -22, 22) end
		end,
		onRelease = function()
			lastX, lastY, revs = 0, 0, {}
			if not shaking then tween(ball, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back) end
		end,
	})
end

----------------------------------------------------------------- COIN
local function openCoin()
	local f = newFloat("coin", 110, 110, "tap the coin to flip it, drag to move it")
	local coin = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(240, 196, 64), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, coin)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 232, 130), Color3.fromRGB(190, 135, 30)), Rotation = 45 }, coin)
	make("UIStroke", { Color = Color3.fromRGB(150, 105, 20), Thickness = 3 }, coin)
	local ring = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.76, 0.76),
		BackgroundTransparency = 1, ZIndex = 22,
	}, coin)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	make("UIStroke", { Color = Color3.fromRGB(165, 115, 25), Thickness = 2 }, ring)
	local face = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "H", TextColor3 = Color3.fromRGB(125, 82, 10),
		Font = Enum.Font.GothamBlack, TextScaled = true, ZIndex = 23,
	}, ring)
	make("UITextSizeConstraint", { MaxTextSize = 38 }, face)

	local cur, flipping, counts = "H", false, { H = 0, T = 0 }
	local function flip()
		if flipping then return end
		flipping = true
		local result = rng:NextNumber() < 0.5 and "H" or "T"
		local half = rng:NextInteger(6, 9)
		if (half % 2 == 0) ~= (result == cur) then half += 1 end
		local start = cur
		local other = (start == "H") and "T" or "H"
		local t0, dur = os.clock(), 1.15
		while coin.Parent do
			local t = math.min(1, (os.clock() - t0) / dur)
			local e = 1 - (1 - t) ^ 2
			local c = math.cos(math.pi * half * e)
			local lift = math.sin(math.pi * t)
			coin.Size = UDim2.fromScale(1 + 0.2 * lift, math.max(0.05, math.abs(c)) * (1 + 0.2 * lift))
			coin.Position = UDim2.new(0.5, 0, 0.5, -lift * 110)
			face.Text = (c >= 0) and start or other
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if not coin.Parent then return end
		coin.Size = UDim2.fromScale(1, 1)
		coin.Position = UDim2.fromScale(0.5, 0.5)
		face.Text = result
		cur = result
		counts[result] += 1
		pulse(coin, 0.12)
		setHint(f, (result == "H" and "HEADS" or "TAILS") .. "   (H:" .. counts.H .. "  T:" .. counts.T .. ")")
		flipping = false
	end
	drag(coin, f, { onTap = flip })
end

----------------------------------------------------------------- DICE
local PIPS = { [1] = { 5 }, [2] = { 1, 9 }, [3] = { 1, 5, 9 }, [4] = { 1, 3, 7, 9 }, [5] = { 1, 3, 5, 7, 9 }, [6] = { 1, 3, 4, 6, 7, 9 } }
local function openDice(sides)
	sides = math.clamp(math.floor(sides or 6), 2, 1000)
	local f = newFloat("dice", 96, 96, "tap the die to roll it (d" .. sides .. ")")
	local die = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(240, 240, 244), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(0.2, 0) }, die)
	glowFrame(die, 2)
	local pips = {}
	for i = 1, 9 do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local pip = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.25 + 0.25 * col, 0.25 + 0.25 * row),
			Size = UDim2.fromScale(0.17, 0.17), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0,
			BackgroundTransparency = 1, ZIndex = 22,
		}, die)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, pip)
		pips[i] = pip
	end
	local num = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(20, 20, 24),
		Font = Enum.Font.GothamBlack, TextScaled = true, TextTransparency = 1, Text = "", ZIndex = 23,
	}, die)
	make("UITextSizeConstraint", { MaxTextSize = 34 }, num)
	local function show(v)
		if sides == 6 then
			local on = {}
			for _, i in ipairs(PIPS[v]) do on[i] = true end
			for i = 1, 9 do pips[i].BackgroundTransparency = on[i] and 0 or 1 end
			num.TextTransparency = 1
		else
			for i = 1, 9 do pips[i].BackgroundTransparency = 1 end
			num.Text = tostring(v)
			num.TextTransparency = 0
		end
	end
	show(sides == 6 and 5 or 1)

	local rolling = false
	local function roll()
		if rolling then return end
		rolling = true
		local result = rng:NextInteger(1, sides)
		local t0, dur, lastFace = os.clock(), 1.0, 0
		while die.Parent do
			local t = math.min(1, (os.clock() - t0) / dur)
			local e = 1 - (1 - t) ^ 3
			die.Rotation = e * 720
			die.Position = UDim2.new(0.5, 0, 0.5, -math.sin(math.pi * t) * 90)
			if os.clock() - lastFace > 0.07 and t < 0.9 then
				lastFace = os.clock()
				show(rng:NextInteger(1, sides))
			end
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if not die.Parent then return end
		die.Rotation = 0
		die.Position = UDim2.fromScale(0.5, 0.5)
		show(result)
		pulse(die, 0.15)
		setHint(f, "Rolled " .. result .. "  (d" .. sides .. ")")
		rolling = false
	end
	drag(die, f, { onTap = roll })
end

----------------------------------------------------------------- STOPWATCH
local function openStopwatch()
	local p = newPanel("stopwatch", 190, 100, "STOPWATCH")
	local timeL = make("TextLabel", {
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "00:00.00",
		TextColor3 = WHITE_T, Font = Enum.Font.GothamBlack, TextSize = 22, ZIndex = 21,
	}, p)
	local running, elapsed, last = false, 0, os.clock()
	local startBtn
	startBtn = smallBtn(p, "START", UDim2.new(0, 10, 1, -34), UDim2.new(0.5, -14, 0, 26), function()
		running = not running
		last = os.clock()
		startBtn.Text = running and "PAUSE" or "START"
	end)
	smallBtn(p, "RESET", UDim2.new(0.5, 4, 1, -34), UDim2.new(0.5, -14, 0, 26), function()
		elapsed = 0
		running = false
		startBtn.Text = "START"
		last = os.clock()
	end)
	local conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if running then elapsed += now - last end
		last = now
		timeL.Text = string.format("%02d:%02d.%02d", math.floor(elapsed / 60), math.floor(elapsed % 60), math.floor((elapsed * 100) % 100))
	end)
	p.Destroying:Connect(function() conn:Disconnect() end)
end

----------------------------------------------------------------- ANALOG CLOCK
local function openClock()
	local f = newFloat("clock", 150, 150)
	local face = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, face)
	glowFrame(face, 2)
	for i = 0, 11 do
		local big = i % 3 == 0
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Rotation = i * 30, ZIndex = 22,
		}, face)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(big and 3 or 1, big and 10 or 5),
			BackgroundColor3 = big and RED or Color3.fromRGB(120, 120, 128), BorderSizePixel = 0, ZIndex = 22,
		}, box)
	end
	local function hand(len, thick, color)
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(len * 2, len * 2),
			BackgroundTransparency = 1, ZIndex = 23,
		}, face)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(thick, len),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 23,
		}, box)
		return box
	end
	local hourH = hand(36, 4, Color3.fromRGB(237, 237, 240))
	local minH = hand(54, 3, Color3.fromRGB(237, 237, 240))
	local secH = hand(62, 1.5, RED)
	local hub = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 25,
	}, face)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, hub)
	local digital = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(100, 14),
		BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(150, 150, 158), Font = Enum.Font.Code, TextSize = 11, Text = "", ZIndex = 22,
	}, face)
	local lastSec, mark0 = -1, os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.date("*t")
		if t.sec ~= lastSec then lastSec, mark0 = t.sec, os.clock() end
		local s = t.sec + math.min(1, os.clock() - mark0)
		local m = t.min + s / 60
		local h = (t.hour % 12) + m / 60
		secH.Rotation, minH.Rotation, hourH.Rotation = s * 6, m * 6, h * 30
		digital.Text = os.date("%I:%M:%S %p")
	end)
	f.Destroying:Connect(function() conn:Disconnect() end)
	drag(face, f, {})
end

----------------------------------------------------------------- RADAR
local function openRadar(range)
	range = math.clamp(tonumber(range) or 150, 20, 2000)
	local f = newFloat("radar", 170, 170, "radar - range " .. range .. " studs (up = where you look)")
	local disc = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 16, 12), BackgroundTransparency = 0.12,
		BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
	glowFrame(disc, 2)
	local line = Color3.fromRGB(70, 90, 80)
	for _, s in ipairs({ 0.66, 0.33 }) do
		local r = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(s, s),
			BackgroundTransparency = 1, ZIndex = 22,
		}, disc)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, r)
		make("UIStroke", { Color = line, Thickness = 1, Transparency = 0.4 }, r)
	end
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = line, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 22 }, disc)
	make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = line, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 22 }, disc)
	local sweep = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, ZIndex = 23,
	}, disc)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 2, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(242, 54, 45), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 23,
	}, sweep)
	local me = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 25,
	}, disc)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, me)
	local dots = {}
	local conn = RunService.RenderStepped:Connect(function()
		sweep.Rotation = (os.clock() * 140) % 360
		local _, _, hrp = getChar()
		if not hrp then return end
		local look = workspace.CurrentCamera.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		fwd = fwd.Magnitude < 0.01 and Vector3.new(0, 0, -1) or fwd.Unit
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local seen = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local t = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if t then
				seen[p] = true
				local dot = dots[p]
				if not dot then
					dot = make("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
						BackgroundColor3 = Color3.fromRGB(255, 70, 60), BorderSizePixel = 0, ZIndex = 24,
					}, disc)
					make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
					dots[p] = dot
				end
				local d = t.Position - hrp.Position
				local x, y = d:Dot(right) / range, -d:Dot(fwd) / range
				local m = math.sqrt(x * x + y * y)
				local far = m > 1
				if far then x, y = x / m, y / m end
				dot.Position = UDim2.fromScale(0.5 + x * 0.46, 0.5 + y * 0.46)
				dot.BackgroundTransparency = far and 0.65 or 0
				dot.Visible = true
			end
		end
		for p, dot in pairs(dots) do
			if not seen[p] then dot.Visible = false end
		end
	end)
	f.Destroying:Connect(function() conn:Disconnect() end)
	drag(disc, f, {})
end

----------------------------------------------------------------- WHEEL
local function openWheel(options)
	if #options < 2 then options = { "Yes", "No", "Maybe", "Again", "Skip", "Go" } end
	while #options > 12 do table.remove(options) end
	local n = #options
	local seg = 360 / n
	local f = newFloat("wheel", 170, 170, "tap SPIN to spin the wheel, drag the rim to move it")
	local wheel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, wheel)
	glowFrame(wheel, 2)
	for i = 1, n do
		local div = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Rotation = (i - 1) * seg, ZIndex = 22,
		}, wheel)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 1, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(70, 70, 80), BorderSizePixel = 0, ZIndex = 22,
		}, div)
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Rotation = (i - 0.5) * seg, ZIndex = 23,
		}, wheel)
		local lbl = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(math.clamp(2 * math.pi * 62 / n, 28, 70), 14), BackgroundTransparency = 1,
			Text = options[i], TextColor3 = WHITE_T, Font = Enum.Font.GothamBold, TextScaled = true, ZIndex = 23,
		}, box)
		make("UITextSizeConstraint", { MaxTextSize = 12 }, lbl)
	end
	local pointer = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = RED, BorderSizePixel = 0, Rotation = 45, ZIndex = 26,
	}, f)
	local spinning, cur = false, 0
	local hubBtn
	hubBtn = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(20, 20, 23), TextColor3 = RED, Font = Enum.Font.GothamBlack, TextSize = 11,
		Text = "SPIN", ZIndex = 27,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, hubBtn)
	make("UIStroke", { Color = RED, Thickness = 1.5 }, hubBtn)
	hubBtn.Activated:Connect(function()
		if spinning then return end
		spinning = true
		local idx = rng:NextInteger(1, n)
		local base = math.ceil(cur / 360) * 360 + 360 * rng:NextInteger(4, 6)
		local target = base - (idx - 0.5) * seg + rng:NextNumber(-0.35, 0.35) * seg
		local tw = tween(wheel, 4.2, { Rotation = target }, Enum.EasingStyle.Quint)
		tw.Completed:Connect(function()
			cur = target
			spinning = false
			if f.Parent then
				pulse(pointer, 0.5)
				setHint(f, "Result: " .. options[idx])
				notify("Wheel: " .. options[idx])
			end
		end)
	end)
	drag(wheel, f, {})
end

----------------------------------------------------------------- NOTES
local savedNote = ""
local function openNote()
	local p = newPanel("note", 220, 150, "NOTES")
	local tb = make("TextBox", {
		Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 1, -36), BackgroundColor3 = Color3.fromRGB(29, 29, 33),
		TextColor3 = WHITE_T, PlaceholderText = "type here...", PlaceholderColor3 = Color3.fromRGB(120, 120, 128),
		Font = Enum.Font.Code, TextSize = 13, MultiLine = true, ClearTextOnFocus = false, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = savedNote, ZIndex = 21,
	}, p)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, tb)
	tb:GetPropertyChangedSignal("Text"):Connect(function() savedNote = tb.Text end)
end

----------------------------------------------------------------- CALCULATOR KEYPAD
local function fmtNum(v)
	if v ~= v or v == math.huge or v == -math.huge then error("math error") end
	if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
	return string.format("%.10g", v)
end
local function openCalc()
	local p = newPanel("calc", 190, 308, "CALCULATOR")
	local disp = make("TextLabel", {
		Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 38), BackgroundColor3 = Color3.fromRGB(29, 29, 33),
		TextColor3 = WHITE_T, Font = Enum.Font.GothamBold, TextSize = 18, Text = "0", TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21,
	}, p)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, disp)
	make("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, disp)
	local expr = ""
	local function refresh() disp.Text = (expr == "") and "0" or expr end
	local rows = { { "C", "(", ")", "<" }, { "7", "8", "9", "/" }, { "4", "5", "6", "*" }, { "1", "2", "3", "-" }, { "0", ".", "^", "+" } }
	local function press(k)
		if k == "C" then expr = ""
		elseif k == "<" then expr = expr:sub(1, -2)
		elseif k == "=" then
			local ok, v = pcall(function() return fmtNum(calcEval(expr)) end)
			expr = ok and v or ""
			disp.Text = ok and v or "Error"
			pulse(disp, 0.06)
			return
		else expr ..= k end
		refresh()
	end
	for r, row in ipairs(rows) do
		for c, k in ipairs(row) do
			smallBtn(p, k, UDim2.new(0, 10 + (c - 1) * 44, 0, 74 + (r - 1) * 38), UDim2.fromOffset(38, 32), function() press(k) end)
		end
	end
	smallBtn(p, "=", UDim2.new(0, 10, 0, 74 + 5 * 38), UDim2.new(1, -20, 0, 32), function() press("=") end)
end

----------------------------------------------------------------- RANDOM NUMBER (slot roller)
local function openRandom(loArg, hiArg)
	local lo, hi = math.floor(tonumber(loArg) or 1), math.floor(tonumber(hiArg) or 100)
	if lo > hi then lo, hi = hi, lo end
	local f = newFloat("random", 150, 64, "tap to roll  (" .. lo .. " - " .. hi .. ")")
	local plate = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, plate)
	glowFrame(plate, 2)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "?", TextColor3 = WHITE_T,
		Font = Enum.Font.GothamBlack, TextScaled = true, ZIndex = 22,
	}, plate)
	make("UITextSizeConstraint", { MaxTextSize = 34 }, label)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, label)

	local rolling = false
	local function roll()
		if rolling then return end
		rolling = true
		local result = rng:NextInteger(lo, hi)
		local t0, dur, nextAt = os.clock(), 1.1, 0
		while plate.Parent do
			local t = math.min(1, (os.clock() - t0) / dur)
			if os.clock() >= nextAt and t < 1 then
				label.Text = tostring(rng:NextInteger(lo, hi))
				nextAt = os.clock() + 0.04 + 0.22 * t * t -- reels slow down as they settle
				plate.Rotation = rng:NextInteger(-3, 3) * (1 - t)
			end
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if not plate.Parent then return end
		plate.Rotation = 0
		label.Text = tostring(result)
		pulse(plate, 0.1)
		rolling = false
	end
	drag(plate, f, { onTap = roll })
end

----------------------------------------------------------------- HEALTH VIAL (live)
local function openHealth()
	local f = newFloat("health", 58, 130, "")
	local vial = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, vial)
	glowFrame(vial, 2)
	local well = make("Frame", {
		Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1, ZIndex = 22,
	}, vial)
	local fill = make("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 22,
	}, well)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, fill)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "--", TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack, TextSize = 16, TextStrokeTransparency = 0.5, ZIndex = 24,
	}, vial)
	local shown, lastHp = 1, nil
	local conn = RunService.RenderStepped:Connect(function()
		local _, hum = getChar()
		if not hum then return end
		local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
		shown += (frac - shown) * 0.18
		fill.Size = UDim2.fromScale(1, math.max(0.04, shown))
		fill.BackgroundColor3 = Color3.fromRGB(90, 10, 16):Lerp(RED, math.clamp(shown * 1.4, 0, 1))
		label.Text = tostring(math.floor(hum.Health + 0.5))
		if lastHp and hum.Health < lastHp - 0.5 then pulse(vial, 0.12) end -- bump when you take damage
		lastHp = hum.Health
	end)
	f.Destroying:Connect(function() conn:Disconnect() end)
	drag(vial, f, {})
end

----------------------------------------------------------------- PING GAUGE (live)
local function openPing()
	local f = newFloat("ping", 140, 140, "network ping")
	local face = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, face)
	glowFrame(face, 2)
	for i = 0, 12 do
		local col = i <= 4 and Color3.fromRGB(120, 200, 120) or (i <= 8 and Color3.fromRGB(230, 180, 60) or RED)
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Rotation = -120 + i * 20, ZIndex = 22,
		}, face)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(i % 2 == 0 and 3 or 1.5, 9),
			BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 22,
		}, box)
	end
	local needle = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(110, 110),
		BackgroundTransparency = 1, Rotation = -120, ZIndex = 23,
	}, face)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromOffset(2.5, 50),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 23,
	}, needle)
	local hub = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 25,
	}, face)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, hub)
	local readout = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(100, 16),
		BackgroundTransparency = 1, TextColor3 = WHITE_T, Font = Enum.Font.GothamBlack, TextSize = 13, Text = "-- ms", ZIndex = 24,
	}, face)
	local target, angle, acc = 0, -120, 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			local ok, ms = pcall(function()
				return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			if ok and ms then
				target = math.clamp(ms / 300, 0, 1) * 240 - 120
				readout.Text = math.floor(ms) .. " ms"
			else
				readout.Text = "n/a"
			end
		end
		angle += (target - angle) * math.min(1, dt * 8)
		needle.Rotation = angle
	end)
	f.Destroying:Connect(function() conn:Disconnect() end)
	drag(face, f, {})
end

----------------------------------------------------------------- dial helper (turn things by dragging around a circle)
-- onAngle gets degrees clockwise from straight up (-180..180)
local function dialInput(area, onAngle)
	local active = false
	local function update(pos)
		local c = area.AbsolutePosition + area.AbsoluteSize / 2
		local d = Vector2.new(pos.X, pos.Y) - c
		if d.Magnitude < 4 then return end
		onAngle(math.deg(math.atan2(d.X, -d.Y)))
	end
	area.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			active = true
			update(input.Position)
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(input)
		if active and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position)
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			active = false
		end
	end)
	area.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
	return function() return active end
end

----------------------------------------------------------------- VOLUME KNOB
local function openKnob()
	local SoundService = game:GetService("SoundService")
	local f = newFloat("volume", 130, 130, "turn the knob - drag the ring to move")
	local plate = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, plate)
	glowFrame(plate, 2)
	for i = 0, 10 do
		local box = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Rotation = -135 + i * 27, ZIndex = 22,
		}, plate)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(i % 5 == 0 and 3 or 1.5, 8),
			BackgroundColor3 = i % 5 == 0 and RED or Color3.fromRGB(120, 120, 128), BorderSizePixel = 0, ZIndex = 22,
		}, box)
	end
	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(40, 40, 46), BorderSizePixel = 0, Rotation = 0, ZIndex = 23, Active = true,
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(90, 90, 100), Color3.fromRGB(22, 22, 26)), Rotation = 60 }, knob)
	make("UIStroke", { Color = Color3.fromRGB(70, 70, 78), Thickness = 2 }, knob)
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(4, 16),
		BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 24,
	}, knob)
	local readout = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(60, 20),
		BackgroundTransparency = 1, TextColor3 = WHITE_T, Font = Enum.Font.GothamBlack, TextSize = 15, Text = "", ZIndex = 25,
	}, plate)
	local function setAngle(a)
		a = math.clamp(a, -135, 135)
		knob.Rotation = a
		local v = math.floor((a + 135) / 270 * 100 + 0.5) / 10
		SoundService.Volume = v
		readout.Text = tostring(v)
	end
	local cur = math.clamp(SoundService.Volume, 0, 10)
	setAngle(cur / 10 * 270 - 135)
	local last = knob.Rotation
	dialInput(knob, function(a)
		if math.abs(a - last) > 200 then return end -- don't flip across the dead zone at the bottom
		last = a
		setAngle(a)
	end)
	drag(plate, f, {}) -- the knob handles its own input; the outer ring moves the whole thing
end

----------------------------------------------------------------- DAY / NIGHT DIAL
local function openTimeDial()
	local f = newFloat("time", 150, 150, "drag inside to set the time (top = noon), ring moves it")
	local plate = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 60, 50), BorderSizePixel = 0, ZIndex = 21,
	}, f)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, plate)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 90, 60), Color3.fromRGB(8, 8, 22)), Rotation = 90,
	}, plate)
	glowFrame(plate, 2)
	local disc = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(112, 112),
		BackgroundTransparency = 1, ZIndex = 22, Active = true,
	}, plate)
	local sun = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BorderSizePixel = 0, ZIndex = 24,
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, sun)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.4 }, sun)
	local readout = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 20),
		BackgroundTransparency = 1, TextColor3 = WHITE_T, Font = Enum.Font.GothamBlack, TextSize = 15, Text = "", ZIndex = 23,
	}, plate)
	local function place(clock)
		local th = math.rad((clock - 12) / 24 * 360)
		sun.Position = UDim2.new(0.5, math.sin(th) * 56, 0.5, -math.cos(th) * 56)
		local day = math.clamp(math.cos(th) * 1.5 + 0.4, 0, 1)
		sun.BackgroundColor3 = Color3.fromRGB(200, 215, 255):Lerp(Color3.fromRGB(255, 200, 60), day)
		local h = math.floor(clock) % 24
		readout.Text = string.format("%02d:%02d", h, math.floor((clock % 1) * 60))
	end
	drag(plate, f, {}) -- the ring moves the dial, the inner disc turns time
	local isDragging = dialInput(disc, function(a)
		local clock = (12 + a / 360 * 24) % 24
		Lighting.ClockTime = clock
		place(clock)
	end)
	place(Lighting.ClockTime)
	local conn = RunService.RenderStepped:Connect(function()
		if not isDragging() then place(Lighting.ClockTime) end -- follows timelapse / other commands
	end)
	f.Destroying:Connect(function() conn:Disconnect() end)
end

----------------------------------------------------------------- register commands
local function override(name, desc, fn)
	commands[name] = fn
	descriptions[name] = desc
end
local oldVolume, oldTime = commands.volume, commands.time
override("random", "random [min] [max] - a slot roller on screen: tap it to roll", function(a) openRandom(a[1], a[2]) end)
override("health", "health - a live health vial on screen", openHealth)
override("ping", "ping - a live ping gauge on screen", openPing)
override("volume", "volume [0-10] - with a number it sets it, with nothing it opens a turn-able knob", function(a)
	if a[1] then oldVolume(a) else openKnob() end
end)
override("time", "time [0-24] - with a number it sets it, with nothing it opens a day/night dial", function(a)
	if a[1] then oldTime(a) else openTimeDial() end
end)
override("8ball", "8ball - a real magic 8-ball on screen: drag it and shake to get an answer", open8Ball)
override("coin", "coin - a real coin on screen: tap it to flip, drag to move", openCoin)
override("roll", "roll [sides] - a real die on screen: tap it to roll", function(a) openDice(tonumber(a[1])) end)

local oldCalc, oldTimer, oldClock = commands.calc, commands.timer, commands.clock
commands.calc = function(a) if #a > 0 then oldCalc(a) else openCalc() end end
descriptions.calc = "calc [math] - with math it answers, with nothing it opens a keypad calculator"
commands.timer = function(a) if a[1] then oldTimer(a) else openStopwatch() end end
descriptions.timer = "timer [start|stop] - with nothing it opens a stopwatch panel"
commands.clock = function(a) if a[1] == "text" then oldClock(a) else openClock() end end
descriptions.clock = "clock - an analog clock on screen (clock text = just the time)"

add({ "stopwatch", "sw" }, "stopwatch panel with start / pause / reset", openStopwatch)
add("radar", "radar [range] - round radar showing players around you", function(a) openRadar(a[1]) end)
add("wheel", "wheel [a b c ...] - spin a prize wheel (tap SPIN)", function(a) openWheel({ table.unpack(a) }) end)
add({ "note", "notes" }, "notepad panel (keeps your text)", openNote)
add({ "closewidgets", "closeall" }, "close every on-screen widget", function()
	local names = {}
	for n in pairs(floats) do names[#names + 1] = n end
	for _, n in ipairs(names) do closeFloat(n) end
end)
end

table.sort(COMMAND_LIST)
end

---------------------------------------------------------------- drag the bar around
-- grab the edges, or the colored strip at the bottom (not the text field) and drag
do
	local dragging, dragStart, startPos = false, nil, nil

	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	local function beginDrag(input)
		if dragging or not isPress(input) then return end
		dragging = true
		dragStart = input.Position
		startPos = outerFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end

	outerFrame.InputBegan:Connect(beginDrag)
	accentBar.InputBegan:Connect(beginDrag)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			outerFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X / mainScale.Scale,
				startPos.Y.Scale, startPos.Y.Offset + d.Y / mainScale.Scale
			)
		end
	end)
end

-- bar entrance: drops in as a small pill, then stretches open and the text box fades up
do
	outerFrame.Position = UDim2.new(0.5, 0, 0, -60)
	outerFrame.Size = UDim2.new(0, 44, 0, 36)
	cmdBar.BackgroundTransparency = 1
	cmdBar.TextTransparency = 1
	accentBar.Size = UDim2.new(0, 0, 0, 4)
	accentBar.AnchorPoint = Vector2.new(0.5, 0)
	accentBar.Position = UDim2.new(0.5, 0, 1, -4)
	tween(outerFrame, 0.55, { Position = UDim2.new(0.5, 0, 0, 50) }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(outerFrame, 0.6, { Size = UDim2.new(0, 260, 0, 36) }, Enum.EasingStyle.Quint)
		tween(accentBar, 0.6, { Size = UDim2.new(1, 0, 0, 4) }, Enum.EasingStyle.Quint)
		task.delay(0.25, function()
			tween(cmdBar, 0.35, { BackgroundTransparency = 0.1, TextTransparency = 0 })
		end)
	end)
	-- the bar widens while you type and relaxes when you leave it
	cmdBar.Focused:Connect(function()
		tween(outerFrame, 0.3, { Size = UDim2.new(0, 340, 0, 36) }, Enum.EasingStyle.Quint)
	end)
	cmdBar.FocusLost:Connect(function()
		tween(outerFrame, 0.35, { Size = UDim2.new(0, 260, 0, 36) }, Enum.EasingStyle.Quint)
	end)
end

print("[CommandBar] ready -", #COMMAND_LIST, "commands")
end

--==================================================================
-- VERMILION HUB FULLSCREEN INTRO
--==================================================================
local playing = false

local LOGO_N = 128
local LOGO_RED = {5,62,66,6,61,67,7,60,68,8,59,69,9,58,70,10,57,71,11,57,71,12,56,72,13,55,73,14,54,74,15,53,75,16,53,75,17,52,76,18,51,77,19,50,78,20,50,78,21,28,29,21,49,79,21,99,100,22,27,31,22,48,80,22,97,101,23,26,32,23,47,81,23,96,102,24,26,33,24,47,81,24,95,102,25,25,34,25,46,82,25,94,103,26,25,35,26,45,83,26,93,103,27,25,36,27,44,84,27,92,103,28,24,38,28,44,84,28,90,104,29,24,39,29,43,85,29,89,104,30,23,40,30,42,86,30,88,105,31,23,41,31,42,86,31,87,105,32,22,106,33,22,106,34,22,106,35,21,107,36,21,107,37,21,107,38,20,108,39,20,108,40,19,109,41,19,109,42,19,109,43,18,110,44,18,110,45,18,110,46,17,111,47,17,111,48,17,111,49,17,111,50,16,112,51,16,112,52,16,112,53,15,113,54,15,113,55,15,113,56,15,113,57,14,114,58,14,114,59,14,114,60,14,114,61,13,115,62,13,115,63,13,115,64,13,115,65,13,115,66,12,116,67,12,116,68,12,116,69,12,116,70,12,116,71,12,116,72,11,117,73,11,117,74,11,117,75,11,117,76,11,117,77,11,117,78,11,117,79,11,117,80,11,117,81,11,117,82,11,117,83,11,117,84,11,117,85,11,116,86,12,116,87,12,116,88,13,115,89,13,115,90,14,114,91,15,113,92,15,113,93,16,112,94,17,111,95,18,110,96,19,109,97,20,108,98,21,107,99,22,106,100,23,105,101,24,104,102,25,103,103,27,101,104,28,100,105,29,99,106,30,98,107,32,96,108,33,95,109,35,93,110,36,92,111,38,90,112,39,89,113,41,87,114,43,85,115,44,84,116,46,82,117,48,80,118,50,78,119,52,76,120,54,74,121,56,72,122,59,69,123,63,65}
local LOGO_EYE = {62,28,29,62,99,100,63,28,30,63,98,100,64,28,31,64,97,100,65,28,32,65,96,100,66,27,33,66,95,101,67,27,34,67,94,101,68,27,36,68,92,101,69,27,37,69,91,101,70,27,38,70,90,101,71,27,39,71,89,101,72,28,40,72,88,100,73,28,41,73,87,100,74,28,42,74,86,100,75,28,44,75,84,100,76,28,45,76,83,100,77,28,46,77,82,100,78,28,47,78,81,100,79,29,48,79,80,99,80,29,49,80,79,99,81,29,50,81,78,99,82,30,52,82,76,98,83,30,53,83,75,98,84,30,54,84,74,98,85,31,55,85,73,97,86,32,56,86,72,96,87,32,55,87,73,96,88,33,54,88,74,95,89,34,53,89,75,94,90,35,52,90,76,93,91,36,50,91,78,92,92,38,49,92,79,90,93,41,46,93,82,87}

local function runIntro()
	local oldIntro = playerGui:FindFirstChild("VermilionHubIntro")
	if oldIntro then oldIntro:Destroy() end
	local oldBlur = Lighting:FindFirstChild("VermilionBlur")
	if oldBlur then oldBlur:Destroy() end

	local gui = make("ScreenGui", {
		Name = "VermilionHubIntro", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	restyleTree(gui)

	local INK = Color3.fromRGB(8, 8, 10)
	local VERM = Color3.fromRGB(242, 54, 45)
	local WHITE = Color3.fromRGB(242, 242, 245)
	local vp = workspace.CurrentCamera.ViewportSize
	local W = math.clamp(vp.X * 0.7, 240, 560)
	local H = W * 0.14
	local LS = math.min(H * 2.6, vp.Y * 0.32)
	local LOGO_Y = -H * 1.45
	local TITLE_Y = H * 0.95

	local function curtain(y, anchorY)
		return make("Frame", {
			AnchorPoint = Vector2.new(0, anchorY), Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = INK,
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1,
		}, gui)
	end
	local top, bottom = curtain(0, 0), curtain(1, 1)

	local stage = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H * 6), BackgroundTransparency = 1, ZIndex = 3,
	}, gui)

	local aura = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, LOGO_Y),
		Size = UDim2.fromOffset(LS * 0.5, LS * 0.5), BackgroundColor3 = VERM,
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
	}, stage)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, aura)

	local function ring(thick)
		local r = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, LOGO_Y),
			Size = UDim2.fromOffset(LS * 0.6, LS * 0.6), BackgroundTransparency = 1, ZIndex = 4,
		}, stage)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, r)
		return r, make("UIStroke", { Color = VERM, Thickness = thick, Transparency = 1 }, r)
	end
	local ring1, ring1s = ring(4)
	local ring2, ring2s = ring(2)

	-- radial light streaks that shoot out of the logo on impact
	local function streaks()
		local rng = Random.new()
		for n = 1, 20 do
			local ang = (n / 20) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local len = LS * rng:NextNumber(0.3, 0.8)
			local d0 = LS * 0.55
			local d1 = LS * rng:NextNumber(1.8, 3.4)
			local f = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(ang) * d0, 0.5, LOGO_Y + math.sin(ang) * d0),
				Size = UDim2.fromOffset(len, 2), Rotation = math.deg(ang),
				BackgroundColor3 = (n % 3 == 0) and WHITE or VERM,
				BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 4,
			}, stage)
			local life = 0.5 + rng:NextNumber(0, 0.35)
			tween(f, life, {
				Position = UDim2.new(0.5, math.cos(ang) * d1, 0.5, LOGO_Y + math.sin(ang) * d1),
				BackgroundTransparency = 1, Size = UDim2.fromOffset(len * 0.25, 1),
			}, Enum.EasingStyle.Quint)
			task.delay(life + 0.1, function() f:Destroy() end)
		end
	end

	-- ---------------------------------------------------------------
	-- LOGO: drawn in-engine from rows of rectangles (no upload needed)
	-- ---------------------------------------------------------------
	local logo = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, LOGO_Y),
		Size = UDim2.fromOffset(LS * 1.6, LS * 1.6), BackgroundTransparency = 1, ZIndex = 6,
	}, stage)
	local logoScale = make("UIScale", { Scale = 1 }, logo)
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LS, LS), BackgroundTransparency = 1, ZIndex = 6,
	}, logo)

	local rows, eyes = {}, {}
	local function addRows(list, out, color, z)
		for k = 1, #list, 3 do
			local y, x0, x1 = list[k], list[k + 1], list[k + 2]
			local f = make("Frame", {
				Position = UDim2.fromScale(x0 / LOGO_N, y / LOGO_N),
				Size = UDim2.fromScale((x1 - x0) / LOGO_N, 1.2 / LOGO_N),
				BackgroundColor3 = color, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z,
			}, holder)
			table.insert(out, { f = f, y = y, x0 = x0, dir = (y % 2 == 0) and -1 or 1, off = 0 })
		end
	end
	addRows(LOGO_RED, rows, VERM, 6)
	addRows(LOGO_EYE, eyes, Color3.new(0, 0, 0), 7)
	local function applyOffsets()
		for _, list in ipairs({ rows, eyes }) do
			for _, r in ipairs(list) do r.f.Position = UDim2.new(r.x0 / LOGO_N, r.off, r.y / LOGO_N, 0) end
		end
	end
	-- rows fly in from alternating sides, top to bottom, like a scan line building it
	local function assemble(duration)
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local t = os.clock() - t0
			for _, r in ipairs(rows) do
				local delay = (r.y / LOGO_N) * duration * 0.55
				local p = math.clamp((t - delay) / (duration * 0.45), 0, 1)
				local e = 1 - (1 - p) ^ 3
				r.off = r.dir * (1 - e) * LS * 1.3
				r.f.BackgroundTransparency = 1 - math.min(1, p * 4)
			end
			applyOffsets()
			RunService.Heartbeat:Wait()
		end
		for _, r in ipairs(rows) do r.off = 0 r.f.BackgroundTransparency = 0 end
		applyOffsets()
	end
	local function glitch(duration, amp)
		local rng = Random.new()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local k = 1 - (os.clock() - t0) / duration
			for _, list in ipairs({ rows, eyes }) do
				local band = 0
				for n, r in ipairs(list) do
					if n % 6 == 1 then band = rng:NextInteger(-1, 1) * amp * k * (rng:NextNumber() < 0.55 and 1 or 0) end
					r.off = band
				end
			end
			applyOffsets()
			RunService.Heartbeat:Wait()
		end
		for _, list in ipairs({ rows, eyes }) do for _, r in ipairs(list) do r.off = 0 end end
		applyOffsets()
	end
	local function openEyes()
		for _, flick in ipairs({ 0, 1, 0, 1, 0 }) do
			for _, e in ipairs(eyes) do e.f.BackgroundTransparency = flick end
			task.wait(0.05)
		end
	end

	-- ---------------------------------------------------------------
	-- TITLE: tech font, one letter at a time, red-hot cooling to white
	-- ---------------------------------------------------------------
	local TITLE_SIZE = math.max(16, math.floor(H * 0.68))
	local titleRow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, TITLE_Y),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 6,
	}, stage)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, titleRow)
	local letters = {}
	for n = 1, #CONFIG.Title do
		local l = make("TextLabel", {
			LayoutOrder = n, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(),
			BackgroundTransparency = 1, Text = CONFIG.Title:sub(n, n), TextSize = TITLE_SIZE,
			Font = Enum.Font.GothamBlack, TextColor3 = VERM, TextTransparency = 1, ZIndex = 6,
		}, titleRow)
		l.Font = CONFIG.TitleFont
		letters[n] = { l = l, sc = make("UIScale", { Scale = 2.2 }, l) }
	end
	local underline = glowFill(make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, TITLE_Y + H * 0.55),
		Size = UDim2.fromOffset(0, 2), BackgroundColor3 = VERM, BorderSizePixel = 0, ZIndex = 6,
	}, stage))

	local sub = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, -W * 0.25, 0.5, TITLE_Y + H * 0.78),
		Size = UDim2.fromOffset(W * 0.35, H * 0.26), BackgroundTransparency = 1, Font = Enum.Font.Code,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(135, 135, 143), TextTransparency = 1, Text = "", ZIndex = 6,
	}, stage)
	local pct = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, W * 0.25, 0.5, TITLE_Y + H * 0.78),
		Size = UDim2.fromOffset(W * 0.14, H * 0.26), BackgroundTransparency = 1, Font = Enum.Font.Code,
		TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = VERM, TextTransparency = 1, Text = "0%", ZIndex = 6,
	}, stage)
	local track = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, TITLE_Y + H * 1.12),
		Size = UDim2.fromOffset(W * 0.5, 3), BackgroundColor3 = Color3.fromRGB(34, 34, 40),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6,
	}, stage)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = glowFill(make("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = VERM, BorderSizePixel = 0, ZIndex = 7,
	}, track))
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

	local flash = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 238, 232),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30,
	}, gui)
	local blur = make("BlurEffect", { Name = "VermilionBlur", Size = 0 }, Lighting)

	-- ambient: embers rise from the bottom of the screen the whole time the intro runs
	task.spawn(function()
		local rng = Random.new()
		while gui.Parent do
			local s = rng:NextInteger(2, 5)
			local x = rng:NextNumber()
			local e = make("Frame", {
				Position = UDim2.fromScale(x, 1.02), Size = UDim2.fromOffset(s, s),
				BackgroundColor3 = (rng:NextNumber() < 0.25) and WHITE or VERM,
				BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2,
			}, gui)
			local life = rng:NextNumber(1.4, 2.8)
			tween(e, life, {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.08, 0.08), rng:NextNumber(0.1, 0.6)),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Sine)
			task.delay(life + 0.1, function() e:Destroy() end)
			task.wait(0.04)
		end
	end)

	-- ambient: random title letters glitch red + tilt for a split second
	task.spawn(function()
		local rng = Random.new()
		while gui.Parent do
			task.wait(rng:NextNumber(0.15, 0.5))
			local L = letters[rng:NextInteger(1, #letters)]
			if L and L.l.Parent and L.l.TextTransparency < 0.5 then
				L.l.TextColor3 = VERM
				L.l.Rotation = rng:NextInteger(-6, 6)
				task.wait(0.06)
				if L.l.Parent then
					L.l.TextColor3 = WHITE
					L.l.Rotation = 0
				end
			end
		end
	end)

	-- 1) cut to black
	tween(top, 0.4, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	tween(bottom, 0.4, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine).Completed:Wait()
	task.wait(0.1)

	-- 2) logo assembles row by row while the glow swells
	tween(aura, 1.4, { Size = UDim2.fromOffset(LS * 2.2, LS * 2.2), BackgroundTransparency = 0.9 }, Enum.EasingStyle.Sine)
	assemble(0.95)

	-- 3) impact
	flash.BackgroundTransparency = 0.55
	tween(flash, 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
	streaks()
	-- scan line sweeps down the whole screen
	local scan = make("Frame", {
		Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromScale(0, -0.02),
		BackgroundColor3 = VERM, BorderSizePixel = 0, ZIndex = 20,
	}, gui)
	tween(scan, 0.6, { Position = UDim2.fromScale(0, 1.02), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	task.delay(0.7, function() scan:Destroy() end)
	logoScale.Scale = 1.14
	tween(logoScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	ring1s.Transparency = 0.05
	tween(ring1, 0.9, { Size = UDim2.fromOffset(LS * 4.4, LS * 4.4) }, Enum.EasingStyle.Quint)
	tween(ring1s, 0.9, { Transparency = 1, Thickness = 0.5 }, Enum.EasingStyle.Quint)
	task.delay(0.12, function()
		ring2s.Transparency = 0.3
		tween(ring2, 1, { Size = UDim2.fromOffset(LS * 5.8, LS * 5.8) }, Enum.EasingStyle.Quint)
		tween(ring2s, 1, { Transparency = 1, Thickness = 0.5 }, Enum.EasingStyle.Quint)
	end)
	tween(aura, 0.25, { BackgroundTransparency = 0.76 })
	task.spawn(function()
		local rng = Random.new()
		local t0 = os.clock()
		while os.clock() - t0 < 0.4 do
			local k = 1 - (os.clock() - t0) / 0.4
			stage.Position = UDim2.new(0.5, rng:NextInteger(-9, 9) * k, 0.5, rng:NextInteger(-9, 9) * k)
			RunService.Heartbeat:Wait()
		end
		stage.Position = UDim2.fromScale(0.5, 0.5)
	end)
	task.spawn(function() glitch(0.38, LS * 0.09) end)
	openEyes()
	tween(aura, 0.9, { BackgroundTransparency = 0.9 })

	-- 4) title: letters slam in one by one (big + red-hot -> normal + white)
	tween(underline, 0.9, { Size = UDim2.fromOffset(W * 0.92, 2) }, Enum.EasingStyle.Quint)
	for n, L in ipairs(letters) do
		task.delay((n - 1) * 0.055, function()
			tween(L.sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(L.l, 0.2, { TextTransparency = 0 })
			task.delay(0.12, function() tween(L.l, 0.55, { TextColor3 = WHITE }) end)
		end)
	end
	task.wait(#letters * 0.055 + 0.45)

	-- 5) loading: cycling status text, percent counter, eased bar
	local msgs = { "initializing core", "loading command modules", "syncing interface", CONFIG.Subtitle:lower() }
	tween(sub, 0.2, { TextTransparency = 0 })
	tween(pct, 0.2, { TextTransparency = 0 })
	track.BackgroundTransparency = 0
	tween(logoScale, CONFIG.HoldTime, { Scale = 1.05 }, Enum.EasingStyle.Sine)
	task.delay(CONFIG.HoldTime * 0.55, function() glitch(0.18, LS * 0.05) end)
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / CONFIG.HoldTime, 0, 1)
		local p = a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2
		fill.Size = UDim2.fromScale(p, 1)
		pct.Text = math.floor(p * 100) .. "%"
		local seg = math.min(#msgs, math.floor(a * #msgs) + 1)
		local within = a * #msgs - (seg - 1)
		local chars = math.clamp(math.floor(within * #msgs[seg] * 2.2), 0, #msgs[seg])
		sub.Text = msgs[seg]:sub(1, chars) .. ((chars < #msgs[seg]) and "_" or "")
		if a >= 1 then break end
		RunService.Heartbeat:Wait()
	end
	task.wait(0.15)

	-- 6) outro: letters scatter, logo tears and punches through in a whiteout, screen un-blurs as it opens
	for n, L in ipairs(letters) do
		task.delay((n - 1) * 0.03, function()
			tween(L.sc, 0.3, { Scale = 0.4 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			tween(L.l, 0.3, { TextTransparency = 1 })
		end)
	end
	tween(underline, 0.3, { Size = UDim2.fromOffset(0, 2) })
	tween(sub, 0.25, { TextTransparency = 1 })
	tween(pct, 0.25, { TextTransparency = 1 })
	tween(track, 0.25, { BackgroundTransparency = 1 })
	tween(fill, 0.25, { BackgroundTransparency = 1 })
	-- camera punch-in while the logo bursts through
	local camera = workspace.CurrentCamera
	local fov0 = camera.FieldOfView
	tween(camera, 0.5, { FieldOfView = fov0 + 25 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(0.55, function() tween(camera, 0.8, { FieldOfView = fov0 }, Enum.EasingStyle.Quint) end)
	glitch(0.28, LS * 0.14)
	tween(logoScale, 0.55, { Scale = 10 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(logo, 0.55, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(aura, 0.5, { BackgroundTransparency = 1 })
	tween(flash, 0.5, { BackgroundTransparency = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.5)
	blur.Size = 30
	tween(blur, 1, { Size = 0 }, Enum.EasingStyle.Quint)
	tween(flash, 0.5, { BackgroundTransparency = 1 })
	tween(top, 0.65, { Position = UDim2.fromScale(0, -0.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	tween(bottom, 0.65, { Position = UDim2.fromScale(0, 1.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut).Completed:Wait()

	gui:Destroy()
	task.delay(0.5, function() blur:Destroy() end)
end

local function playIntro()
	if playing then return end
	playing = true
	local ok, err = pcall(runIntro)
	if not ok then
		warn("[VermilionHub] Error: " .. tostring(err))
		local leftover = playerGui:FindFirstChild("VermilionHubIntro")
		if leftover then leftover:Destroy() end
	end
	playing = false

	-- animation ended -> run the command bar (only the first time)
	local ok2, err2 = pcall(loadCommandBar)
	if not ok2 then
		warn("[CommandBar] Error: " .. tostring(err2))
	end
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CONFIG.ReplayKey then
		task.spawn(playIntro)
	end
end)

if CONFIG.PlayOnJoin then
	task.wait(0.5)
	task.spawn(playIntro)
else
	task.spawn(function()
		local ok, err = pcall(loadCommandBar)
		if not ok then warn("[CommandBar] Error: " .. tostring(err)) end
	end)
end

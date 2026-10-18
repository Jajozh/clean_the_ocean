-- Строит остров v2 (хаб, 6 баз, берег, пальмы) и океан в Workspace. Идемпотентно: build() можно вызывать повторно.
-- В edit-режиме Studio require кэширует модуль: чтобы перестроить после правок, вызывай build() из Clone() модуля (у клона свой кэш).
-- Запуск: командная строка Studio, require(game.ReplicatedStorage.Shared.IslandBuilder):Clone() -> require(клон).build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Island)
local Layout = require(ReplicatedStorage.Shared.Layout).new(Config)
local Shape = require(ReplicatedStorage.Shared.IslandShape).new(Config, Layout)

local GROUND_Y = 2 -- верх песка (рельеф 0); Layout считает от y = 0, всё остальное стоит на этой высоте
local FLOOR_TOP_Y = GROUND_Y + 0.2 -- выше песка, иначе поверхности мерцают (z-fighting)
local SLOT_HEIGHT = 1 -- центр слота на уровне песка, верх на 0.5 выше
local SEABED_THICKNESS = 8
local WATER_TOP_Y = -2
local WALL_TOP_Y = 60
local WALL_THICKNESS = 4
local WATER_STRIP = 148 -- ширина полосы заливки воды по Z
local BARRIER_HEIGHT = 30

local FLOOR_COLOR = Color3.fromRGB(124, 92, 70)
local KIND_COLORS = {
	beach = Color3.fromRGB(226, 170, 100),
	grass = Color3.fromRGB(98, 150, 64),
	hill = Color3.fromRGB(70, 120, 50),
}
local TRUNK_COLOR = Color3.fromRGB(120, 80, 45)
local LEAF_COLOR = Color3.fromRGB(60, 150, 60)
local POST_COLOR = Color3.fromRGB(150, 110, 70)
local COUNTER_COLOR = Color3.fromRGB(235, 225, 200)
local PLATE_COLOR = Color3.fromRGB(170, 170, 170)
local ROOF_COLOR = Color3.fromRGB(245, 245, 245)
local STRIPE_RED = Color3.fromRGB(210, 50, 50)
local STRIPE_GREEN = Color3.fromRGB(60, 180, 80)

local SLOT_COLORS = {
	Showcase = Color3.fromRGB(150, 210, 255),
	ShowcaseButton = Color3.fromRGB(40, 90, 220),
	Aquarium = Color3.fromRGB(150, 80, 200),
	Recycler = Color3.fromRGB(210, 50, 50),
}

local SLOT_LABELS = {
	Showcase = "Витрина",
	ShowcaseButton = "Кнопка",
	Aquarium = "Аквариум",
	Recycler = "Переработка мусора",
}

local BUILDING_LABELS = { Shop = "Магазин", Upgrades = "Апгрейды" }

local NUMBERED = { Showcase = true, ShowcaseButton = true }

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.Anchored = true
	part.Parent = parent
	return part
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function addLabel(part: Part, text: string)
	-- Надпись на верхней грани самой модели, а не над ней.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	-- Верх грани Top повёрнут на 90° к взгляду с берега: крутим метку и меняем размеры местами.
	label.Rotation = 90
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(part.Size.Z / part.Size.X, part.Size.X / part.Size.Z)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- Надпись на передней (+Z) грани здания: у Part грань Back смотрит в +Z.
local function addFrontLabel(part: Part, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(40, 40, 40)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

local function cellOf(v: number): number
	return math.floor(v / Config.Cell)
end

local function groundTop(cx: number, cz: number, shape): number
	return GROUND_Y + shape:height(cx, cz) * Config.Relief.Step
end

local function buildLand(island: Folder)
	local land = folder("Land", island)
	local cell, step, thick = Config.Cell, Config.Relief.Step, Config.Island.Thickness
	local runs = Shape:runs()
	for _, r in runs do
		local top = GROUND_Y + r.height * step
		local sizeX = (r.cx1 - r.cx0 + 1) * cell
		local color = KIND_COLORS[r.kind]
		if r.kind == "hill" then
			-- Чем выше, тем светлее.
			color = color:Lerp(Color3.fromRGB(110, 160, 70), math.clamp(r.height / math.max(Config.Relief.MaxSteps, 1), 0, 1) * 0.5)
		end
		local part = makePart(
			r.kind,
			Vector3.new(sizeX, top + thick, cell),
			CFrame.new((r.cx0 + r.cx1 + 1) / 2 * cell, (top - thick) / 2, (r.cz + 0.5) * cell),
			color,
			land
		)
		part.TopSurface = Enum.SurfaceType.Studs
	end
	return #runs
end

local function buildBases(island: Folder)
	local bases = folder("Bases", island)
	local slots = Layout:baseSlots()
	for i = 1, Config.MaxPlayers do
		local model = Instance.new("Model")
		model.Name = "Base" .. i
		model:SetAttribute("BaseIndex", i)
		local rot = CFrame.Angles(0, Layout:baseYaw(i), 0)

		local bp = Layout:basePosition(i)
		makePart(
			"Floor",
			Vector3.new(Config.Base.Width, 1, Config.Base.Depth),
			CFrame.new(bp.x, FLOOR_TOP_Y - 0.5, bp.z) * rot,
			FLOOR_COLOR,
			model
		)

		local counters = {}
		for _, slot in slots do
			local wp = Layout:slotWorldPosition(i, slot)
			local part = makePart(
				slot.name,
				Vector3.new(slot.sizeX, SLOT_HEIGHT, slot.sizeZ),
				CFrame.new(wp.x, wp.y + GROUND_Y, wp.z) * rot,
				SLOT_COLORS[slot.slotType],
				model
			)
			part:SetAttribute("SlotType", slot.slotType)
			part:SetAttribute("BaseIndex", i)

			local text = SLOT_LABELS[slot.slotType]
			if NUMBERED[slot.slotType] then
				counters[slot.slotType] = (counters[slot.slotType] or 0) + 1
				text ..= " " .. counters[slot.slotType]
			end
			addLabel(part, text)
		end
		model.Parent = bases
	end
end

local function buildHub(island: Folder)
	local hub = folder("Hub", island)
	for _, b in Layout:hubBuildings() do
		local model = Instance.new("Model")
		model.Name = b.id
		model:SetAttribute("BuildingId", b.id)
		local base = groundTop(cellOf(b.x), cellOf(b.z), Shape) -- верх земли под зданием
		local front = b.z + b.sizeZ / 2

		makePart("Plate", Vector3.new(b.sizeX, 1, b.sizeZ), CFrame.new(b.x, base + 0.5, b.z), PLATE_COLOR, model)

		-- Прилавок у передней кромки плиты, на нём надпись.
		local counter = makePart(
			"Counter",
			Vector3.new(b.sizeX - 2, 3, 3),
			CFrame.new(b.x, base + 1 + 1.5, front - 2),
			COUNTER_COLOR,
			model
		)
		addFrontLabel(counter, BUILDING_LABELS[b.id] or b.id)

		-- Четыре столба по углам.
		local postH = 8
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				makePart(
					"Post",
					Vector3.new(1, postH, 1),
					CFrame.new(b.x + sx * (b.sizeX / 2 - 0.5), base + 1 + postH / 2, b.z + sz * (b.sizeZ / 2 - 0.5)),
					POST_COLOR,
					model
				)
			end
		end

		-- Крыша-навес и яркая полоса по переднему краю.
		local roofY = base + 1 + postH + 0.5
		local roofW = b.sizeX + 2
		makePart("Roof", Vector3.new(roofW, 1, b.sizeZ + 2), CFrame.new(b.x, roofY, b.z), ROOF_COLOR, model)
		local stripeY = roofY + 1
		if b.id == "Upgrades" then
			local n = math.floor(roofW / 2)
			for k = 0, n - 1 do
				makePart(
					"Stripe",
					Vector3.new(roofW / n, 1, 1),
					CFrame.new(b.x - roofW / 2 + (k + 0.5) * roofW / n, stripeY, front + 0.5),
					if k % 2 == 0 then STRIPE_RED else ROOF_COLOR,
					model
				)
			end
		else
			makePart(
				"Stripe",
				Vector3.new(roofW, 1, 1),
				CFrame.new(b.x, stripeY, front + 0.5),
				STRIPE_GREEN,
				model
			)
		end
		model.Parent = hub
	end
end

local function buildSpawns(island: Folder)
	local spawns = folder("Spawns", island)
	for i = 1, Config.MaxPlayers do
		local sp = Layout:spawnPosition(i)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(sp.x, sp.y + GROUND_Y + 0.5, sp.z) * CFrame.Angles(0, Layout:baseYaw(i), 0)
		spawn.Neutral = true
		spawn.Anchored = true
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Material = Enum.Material.Plastic
		spawn.Color = Color3.fromRGB(255, 255, 255)
		spawn.Parent = spawns
		for _, child in spawn:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
end

local function buildPalms(island: Folder)
	local palms = folder("Palms", island)
	local list = Shape:palms()
	for i, p in list do
		local y0 = groundTop(cellOf(p.x), cellOf(p.z), Shape)
		local yaw = (i * 53 % 360) * math.pi / 180 -- детерминированный поворот
		local lean = (i % 3 - 1) * 0.5 -- наклон ствола, студов на блок
		local blocks = 3 + i % 2
		local scale = 1 + (i % 4) * 0.1
		local model = Instance.new("Model")
		model.Name = "Palm" .. i

		-- Локальные смещения считаем от основания и поворачиваем вокруг него.
		local origin = CFrame.new(p.x, y0, p.z) * CFrame.Angles(0, yaw, 0)
		local function put(name: string, size: Vector3, off: Vector3, color: Color3, collide: boolean)
			local part = makePart(name, size, origin * CFrame.new(off), color, model)
			part.CanCollide = collide
		end

		local trunkH = 3 * scale
		for k = 0, blocks - 1 do
			put("Trunk", Vector3.new(2, trunkH, 2), Vector3.new(lean * k, trunkH * (k + 0.5), 0), TRUNK_COLOR, true)
		end
		local topY = trunkH * blocks
		local cx = lean * (blocks - 1)
		-- Крона крестом: четыре листа, слегка опущенных к краям, и верхний блок.
		put("Leaf", Vector3.new(4, 1, 2), Vector3.new(cx + 3, topY + 0.5, 0), LEAF_COLOR, false)
		put("Leaf", Vector3.new(4, 1, 2), Vector3.new(cx - 3, topY + 0.5, 0), LEAF_COLOR, false)
		put("Leaf", Vector3.new(2, 1, 4), Vector3.new(cx, topY + 0.5, 3), LEAF_COLOR, false)
		put("Leaf", Vector3.new(2, 1, 4), Vector3.new(cx, topY + 0.5, -3), LEAF_COLOR, false)
		put("LeafTop", Vector3.new(3, 1, 3), Vector3.new(cx, topY + 1.5, 0), LEAF_COLOR, false)
		model.Parent = palms
	end
	return #list
end

local function buildBarrier(island: Folder)
	local barrier = folder("Barrier", island)
	local cell = Config.Cell
	-- Группируем клетки по строке и склеиваем соседние по cx.
	local rows: { [number]: { number } } = {}
	for _, c in Shape:barrierCells() do
		rows[c.cz] = rows[c.cz] or {}
		table.insert(rows[c.cz], c.cx)
	end
	local function wall(cz: number, cx0: number, cx1: number)
		-- Высоту берём по самой высокой клетке прогона.
		local top = GROUND_Y
		for cx = cx0, cx1 do
			top = math.max(top, groundTop(cx, cz, Shape))
		end
		local w = makePart(
			"Barrier",
			Vector3.new((cx1 - cx0 + 1) * cell, BARRIER_HEIGHT, cell),
			CFrame.new((cx0 + cx1 + 1) / 2 * cell, top + BARRIER_HEIGHT / 2, (cz + 0.5) * cell),
			Color3.new(1, 1, 1),
			barrier
		)
		w.Transparency = 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
	end
	for cz, xs in rows do
		table.sort(xs)
		local start, prev = xs[1], xs[1]
		for k = 2, #xs do
			if xs[k] ~= prev + 1 then
				wall(cz, start, prev)
				start = xs[k]
			end
			prev = xs[k]
		end
		wall(cz, start, prev)
	end
end

local function buildOcean()
	local oc = Config.Ocean
	local ocean = folder("Ocean", workspace)
	local minX, maxX = -oc.Half, oc.Half
	local minZ, maxZ = Config.Hub.z - oc.Half, Config.Hub.z + oc.Half
	local y0 = -oc.Depth
	local wallH = WALL_TOP_Y - y0
	local wallCY = (WALL_TOP_Y + y0) / 2
	local t = WALL_THICKNESS

	local function wall(name: string, sx: number, sz: number, cx: number, cz: number)
		local w = makePart(name, Vector3.new(sx, wallH, sz), CFrame.new(cx, wallCY, cz), Color3.new(1, 1, 1), ocean)
		w.Transparency = 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
	end
	-- Стены снаружи периметра квадрата воды.
	wall("WallWest", t, maxZ - minZ + 2 * t, minX - t / 2, (minZ + maxZ) / 2)
	wall("WallEast", t, maxZ - minZ + 2 * t, maxX + t / 2, (minZ + maxZ) / 2)
	wall("WallNorth", maxX - minX, t, 0, minZ - t / 2)
	wall("WallSouth", maxX - minX, t, 0, maxZ + t / 2)

	-- Вода и дно полосами по Z, чтобы не вешать Studio. FillBlock(cframe, size, material).
	local terrain = workspace.Terrain
	local width = maxX - minX
	local waterH = WATER_TOP_Y - y0
	local z = minZ
	while z < maxZ do
		local len = math.min(WATER_STRIP, maxZ - z)
		local cz = z + len / 2
		terrain:FillBlock(CFrame.new(0, (WATER_TOP_Y + y0) / 2, cz), Vector3.new(width, waterH, len), Enum.Material.Water)
		terrain:FillBlock(
			CFrame.new(0, y0 - SEABED_THICKNESS / 2, cz),
			Vector3.new(width, SEABED_THICKNESS, len),
			Enum.Material.Sand
		)
		z += len
		task.wait()
	end
end

local function countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function build()
	local started = os.clock()

	-- Идемпотентность: убираем старое и шаблонные Baseplate/SpawnLocation.
	for _, name in { "Island", "Ocean", "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	workspace.Terrain:Clear()

	local island = Instance.new("Folder")
	island.Name = "Island"
	local landRuns = buildLand(island)
	buildBases(island)
	buildHub(island)
	buildSpawns(island)
	local palmCount = buildPalms(island)
	buildBarrier(island)
	island.Parent = workspace

	buildOcean()

	local parts = countParts(island) + countParts(workspace:FindFirstChild("Ocean"))
	return { parts = parts, seconds = os.clock() - started, landRuns = landRuns, palms = palmCount }
end

return { build = build }

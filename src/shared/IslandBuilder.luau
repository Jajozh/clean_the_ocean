-- Строит остров v3 (хаб, 6 баз по дуге, плавательная зона, горы и пальмы за ней) и океан в Workspace. Идемпотентно.
-- В edit-режиме Studio require кэширует модуль: чтобы перестроить после правок, клонируй всю папку Shared и вызови require(клон.IslandBuilder).build()
-- Зависимости берём рядом с модулем (script.Parent), а не по пути ReplicatedStorage.Shared:
-- тогда клон всей папки Shared целиком получает свежий кэш require.
local Shared = script.Parent

local Config = require(Shared.Config.Island)
local Layout = require(Shared.Layout).new(Config)
local Shape = require(Shared.IslandShape).new(Config, Layout)

local GROUND_Y = 2 -- верх песка (суша плоская); Layout считает от y = 0, всё остальное стоит на этой высоте
local FLOOR_TOP_Y = GROUND_Y + 0.2 -- выше песка, иначе поверхности мерцают (z-fighting)
local SLOT_HEIGHT = 1 -- центр слота на уровне песка, верх на 0.5 выше
local SEABED_THICKNESS = 8
local WATER_TOP_Y = -2
local WALL_TOP_Y = 60
local WALL_THICKNESS = 4
local WATER_STRIP = 150 -- ширина полосы заливки воды по Z
local BARRIER_HEIGHT = 40 -- стены по суше

local SAND_COLOR = Color3.fromRGB(232, 190, 110)
local FLOOR_COLOR = Color3.fromRGB(124, 92, 70)
local TRUNK_COLOR = Color3.fromRGB(120, 80, 45)
local LEAF_COLOR = Color3.fromRGB(60, 150, 60)
local ROCK_DARK = Color3.fromRGB(120, 105, 95)
local ROCK_LIGHT = Color3.fromRGB(150, 140, 130)
local SNOW_COLOR = Color3.fromRGB(245, 247, 250)
local SNOW_HEIGHT = 40 -- от этой высоты горы со снежной шапкой
local BARRIER_DEBUG_COLOR = Color3.fromRGB(255, 40, 40)
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
		local base = GROUND_Y -- верх земли под зданием
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

local function buildLand(island: Folder)
	local land = folder("Land", island)
	local cell, thick = Config.Cell, Config.Island.Thickness
	local runs = Shape:runs()
	for _, r in runs do
		local part = makePart(
			"Sand",
			Vector3.new((r.cx1 - r.cx0 + 1) * cell, GROUND_Y + thick, cell),
			CFrame.new((r.cx0 + r.cx1 + 1) / 2 * cell, (GROUND_Y - thick) / 2, (r.cz + 0.5) * cell),
			SAND_COLOR,
			land
		)
		part.TopSurface = Enum.SurfaceType.Studs
	end
	return #runs
end

local function decor(part: Part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function buildMountains(island: Folder)
	local folderM = folder("Mountains", island)
	local list = Shape:mountains()
	for i, m in list do
		local tiers = if m.height < 20 then 3 elseif m.height < 40 then 4 else 5
		local tierH = m.height / tiers
		local yaw = (i * 37 % 90) * math.pi / 180 -- детерминированный поворот
		local aspect = 0.75 + (i % 4) * 0.08 -- глубина относительно ширины
		local shade = ((i * 7) % 5 - 2) * 0.03
		local model = Instance.new("Model")
		model.Name = "Mountain" .. i
		local origin = CFrame.new(m.x, GROUND_Y, m.z) * CFrame.Angles(0, yaw, 0)
		for k = 0, tiers - 1 do
			local w = math.max(m.base * (1 - 0.8 * k / tiers), 4)
			local color = ROCK_DARK:Lerp(ROCK_LIGHT, math.clamp(k / (tiers - 1) + shade, 0, 1))
			if k == tiers - 1 and m.height >= SNOW_HEIGHT then
				color = SNOW_COLOR
			end
			local part = makePart(
				"Tier" .. (k + 1),
				Vector3.new(w, tierH, w * aspect),
				origin * CFrame.new(0, tierH * (k + 0.5), 0),
				color,
				model
			)
			decor(part)
		end
		model.Parent = folderM
	end
	return #list
end

local function buildPalms(island: Folder)
	local palms = folder("Palms", island)
	local list = Shape:palms()
	for i, p in list do
		local blocks = 3 + i % 2
		local scale = 1 + (i % 4) * 0.1
		local model = Instance.new("Model")
		model.Name = "Palm" .. i
		local origin = CFrame.new(p.x, GROUND_Y, p.z)
		local function put(name: string, size: Vector3, off: Vector3, color: Color3)
			decor(makePart(name, size, origin * CFrame.new(off), color, model))
		end

		local trunkH = 3 * scale
		for k = 0, blocks - 1 do
			put("Trunk", Vector3.new(3, trunkH, 3), Vector3.new(0, trunkH * (k + 0.5), 0), TRUNK_COLOR)
		end
		local topY = trunkH * blocks
		-- Крона: четыре листа крестом и верхний блок.
		put("Leaf", Vector3.new(4, 1, 3), Vector3.new(3.5, topY + 0.5, 0), LEAF_COLOR)
		put("Leaf", Vector3.new(4, 1, 3), Vector3.new(-3.5, topY + 0.5, 0), LEAF_COLOR)
		put("Leaf", Vector3.new(3, 1, 4), Vector3.new(0, topY + 0.5, 3.5), LEAF_COLOR)
		put("Leaf", Vector3.new(3, 1, 4), Vector3.new(0, topY + 0.5, -3.5), LEAF_COLOR)
		put("LeafTop", Vector3.new(3, 1, 3), Vector3.new(0, topY + 1.5, 0), LEAF_COLOR)
		model.Parent = palms
	end
	return #list
end

local function buildBarrier(island: Folder, showBarriers: boolean)
	local barrier = folder("Barrier", island)
	local cell, t = Config.Cell, WALL_THICKNESS
	local y0 = -Config.Ocean.Depth

	local function wall(name: string, size: Vector3, cf: CFrame)
		local w = makePart(name, size, cf, if showBarriers then BARRIER_DEBUG_COLOR else Color3.new(1, 1, 1), barrier)
		w.Transparency = if showBarriers then 0.6 else 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
	end

	-- Стены по клеткам: соседние клетки одной строки склеиваем в один Part.
	local rows: { [number]: { number } } = {}
	for _, c in Shape:barrierCells() do
		rows[c.cz] = rows[c.cz] or {}
		table.insert(rows[c.cz], c.cx)
	end
	local function cellWall(cz: number, cx0: number, cx1: number)
		wall(
			"Barrier",
			Vector3.new((cx1 - cx0 + 1) * cell, BARRIER_HEIGHT, cell),
			CFrame.new((cx0 + cx1 + 1) / 2 * cell, GROUND_Y + BARRIER_HEIGHT / 2, (cz + 0.5) * cell)
		)
	end
	for cz, xs in rows do
		table.sort(xs)
		local start, prev = xs[1], xs[1]
		for k = 2, #xs do
			if xs[k] ~= prev + 1 then
				cellWall(cz, start, prev)
				start = xs[k]
			end
			prev = xs[k]
		end
		cellWall(cz, start, prev)
	end

	-- Стены вокруг плавательной зоны снаружи прямоугольника; север открыт.
	local s = Layout:swim()
	local h = WALL_TOP_Y - y0
	local cy = (WALL_TOP_Y + y0) / 2
	local midZ = (s.minZ + s.maxZ + t) / 2
	local lenZ = s.maxZ - s.minZ + t
	wall("SwimWest", Vector3.new(t, h, lenZ), CFrame.new(s.minX - t / 2, cy, midZ))
	wall("SwimEast", Vector3.new(t, h, lenZ), CFrame.new(s.maxX + t / 2, cy, midZ))
	wall("SwimSouth", Vector3.new(s.maxX - s.minX + 2 * t, h, t), CFrame.new((s.minX + s.maxX) / 2, cy, s.maxZ + t / 2))
end

local function buildOcean()
	local oc = Config.Ocean
	local ocean = folder("Ocean", workspace)
	local cz0 = Config.Island.CenterZ
	local minX, maxX = -oc.Half, oc.Half
	local minZ, maxZ = cz0 - oc.Half, cz0 + oc.Half
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

local function build(options: { showBarriers: boolean? }?)
	local started = os.clock()
	local showBarriers = options ~= nil and options.showBarriers == true

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
	local mountainCount = buildMountains(island)
	local palmCount = buildPalms(island)
	buildBarrier(island, showBarriers)
	island.Parent = workspace

	buildOcean()

	local barriers = #island.Barrier:GetChildren()
	local parts = countParts(island) + countParts(workspace:FindFirstChild("Ocean"))
	return {
		parts = parts,
		seconds = os.clock() - started,
		landRuns = landRuns,
		palms = palmCount,
		mountains = mountainCount,
		barriers = barriers,
	}
end

return { build = build }

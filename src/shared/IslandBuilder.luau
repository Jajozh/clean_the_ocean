-- Строит остров, 6 баз и океан в Workspace. Идемпотентно: build() можно вызывать повторно.
-- Запуск в edit-режиме: командная строка Studio, require(game.ReplicatedStorage.Shared.IslandBuilder).build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Island)
local Layout = require(ReplicatedStorage.Shared.Layout).new(Config)

local SAND_COLOR = Color3.fromRGB(226, 205, 150)
local FLOOR_COLOR = Color3.fromRGB(124, 92, 70)
local GROUND_Y = 2 -- верх песка; Layout считает от y = 0, всё остальное стоит на этой высоте
local FLOOR_TOP_Y = GROUND_Y + 0.2 -- выше песка, иначе поверхности мерцают (z-fighting)
local SEABED_THICKNESS = 8
local WATER_TOP_Y = -2
local WALL_TOP_Y = 60
local WALL_THICKNESS = 4
local SLOT_HEIGHT = 1 -- центр слота на уровне песка, верх на 0.5 выше

local SLOT_COLORS = {
	Showcase = Color3.fromRGB(150, 210, 255),
	ShowcaseButton = Color3.fromRGB(40, 90, 220),
	Aquarium = Color3.fromRGB(150, 80, 200),
	Recycler = Color3.fromRGB(210, 50, 50),
	Shop = Color3.fromRGB(60, 180, 80),
}

local SLOT_LABELS = {
	Showcase = "Витрина",
	ShowcaseButton = "Кнопка",
	Aquarium = "Аквариум",
	Recycler = "Переработка мусора",
	Shop = "Магазин",
}

local NUMBERED = { Showcase = true, ShowcaseButton = true }

local function build()
	-- Идемпотентность: убираем старое при перезапуске.
	for _, name in { "Island", "Ocean" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	workspace.Terrain:Clear()

	local function makePart(name: string, size: Vector3, center: Vector3, color: Color3, parent: Instance): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = center
		part.Color = color
		part.Material = Enum.Material.Plastic
		part.Anchored = true
		part.Parent = parent
		return part
	end

	local function addLabel(part: Part, text: string)
		-- Надпись на верхней грани самой модели, а не над ней.
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Adornee = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = gui
		gui.Parent = part
	end

	local island = Instance.new("Folder")
	island.Name = "Island"

	-- Остров: сплошной блок до дна, верх на y = GROUND_Y.
	local isl = Config.Island
	local sand = makePart(
		"Sand",
		Vector3.new(isl.Width, isl.Thickness + GROUND_Y, isl.FrontZ - isl.BackZ),
		Vector3.new(0, (GROUND_Y - isl.Thickness) / 2, (isl.FrontZ + isl.BackZ) / 2),
		SAND_COLOR,
		island
	)
	sand.TopSurface = Enum.SurfaceType.Studs

	-- Базы.
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = island

	local slots = Layout:baseSlots()
	for i = 1, Config.MaxPlayers do
		local model = Instance.new("Model")
		model.Name = "Base" .. i
		model:SetAttribute("BaseIndex", i)

		local bp = Layout:basePosition(i)
		makePart(
			"Floor",
			Vector3.new(Config.Base.Width, 1, Config.Base.Depth),
			Vector3.new(bp.x, FLOOR_TOP_Y - 0.5, bp.z),
			FLOOR_COLOR,
			model
		)

		local counters = {}
		for _, slot in slots do
			local wp = Layout:slotWorldPosition(i, slot)
			local part = makePart(
				slot.name,
				Vector3.new(slot.sizeX, SLOT_HEIGHT, slot.sizeZ),
				Vector3.new(wp.x, wp.y + GROUND_Y, wp.z),
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

	-- Спавны.
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = island
	for i = 1, Config.MaxPlayers do
		local sp = Layout:spawnPosition(i)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(sp.x, sp.y + GROUND_Y + 0.5, sp.z)
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
	island.Parent = workspace

	-- Океан: стены-ограничители.
	local ocean = Instance.new("Folder")
	ocean.Name = "Ocean"

	local oc = Config.Ocean
	local halfW = isl.Width / 2
	local minZ = isl.BackZ
	local maxZ = isl.FrontZ + oc.Length
	local wallY0 = -oc.Depth
	local wallH = WALL_TOP_Y - wallY0
	local wallCY = (WALL_TOP_Y + wallY0) / 2

	local function wall(name: string, sx: number, sz: number, cx: number, cz: number)
		local w = makePart(name, Vector3.new(sx, wallH, sz), Vector3.new(cx, wallCY, cz), Color3.new(1, 1, 1), ocean)
		w.Transparency = 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
	end

	local lenZ = maxZ - minZ
	local midZ = (maxZ + minZ) / 2
	wall("WallLeft", WALL_THICKNESS, lenZ, -halfW - WALL_THICKNESS / 2, midZ)
	wall("WallRight", WALL_THICKNESS, lenZ, halfW + WALL_THICKNESS / 2, midZ)
	wall("WallBack", isl.Width + WALL_THICKNESS * 2, WALL_THICKNESS, 0, minZ - WALL_THICKNESS / 2)
	wall("WallFar", isl.Width + WALL_THICKNESS * 2, WALL_THICKNESS, 0, maxZ + WALL_THICKNESS / 2)
	ocean.Parent = workspace

	-- Вода и дно (Terrain). FillBlock(cframe, size, material).
	local terrain = workspace.Terrain
	local waterH = WATER_TOP_Y - wallY0
	terrain:FillBlock(
		CFrame.new(0, (WATER_TOP_Y + wallY0) / 2, isl.FrontZ + oc.Length / 2),
		Vector3.new(isl.Width, waterH, oc.Length),
		Enum.Material.Water
	)
	terrain:FillBlock(
		CFrame.new(0, wallY0 - SEABED_THICKNESS / 2, isl.FrontZ + oc.Length / 2),
		Vector3.new(isl.Width, SEABED_THICKNESS, oc.Length),
		Enum.Material.Sand
	)
end

return { build = build }

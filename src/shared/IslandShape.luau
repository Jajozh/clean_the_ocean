-- Чистая форма острова: радиальный контур вокруг хаба, пляж на юге, рельеф и пальмы на севере.
-- Без Roblox API и без random: всё считается от cfg.Seed.
local IslandShape = {}
IslandShape.__index = IslandShape

local LO, HI = -100, 99 -- диапазон индексов клеток (хватает с запасом)
local W = HI - LO + 1

local function smooth(a: number, b: number, x: number)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Детерминированное число 0..1 от целого n.
local function hash(seed: number, n: number)
	local v = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return v - math.floor(v)
end

local function key(cx: number, cz: number)
	return (cz - LO) * W + (cx - LO)
end

function IslandShape.new(cfg, layout)
	local self = setmetatable({}, IslandShape)
	local C, hub, seed = cfg.Cell, cfg.Hub, cfg.Seed
	local ph = {}
	for k = 1, 12 do
		ph[k] = hash(seed, k) * 2 * math.pi
	end
	local frontEdge = cfg.Arc.R + cfg.Base.Depth / 2
	local southR = frontEdge + cfg.Beach

	-- Радиус суши в направлении phi (радианы от +Z к +X).
	local function radius(phi: number)
		local m1 = (3 * math.sin(3 * phi + ph[1]) + 2.5 * math.sin(5 * phi + ph[2]) + 2 * math.sin(9 * phi + ph[3])) / 7.5
		local south = southR - 4 - 4 * m1
		local m2 = (0.5 * math.sin(4 * phi + ph[4]) + 0.35 * math.sin(7 * phi + ph[5]) + 0.25 * math.sin(11 * phi + ph[6])) / 1.1
		local north = 150 + 22 * m2
		local w = smooth(math.rad(100), math.rad(130), math.abs(phi))
		return south * (1 - w) + north * w
	end

	local land, height, kind = {}, {}, {}
	local list = {} -- клетки суши в порядке строк
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

	for cz = LO, HI do
		for cx = LO, HI do
			local x, z = (cx + 0.5) * C - hub.x, (cz + 0.5) * C - hub.z
			if math.sqrt(x * x + z * z) <= radius(math.atan2(x, z)) then
				local k = key(cx, cz)
				land[k] = true
				table.insert(list, { cx, cz })
				minX, maxX = math.min(minX, cx * C), math.max(maxX, (cx + 1) * C)
				minZ, maxZ = math.min(minZ, cz * C), math.max(maxZ, (cz + 1) * C)
				-- Сырая высота: только севернее хаба, растёт к северу и от шума.
				local h = 0
				local dz = -z
				if dz >= 50 then
					local wx, wz = x + hub.x, z + hub.z
					local noise = 1.2 * math.sin(wx * 0.05 + ph[7]) * math.sin(wz * 0.04 + ph[8]) + 0.6 * math.sin((wx + wz) * 0.09 + ph[9])
					h = math.clamp(math.floor((dz - 50) / 16 + noise + 0.5), 0, cfg.Relief.MaxSteps)
				end
				height[k] = h
			end
		end
	end

	-- Релаксация: соседи отличаются не более чем на 1 ступень (понижаем, пока не устоится).
	local changed = true
	while changed do
		changed = false
		for _, c in list do
			local cx, cz = c[1], c[2]
			local k = key(cx, cz)
			for _, n in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local nh = height[key(cx + n[1], cz + n[2])]
				if nh and height[k] > nh + 1 then
					height[k] = nh + 1
					changed = true
				end
			end
		end
	end

	for _, c in list do
		local cx, cz = c[1], c[2]
		local k = key(cx, cz)
		local x, z = (cx + 0.5) * C - hub.x, (cz + 0.5) * C - hub.z
		local sandy = math.sqrt(x * x + z * z) >= frontEdge - 4 and math.abs(math.atan2(x, z)) <= math.rad(105)
		kind[k] = if height[k] > 0 then "hill" elseif sandy then "beach" else "grass"
	end

	self.cfg, self.layout, self.C = cfg, layout, C
	self._land, self._height, self._kind, self._list = land, height, kind, list
	self._bounds = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
	self._seed, self._ph = seed, ph
	return self
end

function IslandShape:isLand(cx: number, cz: number)
	if cx < LO or cx > HI or cz < LO or cz > HI then
		return false
	end
	return self._land[key(cx, cz)] == true
end

function IslandShape:height(cx: number, cz: number)
	return self._height[key(cx, cz)] or 0
end

function IslandShape:kind(cx: number, cz: number)
	if cx < LO or cx > HI or cz < LO or cz > HI then
		return nil
	end
	return self._kind[key(cx, cz)]
end

function IslandShape:bounds()
	return self._bounds
end

-- Строковые прогоны одинаковых kind и height (кэш).
function IslandShape:runs()
	if self._runs then
		return self._runs
	end
	local runs, cur = {}, nil
	for _, c in self._list do
		local cx, cz = c[1], c[2]
		local kd, h = self:kind(cx, cz), self:height(cx, cz)
		if cur and cur.cz == cz and cur.cx1 + 1 == cx and cur.kind == kd and cur.height == h then
			cur.cx1 = cx
		else
			cur = { cz = cz, cx0 = cx, cx1 = cx, kind = kd, height = h }
			table.insert(runs, cur)
		end
	end
	self._runs = runs
	return runs
end

-- Кромка севернее хаба, не пляж.
function IslandShape:barrierCells()
	if self._barrier then
		return self._barrier
	end
	local out = {}
	for _, c in self._list do
		local cx, cz = c[1], c[2]
		if (cz + 0.5) * self.C < self.cfg.Hub.z and self:kind(cx, cz) ~= "beach" then
			if not (self:isLand(cx + 1, cz) and self:isLand(cx - 1, cz) and self:isLand(cx, cz + 1) and self:isLand(cx, cz - 1)) then
				table.insert(out, { cx = cx, cz = cz })
			end
		end
	end
	self._barrier = out
	return out
end

-- Пальмы: детерминированные кандидаты, жадный отбор с зазором 10 студов.
function IslandShape:palms()
	if self._palms then
		return self._palms
	end
	local cfg, C, layout = self.cfg, self.C, self.layout
	local b = self._bounds
	local hubB = layout:hubBuildings()
	local out = {}
	for n = 1, 1500 do
		local x = b.minX + hash(self._seed, n * 2 + 100) * (b.maxX - b.minX)
		local z = b.minZ + hash(self._seed, n * 2 + 101) * (b.maxZ - b.minZ)
		local cx, cz = math.floor(x / C), math.floor(z / C)
		local kd = self:kind(cx, cz)
		local ok = kd == "grass" or kd == "hill"
		-- Не у самой воды и не на базах (запас 4 студа).
		for dx = -1, 1 do
			for dz = -1, 1 do
				ok = ok and self:isLand(cx + dx, cz + dz)
			end
		end
		for i = 1, cfg.MaxPlayers do
			if not ok then
				break
			end
			local p, f = layout:basePosition(i), layout:baseFront(i)
			local u, v = (x - p.x) * f.z - (z - p.z) * f.x, (x - p.x) * f.x + (z - p.z) * f.z
			ok = not (math.abs(u) < cfg.Base.Width / 2 + 4 and math.abs(v) < cfg.Base.Depth / 2 + 4)
		end
		for _, hb in hubB do
			ok = ok and not (math.abs(x - hb.x) < hb.sizeX / 2 + 4 and math.abs(z - hb.z) < hb.sizeZ / 2 + 4)
		end
		for _, q in out do
			ok = ok and (x - q.x) ^ 2 + (z - q.z) ^ 2 >= 10 * 10
		end
		if ok then
			table.insert(out, { x = x, z = z })
		end
		if #out >= 60 then
			break
		end
	end
	self._palms = out
	return out
end

return IslandShape

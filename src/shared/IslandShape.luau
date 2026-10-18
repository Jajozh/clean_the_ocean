-- Чистая форма острова v3: эллипс с неровным краем, плавательная зона вырезана, ограда, горы и пальмы.
-- Без Roblox API и без random: всё считается от cfg.Seed.
local IslandShape = {}
IslandShape.__index = IslandShape

local LO, HI = -100, 99 -- диапазон индексов клеток (хватает с запасом)
local W = HI - LO + 1

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
	local C, seed, isl = cfg.Cell, cfg.Seed, cfg.Island
	local swim, F = layout:swim(), layout:focus()
	local ph = {}
	for k = 1, 4 do
		ph[k] = hash(seed, k) * 2 * math.pi
	end
	local freq, amp = { 3, 5, 8, 13 }, { 0.4, 0.3, 0.2, 0.1 }

	local function inSwim(x: number, z: number)
		return x >= swim.minX and x <= swim.maxX and z >= swim.minZ and z <= swim.maxZ
	end

	-- Суша по центру клетки: эллипс, радиус которого смещён шумом по углу (до Island.Noise студов).
	local function isLandAt(x: number, z: number)
		if inSwim(x, z) then
			return false
		end
		local u, v = x / isl.SemiX, (z - isl.CenterZ) / isl.SemiZ
		local t = math.atan2(v, u)
		local n = 0
		for k = 1, 4 do
			n += amp[k] * math.sin(freq[k] * t + ph[k])
		end
		local rloc = math.sqrt((isl.SemiX * math.cos(t)) ^ 2 + (isl.SemiZ * math.sin(t)) ^ 2)
		return math.sqrt(u * u + v * v) <= 1 + isl.Noise * n / rloc
	end

	local land, list = {}, {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for cz = LO, HI do
		for cx = LO, HI do
			if isLandAt((cx + 0.5) * C, (cz + 0.5) * C) then
				land[key(cx, cz)] = true
				table.insert(list, { cx, cz })
				minX, maxX = math.min(minX, cx * C), math.max(maxX, (cx + 1) * C)
				minZ, maxZ = math.min(minZ, cz * C), math.max(maxZ, (cz + 1) * C)
			end
		end
	end

	self.cfg, self.layout, self.C, self._seed = cfg, layout, C, seed
	self._land, self._list, self._swim, self._focus = land, list, swim, F
	self._bounds = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
	return self
end

function IslandShape:isLand(cx: number, cz: number)
	if cx < LO or cx > HI or cz < LO or cz > HI then
		return false
	end
	return self._land[key(cx, cz)] == true
end

function IslandShape:kind(cx: number, cz: number)
	return if self:isLand(cx, cz) then "sand" else nil
end

function IslandShape:bounds()
	return self._bounds
end

-- Строковые прогоны подряд идущей суши (кэш).
function IslandShape:runs()
	if self._runs then
		return self._runs
	end
	local runs, cur = {}, nil
	for _, c in self._list do
		local cx, cz = c[1], c[2]
		if cur and cur.cz == cz and cur.cx1 + 1 == cx then
			cur.cx1 = cx
		else
			cur = { cz = cz, cx0 = cx, cx1 = cx }
			table.insert(runs, cur)
		end
	end
	self._runs = runs
	return runs
end

function IslandShape:_dist(x: number, z: number)
	return math.sqrt((x - self._focus.x) ^ 2 + (z - self._focus.z) ^ 2)
end

-- Ограда: кольцо в 3 клетки вдоль RING и кромка внутри диска у воды, не относящейся к Swim.
function IslandShape:barrierCells()
	if self._barrier then
		return self._barrier
	end
	local C, s = self.C, self._swim
	local ring = self.cfg.Arc.R + self.cfg.Decor.Margin
	local out = {}
	for _, c in self._list do
		local cx, cz = c[1], c[2]
		local d = self:_dist((cx + 0.5) * C, (cz + 0.5) * C)
		local wall = d >= ring - C and d < ring + 2 * C
		if not wall and d < ring - C then
			for dx = -1, 1 do
				for dz = -1, 1 do
					if not self:isLand(cx + dx, cz + dz) then
						local x, z = (cx + dx + 0.5) * C, (cz + dz + 0.5) * C
						if not (x >= s.minX and x <= s.maxX and z >= s.minZ and z <= s.maxZ) then
							wall = true
						end
					end
				end
			end
		end
		if wall then
			table.insert(out, { cx = cx, cz = cz })
		end
	end
	self._barrier = out
	return out
end

-- Горы: кандидаты по северной кромке с дрожанием, жадный отбор без пересечений.
function IslandShape:mountains()
	if self._mountains then
		return self._mountains
	end
	local cfg, C, seed = self.cfg, self.C, self._seed
	local ring = cfg.Arc.R + cfg.Decor.Margin
	local b = self._bounds
	local want = cfg.Decor.Mountains
	local out = {}
	for n = 1, 600 do
		local base = 24 + math.floor(hash(seed, n * 5 + 200) * 25)
		local height = 20 + math.floor(hash(seed, n * 5 + 201) * 41)
		-- Ровная сетка по X (шаг по номеру кандидата) плюс дрожание, Z у северной кромки.
		local slot = (n - 1) % want
		local x = b.minX + (slot + 0.5 + (hash(seed, n * 5 + 202) - 0.5) * 0.6) * (b.maxX - b.minX) / want
		local z = b.minZ + hash(seed, n * 5 + 203) * 90
		local ok = self:_dist(x, z) - base / 2 >= ring
		for sx = -1, 1 do
			for sz = -1, 1 do
				ok = ok and self:isLand(math.floor((x + sx * base / 2) / C), math.floor((z + sz * base / 2) / C))
			end
		end
		for _, m in out do
			ok = ok and math.sqrt((x - m.x) ^ 2 + (z - m.z) ^ 2) >= (base + m.base) / 2
		end
		if ok then
			table.insert(out, { x = x, z = z, base = base, height = height })
			if #out >= want then
				break
			end
		end
	end
	self._mountains = out
	return out
end

-- Пальмы: кандидаты на декор-полосе, жадный отбор с зазором 8 студов.
function IslandShape:palms()
	if self._palms then
		return self._palms
	end
	local cfg, C, seed = self.cfg, self.C, self._seed
	local ring = cfg.Arc.R + cfg.Decor.Margin
	local b = self._bounds
	local mountains = self:mountains()
	local out = {}
	for n = 1, 3000 do
		local x = b.minX + hash(seed, n * 2 + 5000) * (b.maxX - b.minX)
		local z = b.minZ + hash(seed, n * 2 + 5001) * (b.maxZ - b.minZ)
		local cx, cz = math.floor(x / C), math.floor(z / C)
		local ok = self:_dist(x, z) >= ring + 6
		-- Не у самой воды: вся окрестность 3x3 клетки на суше.
		for dx = -1, 1 do
			for dz = -1, 1 do
				ok = ok and self:isLand(cx + dx, cz + dz)
			end
		end
		for _, m in mountains do
			ok = ok and math.sqrt((x - m.x) ^ 2 + (z - m.z) ^ 2) >= m.base / 2 + 3
		end
		for _, q in out do
			ok = ok and (x - q.x) ^ 2 + (z - q.z) ^ 2 >= 8 * 8
		end
		if ok then
			table.insert(out, { x = x, z = z })
			if #out >= cfg.Decor.Palms then
				break
			end
		end
	end
	self._palms = out
	return out
end

return IslandShape

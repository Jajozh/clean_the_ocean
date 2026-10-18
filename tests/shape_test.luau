-- Контракт формы острова: неровный контур, пляж перед базами, рельеф и пальмы за ними.
-- Клетка (cx, cz) покрывает x из [cx * Cell, (cx + 1) * Cell), z аналогично.
local harness = require("./harness")
local cfg = require("../src/shared/Config/Island")
local Layout = require("../src/shared/Layout")
local IslandShape = require("../src/shared/IslandShape")

local test = harness.test
local layout = Layout.new(cfg)
local shape = IslandShape.new(cfg, layout)
local C = cfg.Cell

local function cellOf(v: number)
	return math.floor(v / C)
end

local function landAt(s, x: number, z: number)
	return s:isLand(cellOf(x), cellOf(z))
end

-- Углы и центр прямоугольника базы в мировых координатах.
local function baseCorners(i: number)
	local p, f = layout:basePosition(i), layout:baseFront(i)
	local rx, rz = f.z, -f.x
	local w, d = cfg.Base.Width / 2, cfg.Base.Depth / 2
	local pts = { { p.x, p.z } }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(pts, { p.x + rx * w * sx + f.x * d * sz, p.z + rz * w * sx + f.z * d * sz })
		end
	end
	return pts
end

local function eachCell(fn)
	local b = shape:bounds()
	for cz = cellOf(b.minZ), cellOf(b.maxZ - 0.001) do
		for cx = cellOf(b.minX), cellOf(b.maxX - 0.001) do
			fn(cx, cz)
		end
	end
end

test("shape: deterministic for one seed, different for another", function()
	local again = IslandShape.new(cfg, layout)
	local other = table.clone(cfg)
	other.Seed = cfg.Seed + 1
	local third = IslandShape.new(other, layout)
	local diff = 0
	eachCell(function(cx, cz)
		assert(shape:isLand(cx, cz) == again:isLand(cx, cz), "not deterministic")
		if shape:isLand(cx, cz) ~= third:isLand(cx, cz) then
			diff += 1
		end
	end)
	assert(diff > 0, "seed does not change the outline")
end)

test("shape: hub, base corners, spawns and hub buildings are on land", function()
	assert(landAt(shape, cfg.Hub.x, cfg.Hub.z))
	for i = 1, cfg.MaxPlayers do
		for _, pt in baseCorners(i) do
			assert(landAt(shape, pt[1], pt[2]), ("base %d is off the island"):format(i))
		end
		local s = layout:spawnPosition(i)
		assert(landAt(shape, s.x, s.z), ("spawn %d is off the island"):format(i))
	end
	for _, b in layout:hubBuildings() do
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				assert(landAt(shape, b.x + sx * b.sizeX / 2, b.z + sz * b.sizeZ / 2), b.id .. " is off the island")
			end
		end
	end
end)

test("shape: water is close in front of every base (the beach is short)", function()
	for i = 1, cfg.MaxPlayers do
		local s, f = layout:spawnPosition(i), layout:baseFront(i)
		local d = 0
		while landAt(shape, s.x + f.x * d, s.z + f.z * d) do
			d += 1
			assert(d < 200, "no water in front of base " .. i)
		end
		assert(d >= 5 and d <= cfg.Beach - cfg.SpawnOffset + 8, ("base %d: water at %d studs"):format(i, d))
	end
end)

test("beach: cells right in front of every base are sand", function()
	for i = 1, cfg.MaxPlayers do
		local p, f = layout:basePosition(i), layout:baseFront(i)
		for d = 5, cfg.Beach - 8, 4 do
			local k = cfg.Base.Depth / 2 + d
			local x, z = p.x + f.x * k, p.z + f.z * k
			assert(shape:kind(cellOf(x), cellOf(z)) == "beach", ("base %d, %d studs ahead"):format(i, d))
		end
	end
end)

test("relief: stepped, walkable, only behind the hub", function()
	local hills, b = 0, shape:bounds()
	eachCell(function(cx, cz)
		if not shape:isLand(cx, cz) then
			assert(shape:kind(cx, cz) == nil)
			return
		end
		local h = shape:height(cx, cz)
		assert(h == math.floor(h) and h >= 0 and h <= cfg.Relief.MaxSteps, "bad height")
		assert((shape:kind(cx, cz) == "hill") == (h > 0), "kind/height mismatch")
		if h > 0 then
			hills += 1
			assert((cz + 0.5) * C < cfg.Hub.z, "relief south of the hub")
		end
		for _, n in { { 1, 0 }, { 0, 1 } } do
			if shape:isLand(cx + n[1], cz + n[2]) then
				assert(math.abs(shape:height(cx + n[1], cz + n[2]) - h) <= 1, "step is too tall")
			end
		end
	end)
	assert(hills >= 200, "too little relief: " .. hills)
	assert(b.minZ < cfg.Hub.z - 100, "island does not extend behind the hub")
end)

test("runs: row runs cover exactly the land, with the same kind and height", function()
	local seen = {}
	for _, r in shape:runs() do
		assert(r.cx1 >= r.cx0)
		for cx = r.cx0, r.cx1 do
			local key = cx .. "," .. r.cz
			assert(seen[key] == nil, "cell covered twice " .. key)
			seen[key] = true
			assert(shape:isLand(cx, r.cz), "run over water " .. key)
			assert(shape:kind(cx, r.cz) == r.kind and shape:height(cx, r.cz) == r.height, "run mismatch " .. key)
		end
	end
	local land = 0
	eachCell(function(cx, cz)
		if shape:isLand(cx, cz) then
			land += 1
			assert(seen[cx .. "," .. cz], "land cell not covered " .. cx .. "," .. cz)
		end
	end)
	local covered = 0
	for _ in seen do
		covered += 1
	end
	assert(covered == land)
end)

test("runs: merged, so far fewer parts than cells", function()
	local runs, cells = #shape:runs(), 0
	eachCell(function(cx, cz)
		if shape:isLand(cx, cz) then
			cells += 1
		end
	end)
	assert(runs * 6 < cells, ("%d runs for %d cells"):format(runs, cells))
end)

test("barrier: north rim only, never where one can dive from the beach", function()
	local cells = shape:barrierCells()
	assert(#cells >= 20)
	for _, c in cells do
		assert(shape:isLand(c.cx, c.cz), "barrier off land")
		local rim = false
		for _, n in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			rim = rim or not shape:isLand(c.cx + n[1], c.cz + n[2])
		end
		assert(rim, "barrier cell is not on the rim")
		assert(shape:kind(c.cx, c.cz) ~= "beach", "barrier on the beach")
	end
	for i = 1, cfg.MaxPlayers do
		local s = layout:spawnPosition(i)
		for _, c in cells do
			local dx, dz = (c.cx + 0.5) * C - s.x, (c.cz + 0.5) * C - s.z
			assert(dx * dx + dz * dz > 30 * 30, "barrier next to spawn " .. i)
		end
	end
end)

test("palms: on grass or hills, off the bases and hub buildings, not too close", function()
	local palms = shape:palms()
	assert(#palms >= 12, "too few palms: " .. #palms)
	for a = 1, #palms do
		local p = palms[a]
		assert(landAt(shape, p.x, p.z), "palm in water")
		assert(shape:kind(cellOf(p.x), cellOf(p.z)) ~= "beach", "palm on the beach")
		for i = 1, cfg.MaxPlayers do
			local b, f = layout:basePosition(i), layout:baseFront(i)
			local dx, dz = p.x - b.x, p.z - b.z
			local u, v = dx * f.z - dz * f.x, dx * f.x + dz * f.z -- локальные x, z базы
			assert(not (math.abs(u) < cfg.Base.Width / 2 + 2 and math.abs(v) < cfg.Base.Depth / 2 + 2), "palm on base " .. i)
		end
		for _, hb in layout:hubBuildings() do
			assert(not (math.abs(p.x - hb.x) < hb.sizeX / 2 + 2 and math.abs(p.z - hb.z) < hb.sizeZ / 2 + 2), "palm on " .. hb.id)
		end
		for c = a + 1, #palms do
			local dx, dz = p.x - palms[c].x, p.z - palms[c].z
			assert(dx * dx + dz * dz >= 8 * 8, "palms too close")
		end
	end
end)

test("island fits into the ocean with a margin", function()
	local b, o = shape:bounds(), cfg.Ocean.Half
	assert(b.minX >= -o + 100 and b.maxX <= o - 100)
	assert(b.minZ >= cfg.Hub.z - o + 100 and b.maxZ <= cfg.Hub.z + o - 100)
end)

return true

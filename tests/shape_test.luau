-- Контракт формы острова v3: неровный эллипс, плавательная зона вырезана, ограда замыкает игровую часть,
-- за ней декор (горы, пальмы). Клетка (cx, cz) покрывает x из [cx * Cell, (cx + 1) * Cell), z аналогично.
local harness = require("./harness")
local cfg = require("../src/shared/Config/Island")
local Layout = require("../src/shared/Layout")
local IslandShape = require("../src/shared/IslandShape")

local test = harness.test
local layout = Layout.new(cfg)
local shape = IslandShape.new(cfg, layout)
local C = cfg.Cell
local RING = cfg.Arc.R + cfg.Decor.Margin -- радиус ограды вокруг F

local F = { x = cfg.Hub.x, z = cfg.Hub.z + cfg.Arc.R }

local function cellOf(v: number)
	return math.floor(v / C)
end

local function center(c: number)
	return (c + 0.5) * C
end

local function inSwim(x: number, z: number)
	local w = layout:swim()
	return x >= w.minX and x <= w.maxX and z >= w.minZ and z <= w.maxZ
end

local function distF(x: number, z: number)
	return math.sqrt((x - F.x) ^ 2 + (z - F.z) ^ 2)
end

local function landAt(x: number, z: number)
	return shape:isLand(cellOf(x), cellOf(z))
end

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

local function landCount()
	local n = 0
	eachCell(function(cx, cz)
		if shape:isLand(cx, cz) then
			n += 1
		end
	end)
	return n
end

local function ellipseHas(cx: number, cz: number)
	local i = cfg.Island
	return ((center(cx)) / i.SemiX) ^ 2 + ((center(cz) - i.CenterZ) / i.SemiZ) ^ 2 <= 1
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

test("shape: ragged edge, but still an ellipse (outside the swim zone)", function()
	local diff, ell = 0, 0
	eachCell(function(cx, cz)
		if inSwim(center(cx), center(cz)) then
			return
		end
		local land, inEllipse = shape:isLand(cx, cz), ellipseHas(cx, cz)
		if inEllipse then
			ell += 1
		end
		if land ~= inEllipse then
			diff += 1
		end
	end)
	assert(diff >= 40, "edge is too smooth: " .. diff)
	assert(diff <= ell * 0.15, "edge is too wild: " .. diff)
end)

test("shape: kind is sand on land, nil on water", function()
	eachCell(function(cx, cz)
		assert(shape:kind(cx, cz) == (if shape:isLand(cx, cz) then "sand" else nil))
	end)
end)

test("shape: the swim zone is carved out of the island", function()
	eachCell(function(cx, cz)
		if inSwim(center(cx), center(cz)) then
			assert(not shape:isLand(cx, cz), ("land in the swim zone at %d,%d"):format(cx, cz))
		end
	end)
end)

test("shape: hub, base corners, spawns and hub buildings are on land", function()
	assert(landAt(cfg.Hub.x, cfg.Hub.z))
	for i = 1, cfg.MaxPlayers do
		for _, pt in baseCorners(i) do
			assert(landAt(pt[1], pt[2]), ("base %d is off the island"):format(i))
		end
		local s = layout:spawnPosition(i)
		assert(landAt(s.x, s.z), ("spawn %d is off the island"):format(i))
	end
	for _, b in layout:hubBuildings() do
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				assert(landAt(b.x + sx * b.sizeX / 2, b.z + sz * b.sizeZ / 2), b.id .. " is off the island")
			end
		end
	end
end)

test("shape: walking forward from a spawn stays on land until the swim zone", function()
	for i = 1, cfg.MaxPlayers do
		local s, f = layout:spawnPosition(i), layout:baseFront(i)
		local d = 0
		while not inSwim(s.x + f.x * d, s.z + f.z * d) do
			assert(landAt(s.x + f.x * d, s.z + f.z * d), ("base %d: water that is not the swim zone, %d studs ahead"):format(i, d))
			d += 1
			assert(d < 200)
		end
	end
end)

test("runs: row runs cover exactly the land", function()
	local seen = {}
	for _, r in shape:runs() do
		assert(r.cx1 >= r.cx0)
		for cx = r.cx0, r.cx1 do
			local key = cx .. "," .. r.cz
			assert(seen[key] == nil, "cell covered twice " .. key)
			seen[key] = true
			assert(shape:isLand(cx, r.cz), "run over water " .. key)
		end
	end
	local covered = 0
	for _ in seen do
		covered += 1
	end
	eachCell(function(cx, cz)
		if shape:isLand(cx, cz) then
			assert(seen[cx .. "," .. cz], "land cell not covered " .. cx .. "," .. cz)
		end
	end)
	assert(covered == landCount())
end)

test("runs: merged, so far fewer parts than cells", function()
	assert(#shape:runs() * 10 < landCount())
end)

test("barrier: cells are land and not on the player's side of anything", function()
	local cells = shape:barrierCells()
	assert(#cells >= 30, "too few barrier cells: " .. #cells)
	for _, c in cells do
		assert(shape:isLand(c.cx, c.cz), "barrier off land")
	end
	for i = 1, cfg.MaxPlayers do
		local s = layout:spawnPosition(i)
		for _, c in cells do
			local dx, dz = center(c.cx) - s.x, center(c.cz) - s.z
			assert(dx * dx + dz * dz > 30 * 30, "barrier next to spawn " .. i)
		end
	end
end)

test("barrier: playable land is sealed (8-neighbour flood from the hub)", function()
	local wall = {}
	for _, c in shape:barrierCells() do
		wall[c.cx .. "," .. c.cz] = true
	end
	local start = { cellOf(cfg.Hub.x), cellOf(cfg.Hub.z) }
	assert(shape:isLand(start[1], start[2]) and not wall[start[1] .. "," .. start[2]])
	local seen, queue, n = { [start[1] .. "," .. start[2]] = true }, { start }, 0
	local head = 1
	while head <= #queue do
		local cx, cz = queue[head][1], queue[head][2]
		head += 1
		n += 1
		assert(distF(center(cx), center(cz)) <= RING + 2 * C, "flood escaped behind the ring wall")
		for dx = -1, 1 do
			for dz = -1, 1 do
				local nx, nz = cx + dx, cz + dz
				if not (dx == 0 and dz == 0) then
					if shape:isLand(nx, nz) then
						local key = nx .. "," .. nz
						if not wall[key] and not seen[key] then
							seen[key] = true
							table.insert(queue, { nx, nz })
						end
					else
						assert(inSwim(center(nx), center(nz)), ("playable land borders foreign water at %d,%d"):format(cx, cz))
					end
				end
			end
		end
	end
	for i = 1, cfg.MaxPlayers do
		local s = layout:spawnPosition(i)
		assert(seen[cellOf(s.x) .. "," .. cellOf(s.z)], "spawn " .. i .. " is not reachable from the hub")
	end
	assert(n > 1000, "playable area is tiny: " .. n)
end)

test("mountains: decor behind the ring wall, on land, not overlapping", function()
	local list = shape:mountains()
	assert(#list >= 8, "too few mountains: " .. #list)
	for a = 1, #list do
		local m = list[a]
		assert(m.base >= 24 and m.base <= 48 and m.height >= 20 and m.height <= 60, "bad mountain size")
		assert(distF(m.x, m.z) - m.base / 2 >= RING, "mountain in front of the ring wall")
		for _, sx in { -1, 0, 1 } do
			for _, sz in { -1, 0, 1 } do
				assert(landAt(m.x + sx * m.base / 2, m.z + sz * m.base / 2), "mountain hangs over the water")
			end
		end
		for b = a + 1, #list do
			local dx, dz = m.x - list[b].x, m.z - list[b].z
			assert(math.sqrt(dx * dx + dz * dz) >= (m.base + list[b].base) / 2, "mountains overlap")
		end
	end
end)

test("palms: decor behind the ring wall, on land, apart from each other and from mountains", function()
	local palms, mountains = shape:palms(), shape:mountains()
	assert(#palms >= 20, "too few palms: " .. #palms)
	for a = 1, #palms do
		local p = palms[a]
		assert(landAt(p.x, p.z), "palm in water")
		assert(distF(p.x, p.z) >= RING + 6, "palm in front of the ring wall")
		for b = a + 1, #palms do
			local dx, dz = p.x - palms[b].x, p.z - palms[b].z
			assert(dx * dx + dz * dz >= 8 * 8, "palms too close")
		end
		for _, m in mountains do
			local dx, dz = p.x - m.x, p.z - m.z
			assert(math.sqrt(dx * dx + dz * dz) >= m.base / 2 + 3, "palm inside a mountain")
		end
	end
end)

test("island and swim zone fit into the ocean square with a margin", function()
	local b, o = shape:bounds(), cfg.Ocean.Half
	local cz = cfg.Island.CenterZ
	assert(b.minX >= -o + 100 and b.maxX <= o - 100)
	assert(b.minZ >= cz - o + 100 and b.maxZ <= cz + o - 100)
	local w = layout:swim()
	assert(w.minX >= -o + 100 and w.maxX <= o - 100 and w.minZ >= cz - o + 100 and w.maxZ <= cz + o - 100)
end)

return true

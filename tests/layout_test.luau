-- Контракт раскладки острова и базы. Layout не использует Roblox API,
-- поэтому тесты запускаются обычным `luau tests/run.luau`.
local harness = require("./harness")
local cfg = require("../src/shared/Config/Island")
local Layout = require("../src/shared/Layout")

local test = harness.test
local layout = Layout.new(cfg)

local function slotsByName()
	local map = {}
	for _, s in layout:baseSlots() do
		assert(map[s.name] == nil, "duplicate slot name " .. s.name)
		map[s.name] = s
	end
	return map
end

local function count(slotType: string)
	local n = 0
	for _, s in layout:baseSlots() do
		if s.slotType == slotType then
			n += 1
		end
	end
	return n
end

test("bases: MaxPlayers positions, same Z, evenly spaced", function()
	local step = cfg.Base.Width + cfg.BaseGap
	for i = 1, cfg.MaxPlayers do
		local p = layout:basePosition(i)
		assert(p.z == cfg.BasesCenterZ and p.y == 0)
		if i > 1 then
			assert(math.abs(p.x - layout:basePosition(i - 1).x - step) < 1e-9)
		end
	end
end)

test("bases: row is symmetric around X = 0", function()
	assert(math.abs(layout:basePosition(1).x + layout:basePosition(cfg.MaxPlayers).x) < 1e-9)
end)

test("bases: index out of range is rejected", function()
	assert(not pcall(layout.basePosition, layout, 0))
	assert(not pcall(layout.basePosition, layout, cfg.MaxPlayers + 1))
end)

test("bases: neighbours do not overlap", function()
	local gap = layout:basePosition(2).x - layout:basePosition(1).x
	assert(gap >= cfg.Base.Width)
end)

test("island: contains every base", function()
	local b = layout:islandBounds()
	for i = 1, cfg.MaxPlayers do
		local p = layout:basePosition(i)
		assert(p.x - cfg.Base.Width / 2 >= b.minX and p.x + cfg.Base.Width / 2 <= b.maxX)
		assert(p.z - cfg.Base.Depth / 2 >= b.minZ and p.z + cfg.Base.Depth / 2 <= b.maxZ)
	end
end)

test("slots: required counts", function()
	assert(count("Showcase") == 8)
	assert(count("ShowcaseButton") == 8)
	assert(count("Aquarium") == 1)
	assert(count("Recycler") == 1)
	assert(count("Shop") == 1)
	slotsByName() -- имена уникальны
end)

test("slots: every footprint is inside the base", function()
	for _, s in layout:baseSlots() do
		assert(math.abs(s.x) + s.sizeX / 2 <= cfg.Base.Width / 2, s.name .. " out of X")
		assert(math.abs(s.z) + s.sizeZ / 2 <= cfg.Base.Depth / 2, s.name .. " out of Z")
	end
end)

test("slots: footprints do not overlap", function()
	local list = layout:baseSlots()
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local overlapX = math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2
			local overlapZ = math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2
			assert(not (overlapX and overlapZ), a.name .. " overlaps " .. b.name)
		end
	end
end)

test("showcases: 4 on the left, 4 on the right", function()
	local left, right = 0, 0
	for _, s in layout:baseSlots() do
		if s.slotType == "Showcase" then
			if s.x < 0 then left += 1 else right += 1 end
		end
	end
	assert(left == 4 and right == 4)
end)

test("buttons: each one stands in front of its showcase, towards the centre", function()
	local map = slotsByName()
	for k = 1, 8 do
		local showcase, button = map["Showcase" .. k], map["Button" .. k]
		assert(showcase and button)
		assert(showcase.x * button.x > 0, "button on the other side")
		assert(math.abs(button.x) < math.abs(showcase.x), "button not towards centre")
		assert(button.z == showcase.z)
	end
end)

test("sketch: aquarium at the back centre, recycler front-left, shop front-right", function()
	local map = slotsByName()
	local minZ, maxZ = math.huge, -math.huge
	for _, s in layout:baseSlots() do
		if s.slotType == "Showcase" then
			minZ, maxZ = math.min(minZ, s.z), math.max(maxZ, s.z)
		end
	end
	assert(map.Aquarium.x == 0 and map.Aquarium.z < minZ)
	assert(map.Recycler.x < 0 and map.Recycler.z > maxZ)
	assert(map.Shop.x > 0 and map.Shop.z > maxZ)
end)

test("slotWorldPosition: base position + slot offset", function()
	local map = slotsByName()
	local base, w = layout:basePosition(3), layout:slotWorldPosition(3, map.Recycler)
	assert(w.x == base.x + map.Recycler.x and w.z == base.z + map.Recycler.z and w.y == 0)
end)

test("spawn: in front of the base and still on the island", function()
	local b = layout:islandBounds()
	for i = 1, cfg.MaxPlayers do
		local base, s = layout:basePosition(i), layout:spawnPosition(i)
		assert(s.x == base.x)
		assert(s.z > base.z + cfg.Base.Depth / 2 and s.z < b.maxZ)
	end
end)

test("ocean: starts right at the island's front edge", function()
	assert(layout:islandBounds().maxZ == cfg.Island.FrontZ)
	assert(cfg.Ocean.Depth > 0 and cfg.Ocean.Length > 0)
end)

return true

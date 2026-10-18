-- Контракт раскладки: базы полукругом вокруг хаба лицом к воде. Layout не использует Roblox API.
local harness = require("./harness")
local cfg = require("../src/shared/Config/Island")
local Layout = require("../src/shared/Layout")

local test = harness.test
local layout = Layout.new(cfg)
local EPS = 1e-6

-- Прямоугольник по центру, переду (fx, fz) и размерам: вправо = (fz, -fx).
local function rect(cx, cz, fx, fz, width, depth)
	return { cx = cx, cz = cz, axes = { { fz, -fx }, { fx, fz } }, half = { width / 2, depth / 2 } }
end

-- Пересечение по осям разделения (SAT). Касание краями не считается пересечением.
local function overlap(a, b)
	for _, set in { a.axes, b.axes } do
		for _, ax in set do
			local function reach(r)
				return r.half[1] * math.abs(ax[1] * r.axes[1][1] + ax[2] * r.axes[1][2])
					+ r.half[2] * math.abs(ax[1] * r.axes[2][1] + ax[2] * r.axes[2][2])
			end
			local dist = math.abs((b.cx - a.cx) * ax[1] + (b.cz - a.cz) * ax[2])
			if dist >= reach(a) + reach(b) then
				return false
			end
		end
	end
	return true
end

local function baseRect(i)
	local p, f = layout:basePosition(i), layout:baseFront(i)
	return rect(p.x, p.z, f.x, f.z, cfg.Base.Width, cfg.Base.Depth)
end

local function hubRect(b)
	local h = cfg.Hub
	return rect(h.x + b.x, h.z + b.z, 0, 1, b.sizeX, b.sizeZ)
end

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

test("bases: all at distance R from the hub, at the configured angles", function()
	for i = 1, cfg.MaxPlayers do
		local p = layout:basePosition(i)
		local t = math.rad(cfg.Arc.FirstDeg + (i - 1) * cfg.Arc.StepDeg)
		assert(math.abs(p.x - (cfg.Hub.x + cfg.Arc.R * math.sin(t))) < EPS, "x of base " .. i)
		assert(math.abs(p.z - (cfg.Hub.z + cfg.Arc.R * math.cos(t))) < EPS, "z of base " .. i)
		assert(p.y == 0)
	end
end)

test("bases: arc is symmetric around the hub axis", function()
	for i = 1, cfg.MaxPlayers do
		local a, b = layout:basePosition(i), layout:basePosition(cfg.MaxPlayers + 1 - i)
		assert(math.abs(a.x - cfg.Hub.x + (b.x - cfg.Hub.x)) < EPS and math.abs(a.z - b.z) < EPS)
	end
end)

test("bases: index out of range is rejected", function()
	assert(not pcall(layout.basePosition, layout, 0))
	assert(not pcall(layout.basePosition, layout, cfg.MaxPlayers + 1))
end)

test("bases: front is a unit vector pointing away from the hub", function()
	for i = 1, cfg.MaxPlayers do
		local p, f = layout:basePosition(i), layout:baseFront(i)
		assert(math.abs(f.x * f.x + f.z * f.z - 1) < EPS)
		local dx, dz = p.x - cfg.Hub.x, p.z - cfg.Hub.z
		local len = math.sqrt(dx * dx + dz * dz)
		assert(math.abs(f.x * dx / len + f.z * dz / len - 1) < EPS, "base " .. i .. " does not face outward")
	end
end)

test("bases: yaw turns local +Z into the front (Roblox CFrame.Angles(0, yaw, 0))", function()
	for i = 1, cfg.MaxPlayers do
		local f, yaw = layout:baseFront(i), layout:baseYaw(i)
		assert(math.abs(math.sin(yaw) - f.x) < EPS and math.abs(math.cos(yaw) - f.z) < EPS)
	end
end)

test("bases: footprints do not overlap each other or hub buildings", function()
	for i = 1, cfg.MaxPlayers do
		for j = i + 1, cfg.MaxPlayers do
			assert(not overlap(baseRect(i), baseRect(j)), ("base %d overlaps base %d"):format(i, j))
		end
		for _, b in cfg.HubBuildings do
			assert(not overlap(baseRect(i), hubRect(b)), ("base %d overlaps %s"):format(i, b.id))
		end
	end
end)

test("hub: Shop and Upgrades exist, sit around the hub and do not overlap", function()
	local list = layout:hubBuildings()
	assert(#list == 2)
	local byId = {}
	for _, b in list do
		byId[b.id] = b
	end
	assert(byId.Shop and byId.Upgrades)
	assert(byId.Shop.x == cfg.Hub.x + cfg.HubBuildings[1].x and byId.Shop.z == cfg.Hub.z + cfg.HubBuildings[1].z)
	assert(not overlap(hubRect(cfg.HubBuildings[1]), hubRect(cfg.HubBuildings[2])))
end)

test("slots: required counts, no Shop on the base anymore", function()
	assert(count("Showcase") == 8)
	assert(count("ShowcaseButton") == 8)
	assert(count("Aquarium") == 1)
	assert(count("Recycler") == 1)
	assert(count("Shop") == 0)
	slotsByName()
end)

test("slots: every footprint is inside the base and footprints do not overlap", function()
	local list = layout:baseSlots()
	for _, s in list do
		assert(math.abs(s.x) + s.sizeX / 2 <= cfg.Base.Width / 2, s.name .. " out of X")
		assert(math.abs(s.z) + s.sizeZ / 2 <= cfg.Base.Depth / 2, s.name .. " out of Z")
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local overlapX = math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2
			local overlapZ = math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2
			assert(not (overlapX and overlapZ), a.name .. " overlaps " .. b.name)
		end
	end
end)

test("slots: buttons stand in front of their showcase, towards the centre", function()
	local map = slotsByName()
	for k = 1, 8 do
		local showcase, button = map["Showcase" .. k], map["Button" .. k]
		assert(showcase and button)
		assert(showcase.x * button.x > 0 and math.abs(button.x) < math.abs(showcase.x) and button.z == showcase.z)
	end
end)

test("slots: aquarium at the back centre, recycler front-left of the showcases", function()
	local map = slotsByName()
	local minZ, maxZ = math.huge, -math.huge
	for _, s in layout:baseSlots() do
		if s.slotType == "Showcase" then
			minZ, maxZ = math.min(minZ, s.z), math.max(maxZ, s.z)
		end
	end
	assert(map.Aquarium.x == 0 and map.Aquarium.z < minZ)
	assert(map.Recycler.x < 0 and map.Recycler.z > maxZ)
end)

test("slotWorldPosition: base centre + x * right + z * front", function()
	local map = slotsByName()
	for i = 1, cfg.MaxPlayers do
		local p, f = layout:basePosition(i), layout:baseFront(i)
		for _, name in { "Recycler", "Showcase1", "Button8" } do
			local s, w = map[name], layout:slotWorldPosition(i, map[name])
			assert(math.abs(w.x - (p.x + s.x * f.z + s.z * f.x)) < EPS, name .. " x, base " .. i)
			assert(math.abs(w.z - (p.z - s.x * f.x + s.z * f.z)) < EPS, name .. " z, base " .. i)
			assert(w.y == 0)
		end
	end
end)

test("spawn: in front of the base, SpawnOffset past its front edge", function()
	for i = 1, cfg.MaxPlayers do
		local p, f, s = layout:basePosition(i), layout:baseFront(i), layout:spawnPosition(i)
		local d = cfg.Base.Depth / 2 + cfg.SpawnOffset
		assert(math.abs(s.x - (p.x + f.x * d)) < EPS and math.abs(s.z - (p.z + f.z * d)) < EPS and s.y == 0)
	end
end)

test("ocean: deep enough and wide enough", function()
	assert(cfg.Ocean.Depth > 0 and cfg.Ocean.Half > cfg.Arc.R + cfg.Base.Depth + cfg.Beach)
end)

return true

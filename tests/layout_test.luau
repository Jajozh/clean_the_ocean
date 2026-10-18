-- Контракт раскладки v3: базы по дуге лицом к фокусу F в плавательной зоне. Layout не использует Roblox API.
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

local function focus()
	return { x = cfg.Hub.x, z = cfg.Hub.z + cfg.Arc.R }
end

local function inSwim(x: number, z: number)
	local w = layout:swim()
	return x >= w.minX and x <= w.maxX and z >= w.minZ and z <= w.maxZ
end

test("bases: on the arc around F at the configured angles", function()
	local f = focus()
	assert(#cfg.Arc.Angles == cfg.MaxPlayers)
	for i = 1, cfg.MaxPlayers do
		local p = layout:basePosition(i)
		local a = math.rad(cfg.Arc.Angles[i])
		assert(math.abs(p.x - (f.x + cfg.Arc.R * math.sin(a))) < EPS, "x of base " .. i)
		assert(math.abs(p.z - (f.z - cfg.Arc.R * math.cos(a))) < EPS, "z of base " .. i)
		assert(p.y == 0)
	end
end)

test("bases: arc is symmetric around the hub axis", function()
	for i = 1, cfg.MaxPlayers do
		local a, b = layout:basePosition(i), layout:basePosition(cfg.MaxPlayers + 1 - i)
		assert(math.abs((a.x - cfg.Hub.x) + (b.x - cfg.Hub.x)) < EPS and math.abs(a.z - b.z) < EPS)
	end
end)

test("bases: index out of range is rejected", function()
	assert(not pcall(layout.basePosition, layout, 0))
	assert(not pcall(layout.basePosition, layout, cfg.MaxPlayers + 1))
end)

test("bases: front is a unit vector pointing at F", function()
	local f = focus()
	for i = 1, cfg.MaxPlayers do
		local p, fr = layout:basePosition(i), layout:baseFront(i)
		assert(math.abs(fr.x * fr.x + fr.z * fr.z - 1) < EPS)
		local dx, dz = f.x - p.x, f.z - p.z
		local len = math.sqrt(dx * dx + dz * dz)
		assert(math.abs(fr.x * dx / len + fr.z * dz / len - 1) < EPS, "base " .. i .. " does not face F")
	end
end)

test("bases: yaw = -angle turns local +Z into the front (Roblox CFrame.Angles(0, yaw, 0))", function()
	for i = 1, cfg.MaxPlayers do
		local fr, yaw = layout:baseFront(i), layout:baseYaw(i)
		assert(math.abs(yaw + math.rad(cfg.Arc.Angles[i])) < EPS)
		assert(math.abs(math.sin(yaw) - fr.x) < EPS and math.abs(math.cos(yaw) - fr.z) < EPS)
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

test("hub: Shop and Upgrades sit between the two middle bases and do not overlap", function()
	local list = layout:hubBuildings()
	assert(#list == 2)
	local byId = {}
	for _, b in list do
		byId[b.id] = b
	end
	assert(byId.Shop and byId.Upgrades)
	assert(byId.Shop.x == cfg.Hub.x + cfg.HubBuildings[1].x and byId.Shop.z == cfg.Hub.z + cfg.HubBuildings[1].z)
	assert(not overlap(hubRect(cfg.HubBuildings[1]), hubRect(cfg.HubBuildings[2])))
	local mid = cfg.MaxPlayers // 2
	local left, right = layout:basePosition(mid), layout:basePosition(mid + 1)
	for _, b in list do
		assert(b.x - b.sizeX / 2 > left.x and b.x + b.sizeX / 2 < right.x, b.id .. " is not between the middle bases")
	end
end)

test("swim: rectangle from the config, F is inside it", function()
	local w, f = layout:swim(), focus()
	assert(w.minX == -cfg.Swim.HalfWidth and w.maxX == cfg.Swim.HalfWidth)
	assert(w.minZ == cfg.Swim.NorthZ and w.maxZ == cfg.Swim.NorthZ + cfg.Swim.Length)
	assert(inSwim(f.x, f.z), "F is not in the swim zone")
end)

test("swim: no base corner, spawn or hub building is in the water", function()
	for i = 1, cfg.MaxPlayers do
		local r = baseRect(i)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x = r.cx + r.axes[1][1] * r.half[1] * sx + r.axes[2][1] * r.half[2] * sz
				local z = r.cz + r.axes[1][2] * r.half[1] * sx + r.axes[2][2] * r.half[2] * sz
				assert(not inSwim(x, z), "base " .. i .. " touches the water")
			end
		end
		local s = layout:spawnPosition(i)
		assert(not inSwim(s.x, s.z), "spawn " .. i .. " is in the water")
	end
	for _, b in layout:hubBuildings() do
		assert(not inSwim(b.x, b.z))
	end
end)

test("swim: from every spawn, walking forward reaches the water soon", function()
	for i = 1, cfg.MaxPlayers do
		local s, fr = layout:spawnPosition(i), layout:baseFront(i)
		local d = 0
		while not inSwim(s.x + fr.x * d, s.z + fr.z * d) do
			d += 1
			assert(d <= cfg.MaxWalkToWater, ("base %d: no water within %d studs"):format(i, cfg.MaxWalkToWater))
		end
		assert(d >= 3, ("base %d: spawn is at the water edge (%d)"):format(i, d))
	end
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
	assert(cfg.Ocean.Depth > 0 and cfg.Ocean.Half > cfg.Island.SemiX)
end)

return true

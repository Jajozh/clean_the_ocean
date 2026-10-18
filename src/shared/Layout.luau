-- Чистая раскладка острова и баз: без Roblox API, конфиг приходит параметром.
local Layout = {}
Layout.__index = Layout

function Layout.new(cfg)
	return setmetatable({ cfg = cfg }, Layout)
end

-- Угол базы i от направления +Z к +X, радианы.
function Layout:baseYaw(i: number)
	local cfg = self.cfg
	assert(i >= 1 and i <= cfg.MaxPlayers and i % 1 == 0, "base index out of range")
	return math.rad(cfg.Arc.FirstDeg + (i - 1) * cfg.Arc.StepDeg)
end

function Layout:baseFront(i: number)
	local t = self:baseYaw(i)
	return { x = math.sin(t), z = math.cos(t) }
end

function Layout:basePosition(i: number)
	local cfg, f = self.cfg, self:baseFront(i)
	return { x = cfg.Hub.x + cfg.Arc.R * f.x, y = 0, z = cfg.Hub.z + cfg.Arc.R * f.z }
end

function Layout:baseSlots()
	return self.cfg.Slots
end

-- Локальный x идёт вправо = (front.z, -front.x), z вперёд = front.
function Layout:slotWorldPosition(i: number, slot)
	local p, f = self:basePosition(i), self:baseFront(i)
	return { x = p.x + slot.x * f.z + slot.z * f.x, y = 0, z = p.z - slot.x * f.x + slot.z * f.z }
end

function Layout:spawnPosition(i: number)
	local p, f = self:basePosition(i), self:baseFront(i)
	local d = self.cfg.Base.Depth / 2 + self.cfg.SpawnOffset
	return { x = p.x + f.x * d, y = 0, z = p.z + f.z * d }
end

function Layout:hubBuildings()
	local cfg, list = self.cfg, {}
	for _, b in cfg.HubBuildings do
		table.insert(list, { id = b.id, x = cfg.Hub.x + b.x, z = cfg.Hub.z + b.z, sizeX = b.sizeX, sizeZ = b.sizeZ })
	end
	return list
end

return Layout

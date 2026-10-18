-- Чистая раскладка острова и баз: без Roblox API, конфиг приходит параметром.
local Layout = {}
Layout.__index = Layout

function Layout.new(cfg)
	return setmetatable({ cfg = cfg }, Layout)
end

-- Фокус F в плавательной зоне: сюда смотрят все базы.
function Layout:focus()
	local cfg = self.cfg
	return { x = cfg.Hub.x, z = cfg.Hub.z + cfg.Arc.R }
end

function Layout:swim()
	local s = self.cfg.Swim
	return { minX = -s.HalfWidth, maxX = s.HalfWidth, minZ = s.NorthZ, maxZ = s.NorthZ + s.Length }
end

-- Угол базы i, радианы (от направления на юг, к +X).
local function angle(self, i: number)
	local cfg = self.cfg
	assert(i >= 1 and i <= cfg.MaxPlayers and i % 1 == 0, "base index out of range")
	return math.rad(cfg.Arc.Angles[i])
end

function Layout:baseYaw(i: number)
	return -angle(self, i)
end

function Layout:baseFront(i: number)
	local a = angle(self, i)
	return { x = -math.sin(a), z = math.cos(a) }
end

function Layout:basePosition(i: number)
	local a, f = angle(self, i), self:focus()
	local R = self.cfg.Arc.R
	return { x = f.x + R * math.sin(a), y = 0, z = f.z - R * math.cos(a) }
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

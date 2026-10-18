-- Чистая раскладка острова и баз: без Roblox API, конфиг приходит параметром.
local Layout = {}
Layout.__index = Layout

function Layout.new(cfg)
	return setmetatable({ cfg = cfg }, Layout)
end

function Layout:basePosition(i: number)
	local cfg = self.cfg
	assert(i >= 1 and i <= cfg.MaxPlayers and i % 1 == 0, "base index out of range")
	local step = cfg.Base.Width + cfg.BaseGap
	return { x = (i - (cfg.MaxPlayers + 1) / 2) * step, y = 0, z = cfg.BasesCenterZ }
end

function Layout:baseSlots()
	return self.cfg.Slots
end

function Layout:slotWorldPosition(i: number, slot)
	local base = self:basePosition(i)
	return { x = base.x + slot.x, y = 0, z = base.z + slot.z }
end

function Layout:spawnPosition(i: number)
	local base = self:basePosition(i)
	return { x = base.x, y = 0, z = base.z + self.cfg.Base.Depth / 2 + self.cfg.SpawnOffset }
end

function Layout:islandBounds()
	local island = self.cfg.Island
	return { minX = -island.Width / 2, maxX = island.Width / 2, minZ = island.BackZ, maxZ = island.FrontZ }
end

return Layout

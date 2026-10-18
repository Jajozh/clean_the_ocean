-- Данные острова. Студы, поверхность песка на y = 0, ось X вдоль ряда баз, +Z к океану.
local showcaseRows = { -16, -7, 2, 11 }

local slots = {}
for k = 1, 8 do
	local side = if k <= 4 then -1 else 1
	local z = showcaseRows[(k - 1) % 4 + 1]
	table.insert(slots, { name = "Showcase" .. k, slotType = "Showcase", x = 22 * side, z = z, sizeX = 6, sizeZ = 6 })
	table.insert(slots, { name = "Button" .. k, slotType = "ShowcaseButton", x = 14 * side, z = z, sizeX = 3, sizeZ = 3 })
end
table.insert(slots, { name = "Aquarium", slotType = "Aquarium", x = 0, z = -20, sizeX = 14, sizeZ = 8 })
table.insert(slots, { name = "Recycler", slotType = "Recycler", x = -18, z = 20, sizeX = 12, sizeZ = 8 })
table.insert(slots, { name = "Shop", slotType = "Shop", x = 18, z = 20, sizeX = 10, sizeZ = 8 })

return {
	MaxPlayers = 6,
	Base = { Width = 60, Depth = 50 },
	BaseGap = 20,
	BasesCenterZ = -70,
	-- Остров сплошной блок до дна океана
	Island = { Width = 520, BackZ = -110, FrontZ = 110, Thickness = 228 },
	Ocean = { Depth = 220, Length = 400 },
	SpawnOffset = 15, -- студов перед передним краем базы
	Slots = slots, -- смещения от центра базы
}

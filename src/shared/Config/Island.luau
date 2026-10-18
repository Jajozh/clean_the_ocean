-- Данные острова v2. Студы. Пляж и вода на юге (+Z), хаб в центре, базы полукругом лицом к воде.
-- Локальные координаты базы: x вправо, z вперёд (к воде); при угле 0 совпадают с мировыми.
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

return {
	MaxPlayers = 6,
	Cell = 4, -- размер клетки суши, студы
	Seed = 7, -- от него зависит контур берега, рельеф и пальмы
	Hub = { x = 0, z = -60 },
	-- Здания хаба: смещение от центра хаба, смотрят на воду (+Z).
	HubBuildings = {
		{ id = "Shop", x = -14, z = 0, sizeX = 16, sizeZ = 12 },
		{ id = "Upgrades", x = 14, z = 0, sizeX = 16, sizeZ = 12 },
	},
	-- Центр базы i = Hub + R * (sin t, cos t), t = FirstDeg + (i - 1) * StepDeg; перед базы смотрит от хаба.
	Arc = { R = 160, StepDeg = 28, FirstDeg = -70 },
	Base = { Width = 60, Depth = 50 },
	Beach = 35, -- от переднего края базы до воды
	SpawnOffset = 15, -- спавн на столько студов перед передним краем базы
	Relief = { Step = 2, MaxSteps = 6 }, -- ступени рельефа к северу от хаба (высота ступени, студы)
	Island = { Thickness = 228 }, -- суша идёт до дна океана
	Ocean = { Depth = 220, Half = 450 }, -- вода: квадрат со стороной 2 * Half вокруг хаба
	Slots = slots, -- смещения от центра базы, локальные координаты
}

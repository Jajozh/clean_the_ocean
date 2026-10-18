-- Данные острова v3. Студы, +Z на юг. Хаб в центре дуги, базы по дуге лицом к фокусу F в плавательной зоне.
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
	Seed = 7, -- от него зависит шум края острова, горы и пальмы
	Hub = { x = 0, z = -60 },
	-- Здания хаба: смещение от центра хаба, смотрят на юг (+Z).
	HubBuildings = {
		{ id = "Shop", x = -24, z = 0, sizeX = 16, sizeZ = 12 },
		{ id = "Upgrades", x = 24, z = 0, sizeX = 16, sizeZ = 12 },
	},
	-- Фокус F = (Hub.x, Hub.z + R). База с углом a: центр F + R * (sin a, -cos a), перед смотрит на F.
	Arc = { R = 220, Angles = { -60, -42, -24, 24, 42, 60 } },
	Base = { Width = 60, Depth = 50 },
	SpawnOffset = 15, -- спавн на столько студов перед передним краем базы
	MaxWalkToWater = 45, -- от спавна по направлению «перед» до плавательной зоны не дальше
	-- Остров: эллипс с неровным блочным краем, песок, высота везде 0.
	Island = { CenterZ = -10, SemiX = 290, SemiZ = 170, Noise = 10, Thickness = 228 },
	-- Плавательная зона (единственная вода, куда можно): прямоугольник, вырезанный из острова с юга.
	Swim = { HalfWidth = 140, NorthZ = 32, Length = 148 }, -- границы кратны Cell, иначе проходят через центр клетки
	-- Декор-полоса: суша дальше R + Margin от F. Недоступна игроку (горы и пальмы).
	Decor = { Margin = 45, Mountains = 10, Palms = 30 },
	Ocean = { Depth = 220, Half = 500 }, -- квадрат воды вокруг центра острова (0, Island.CenterZ)
	Slots = slots, -- смещения от центра базы, локальные координаты
}

-- Если остров уже построен в edit-режиме и сохранён в месте, не пересобираем.
if workspace:FindFirstChild("Island") then
	return
end
require(game:GetService("ReplicatedStorage").Shared.IslandBuilder).build()

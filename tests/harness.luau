local harness = {}

local passed, failed = 0, {}

function harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("ok   " .. name)
	else
		table.insert(failed, name)
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end

-- Падаем ошибкой, чтобы `luau tests/run.luau` вернул ненулевой код.
function harness.finish()
	print(("\n%d passed, %d failed"):format(passed, #failed))
	if #failed > 0 then
		error("tests failed", 0)
	end
end

return harness

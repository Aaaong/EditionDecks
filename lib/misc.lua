-- forced-edition logic adapted from Cryptid by MathIsFun_, Cryptid and Balatro Discords, GPL-3.0

function EditionDecks.safe_get(t, ...)
	local current = t
	for _, k in ipairs({ ... }) do
		if not current or current[k] == nil then
			return false
		end
		current = current[k]
	end
	return current
end

function EditionDecks.poll_random_edition(_seed)
	local pool = {}
	for _, c in ipairs(G.P_CENTER_POOLS.Edition) do
		if c.key ~= "e_base" and not c.no_edeck then
			pool[#pool + 1] = c
		end
	end
	return pseudorandom_element(pool, pseudoseed(_seed or "edeck_random_edition")).key
end

function EditionDecks.forced_edition()
	return G.GAME and G.GAME.modifiers and G.GAME.modifiers.edeck_force_edition
end

function EditionDecks.next_forced_edition()
	local mods = G.GAME and G.GAME.modifiers
	if not mods then
		return nil
	end
	if mods.edeck_force_edition then
		return mods.edeck_force_edition
	elseif mods.edeck_force_random_edition then
		return EditionDecks.poll_random_edition()
	end
end

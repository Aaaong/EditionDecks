-- Edition Decks
-- A standalone mod adding one deck per edition.
--
-- CREDIT: the idea, the game logic (edition locking, forced editions on new cards, the Lovely patches)
-- and the original "Edition Deck" come from Cryptid by MathIsFun_, Cryptid and Balatro Discords
-- (https://github.com/SpectralPack/Cryptid), licensed under GPL-3.0. This mod is derived from it and is
-- distributed under the same license (see LICENSE). The sprites are created with generative AI.

if not EditionDecks then
	EditionDecks = {}
end
EditionDecks.path = "" .. SMODS.current_mod.path
EditionDecks.config = SMODS.current_mod.config

SMODS.current_mod.config_tab = function()
	local nodes = {}
	for _, key in ipairs({
		"planet_edition_effects",
		"black_hole_edition_effects",
		"joker_edition_effects",
		"other_edition_effects",
	}) do
		nodes[#nodes + 1] = create_toggle({
			label = localize("edeck_cfg_" .. key),
			ref_table = EditionDecks.config,
			ref_value = key,
		})
	end
	for _, line in ipairs({ "edeck_cfg_info_1", "edeck_cfg_info_2" }) do
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.03 },
			nodes = {
				{ n = G.UIT.T, config = { text = localize(line), scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
			},
		}
	end
	return {
		n = G.UIT.ROOT,
		config = { r = 0.1, minw = 6, align = "tm", padding = 0.2, colour = G.C.BLACK },
		nodes = nodes,
	}
end

local function load(file)
	local f, err = SMODS.load_file(file)
	if err then
		error(err)
	end
	return f()
end

-- Mod icon
SMODS.Atlas({
	key = "modicon",
	path = "edeck_icon.png",
	px = 32,
	py = 32,
})

load("lib/misc.lua")
load("items/edition_deck.lua")

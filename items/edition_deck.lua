SMODS.Atlas({
	key = "decks",
	path = "edeck_decks.png",
	px = 71,
	py = 95,
})

local edition_decks = {
	{ suffix = "foil", edition = "e_foil", pos = { x = 0, y = 0 }, order = 17 },
	{ suffix = "holo", edition = "e_holo", pos = { x = 1, y = 0 }, order = 18 },
	{ suffix = "polychrome", edition = "e_polychrome", pos = { x = 2, y = 0 }, order = 19 },
	{ suffix = "negative", edition = "e_negative", pos = { x = 3, y = 0 }, order = 20 },
	{ suffix = "random", edition = nil, pos = { x = 4, y = 0 }, order = 21 },
}

local deck_edition = {}

for _, def in ipairs(edition_decks) do
	local key = def.suffix
	deck_edition["b_edeck_" .. key] = def.edition or "random"
	SMODS.Back({
		name = "Edition Deck (" .. def.suffix .. ")",
		key = key,
		order = def.order,
		atlas = "decks",
		pos = def.pos,
		config = {},
		loc_vars = function(self, info_queue, center)
			local edition = def.edition
			return {
				vars = {
					edition and localize({ type = "name_text", set = "Edition", key = edition })
						or localize("edeck_random_edition"),
					colours = {
						edition and G.P_CENTERS[edition] and G.P_CENTERS[edition].badge_colour or G.C.DARK_EDITION,
					},
				},
			}
		end,
		apply = function(self)
			G.GAME.edeck_lock_edition = true
			G.GAME.modifiers.edeck_no_edition_price = true
			if def.edition then
				G.GAME.modifiers.edeck_force_edition = def.edition
			else
				G.GAME.modifiers.edeck_force_random_edition = true
				G.GAME.modifiers.edeck_force_edition = nil
			end
			for k, v in pairs(G.P_TAGS) do
				if v.config and v.config.edition then
					G.GAME.banned_keys[k] = true
				end
			end
			G.E_MANAGER:add_event(Event({
				func = function()
					for c = #G.playing_cards, 1, -1 do
						G.playing_cards[c]:set_edition(def.edition or EditionDecks.poll_random_edition(), true, true)
					end
					return true
				end,
			}))
		end,
		unlocked = false,
		check_for_unlock = function(self, args)
			if args.type == "discover_amount" then
				if G.DISCOVER_TALLIES.editions.tally / G.DISCOVER_TALLIES.editions.of >= 1 then
					unlock_card(self)
				end
			end
		end,
	})
end

SMODS.DrawStep({
	key = "back_edition",
	order = 5,
	func = function(self)
		if self.params.sleeve_card or self.ability.set == "Sleeve" then
			return
		end
		local in_run_setup = not not (
			self.ability.set == "Back"
			or self.params.viewed_back
			or self.params.run_select_selection_choice
			or self.params.run_select_preview_card
			or (self.area and (self.area.config.run_select or self.area.config.run_select_deck_preview))
		)
		local back = (self.ability.set == "Back" and self.config.center)
			or (self.params.viewed_back == true and G.GAME.viewed_back and G.GAME.viewed_back.effect.center)
			or (self.playing_card and not in_run_setup and G.GAME.selected_back_key)
		if not back or not (back.unlocked or not in_run_setup) then
			return
		end
		local ed = deck_edition[back.key]
		if not ed or ed == "random" then
			return
		end
		if ed == "e_negative" then
			self.children.back:draw_shader("negative", nil, self.ARGS.send_to_shader, true)
			self.children.back:draw_shader("negative_shine", nil, self.ARGS.send_to_shader, true)
		else
			local shader = G.SHADERS[ed:sub(3)] and ed:sub(3) or EditionDecks.safe_get(G.P_CENTERS, ed, "shader") or nil
			if shader then
				self.children.back:draw_shader(shader, nil, self.ARGS.send_to_shader, true)
			end
		end
	end,
	conditions = { vortex = false, facing = "back" },
})

local set_edition_ref = Card.set_edition
function Card:set_edition(edition, immediate, silent, delay)
	if not G.SETTINGS.paused and not self.no_forced_edition and G.GAME.edeck_lock_edition then
		if G.GAME.modifiers.edeck_force_edition then
			edition = G.GAME.modifiers.edeck_force_edition
		elseif self.edition then
			return
		end
	end
	local ret = set_edition_ref(self, edition, immediate, silent, delay)
	EditionDecks.make_edition_cosmetic(self)
	return ret
end

function EditionDecks.make_edition_cosmetic(card)
	local set = card.ability and card.ability.set
	if (set == "Voucher" or set == "Booster") and card.edition then
		if card.edition.card_limit then
			card.ability.card_limit = (card.ability.card_limit or 0) - card.edition.card_limit
			card.edition.card_limit = nil
		end
		if card.edition.extra_slots_used then
			card.ability.extra_slots_used = (card.ability.extra_slots_used or 0) - card.edition.extra_slots_used
			card.edition.extra_slots_used = nil
		end
	end
end

local card_init_ref = Card.init
function Card:init(X, Y, W, H, card, center, params)
	card_init_ref(self, X, Y, W, H, card, center, params)
	local set = center and center.set
	if
		(set == "Voucher" or set == "Booster")
		and G.STAGE == G.STAGES.RUN
		and G.GAME
		and G.GAME.edeck_lock_edition
		and not self.edition
	then
		local ed = EditionDecks.next_forced_edition()
		if ed then
			self:set_edition(ed, true, true)
		end
	end
end

local pending_draws = 0
local draw_from_deck_to_hand_ref = G.FUNCS.draw_from_deck_to_hand
if draw_from_deck_to_hand_ref then
G.FUNCS.draw_from_deck_to_hand = function(...)
	local mods = G.GAME and G.GAME.modifiers
	local watch = mods and (mods.edeck_force_edition == "e_negative" or mods.edeck_force_random_edition)
	local ret = draw_from_deck_to_hand_ref(...)
	if watch then
		pending_draws = pending_draws + 1
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				pending_draws = math.max(0, pending_draws - 1)
				if pending_draws == 0 then
					SMODS.cards_to_draw = nil
				end
				return true
			end,
		}))
	end
	return ret
end
end

local create_card_ref = create_card
function create_card(...)
	local card = create_card_ref(...)
	local ed = card and EditionDecks.next_forced_edition()
	if ed then
		card:set_edition(ed, true, true)
	end
	return card
end

local create_playing_card_ref = create_playing_card
function create_playing_card(...)
	local card = create_playing_card_ref(...)
	local ed = card and EditionDecks.next_forced_edition()
	if ed then
		card:set_edition(ed, true, true)
	end
	return card
end

if SMODS.add_voucher_to_shop then
	local add_voucher_to_shop_ref = SMODS.add_voucher_to_shop
	function SMODS.add_voucher_to_shop(...)
		local card = add_voucher_to_shop_ref(...)
		local ed = type(card) == "table" and card.set_edition and EditionDecks.next_forced_edition()
		if ed then
			card:set_edition(ed, true, true)
		end
		return card
	end
end

local function level_up_source(card)
	local set = card.ability and card.ability.set
	if set == "Planet" then
		return "planet_edition_effects"
	elseif card.config and card.config.center_key == "c_black_hole" then
		return "black_hole_edition_effects"
	elseif set == "Joker" then
		return "joker_edition_effects"
	end
	return "other_edition_effects"
end

local level_up_hand_ref = level_up_hand
function level_up_hand(card, hand, instant, amount, statustext)
	local ret = level_up_hand_ref(card, hand, instant, amount, statustext)
	local ed = type(card) == "table" and card.edition
	if
		ed
		and EditionDecks.config
		and EditionDecks.config[level_up_source(card)]
		and G.GAME.hands[hand]
	then
		local params = {}
		if ed.chips then
			params[#params + 1] = "chips"
		end
		if ed.mult or ed.x_mult then
			params[#params + 1] = "mult"
		end
		if #params > 0 then
			SMODS.upgrade_poker_hands({
				hands = hand,
				parameters = params,
				func = function(base, _, parameter)
					if parameter == "chips" then
						return base + ed.chips
					end
					if ed.mult then
						base = base + ed.mult
					end
					if ed.x_mult then
						base = base * ed.x_mult
					end
					return base
				end,
				level_up = 1,
				from = card,
				instant = instant,
				StatusText = statustext,
			})
		end
	end
	return ret
end

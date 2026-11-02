extends "res://scripts/live_hand_card_metadata.gd"
## Display-only extension of the shared live-hand card metadata service for Button
## Golem's two Eyelet Guard printings, (cycle 390) Tinker's two Jury-rig printings,
## (V3-1) the Lantern Monk's ally-targeting Moth Shroud pair and the Rag Duelist's
## four cape self-Dodge printings.
##
## The shared service (scripts/live_hand_card_metadata.gd) belongs to another
## coding lane, so this presenter-local subclass never edits it: every other ID
## falls straight through to `super`, and only the two authentic self-only Eyelet
## Guard records gain a faced, readable card. The Block, Thorns and one-turn
## duration printed here come from the very pool catalog record the paid resolver
## authenticates, so the face can never promise more (or less) than the fight
## really applies.
##
## Armed Thorns is fight-scoped state, never a hero status: nothing here writes or
## displays a `thorns` counter. `_authenticate` is read-only and is the resolver's
## own catalog contract, so this file invents no second authentication rule.

const PRINTINGS := CombatButtonGolemEyeletGuardCards.PRINTINGS
var _v3_guard_rules := CombatWardenV3GuardCards.new()
## The accepted Jury-rig authenticator is the only face authority for its two printings.
var _jury_rules := CombatTinkerV3JuryRigCards.new()
## The Seamstress's accepted whole-party Midnight Loom resolver is the only face and
## tooltip authority for its two printings: the printed heal, Block and one explicit
## party cleanse are read from the very catalog record that paid resolver authenticates.
var _loom_rules := CombatSeamstressV3CleansingCards.new()
## The Lantern Monk's accepted ally-targeting Moth Shroud resolver (V3-1) is the only
## face and tooltip authority for its two printings: the printed Block and the
## one-shot Dodge token come from the very catalog record that paid resolver authenticates.
var _shroud_rules := CombatLanternMonkShroudCards.new()
## The Rag Duelist's accepted self-Dodge resolver (V3-1) is the only face and tooltip
## authority for its four cape printings: the printed cost and the one-shot Dodge
## come from the very catalog record that paid resolver authenticates.
var _cape_rules := CombatRagDuelistDodgeCards.new()

## Read-only catalog authenticator. It never plays a card, never owns an armed
## mode and is never handed to the fight: the ONE armed authority lives on
## CombatRoundFlow.
var _catalog_rules := CombatButtonGolemEyeletGuardCards.new()


## The authentic pool record for one of this presenter's own printings (Eyelet Guard,
## Moth Shroud), detached. Anything else, and a rewritten or relinked pair, keeps the
## shared unknown/foreign face.
func _definition(card_id: String) -> Dictionary:
	if _shroud_rules.is_supported_card(card_id):
		# `is_supported_card` authenticates the exact catalog record and its base/'+'
		# link before this read-only face ever shows a name, cost, Block or Dodge.
		return _shroud_rules._catalog_definition(card_id)
	if _cape_rules.is_supported_card(card_id):
		# The same authenticating read for the four self-only cape printings: a rewritten
		# owner, cost, seat, target, effect or upgrade link keeps the unknown face.
		return _cape_rules._catalog_definition(card_id)
	if _jury_rules.is_supported_card(card_id):
		return CombatTinkerV3JuryRigCards.jury_rig_definition(card_id)
	if _loom_rules.is_supported_party_card(card_id):
		var loom: Dictionary = _loom_rules._catalog_definition(card_id)
		var printing: Dictionary = _loom_rules.PARTY_CARDS.get(card_id, {})
		return loom if _loom_rules._authentic_party(loom, card_id, printing) else {}
	if _v3_guard_rules.is_supported_card(card_id):
		return _v3_guard_rules._catalog_definition(card_id) if _v3_guard_rules.is_authentic_card(card_id) else {}
	if not PRINTINGS.has(card_id):
		return super._definition(card_id)
	if _catalog_rules._authenticate(card_id).is_empty():
		return {}
	return ButtonGolemPoolCards.new().get_definition(card_id)


## The terse drawn face line: only the printed Block and the Dodge token (or the
## one-turn Thorns for Eyelet Guard).
func _rules(id: String) -> String:
	if _shroud_rules.is_supported_card(id):
		var record: Dictionary = _definition(id)
		if record.is_empty():
			return ""
		return "Give a living ally %d Block. Dodge: their next incoming attack misses once." % int(record.get("effects", {}).get("block", 0))
	if _cape_rules.is_supported_card(id):
		var cape: Dictionary = _definition(id)
		if cape.is_empty():
			return ""
		return "Dodge the next attack aimed at this hero once; unused, it expires at your turn end."
	if _jury_rules.is_supported_card(id):
		var record: Dictionary = _definition(id)
		if record.is_empty():
			return ""
		return "Once per combat, copy the last other card played free: Tune Up/+ draw 1 or 2; Spare Parts/+ give 3 or 4 Block and draw 1."
	if _loom_rules.is_supported_party_card(id):
		var record: Dictionary = _definition(id)
		if record.is_empty():
			return ""
		var effects: Dictionary = record.get("effects", {})
		return "Each living hero: heal %d HP, gain %d Block; remove one chosen Bleed/Weak/Exposed." % [
			int(effects.get("heal", 0)), int(effects.get("block", 0))]
	if _v3_guard_rules.is_supported_card(id):
		var record: Dictionary = _definition(id)
		if record.is_empty():
			return ""
		return "Give a living ally %d Block. Guard their next enemy hit once: the Warden intercepts it." % int(record.get("effects", {}).get("block", 0))
	if not PRINTINGS.has(id):
		return super._rules(id)
	var record: Dictionary = _definition(id)
	if record.is_empty():
		return ""
	var effects: Dictionary = record.get("effects", {})
	return "Gain %d Block. Gain %d Thorns until your next turn." % [
		int(effects.get("block", 0)), int(effects.get("thorns", 0))]


## The complete hover tooltip: authentic owner, cost, self target, both printed
## effects, the one-turn duration and the refresh rule, then the usual pip legend.
func base_effect_text(card_id: String, include_pips: bool = true) -> String:
	if _shroud_rules.is_supported_card(card_id):
		var shroud: Dictionary = _definition(card_id)
		if shroud.is_empty():
			return "Unknown card"
		var shroud_effects: Dictionary = shroud.get("effects", {})
		var shroud_block: int = int(shroud_effects.get("block", 0))
		var shroud_pips: String = _pip_legend(shroud) if include_pips else ""
		return ("%s; Lantern Monk; %d energy\nFrom %s; Choose one living ally\n"
			+ "Give the chosen ally %d Block and arm Dodge: the next incoming attack on that ally misses and spends the one-shot Dodge, so it deals no damage. Moth Shroud keeps an already-armed Dodge at 1 instead of stacking it, and casting the card never spends Dodge. Torn heroes are excluded; the Monk may veil itself.\n%s") % [
				str(shroud.get("display_name", card_id)), int(shroud.get("cost", -1)),
				_positions(shroud.get("from_positions", [])), shroud_block, shroud_pips]
	if _cape_rules.is_supported_card(card_id):
		var cape: Dictionary = _definition(card_id)
		if cape.is_empty():
			return "Unknown card"
		var cape_pips: String = _pip_legend(cape) if include_pips else ""
		return ("%s; Rag Duelist; %d energy\nFrom %s; To self\n"
			+ "Dodge the next attack aimed at this hero once: it misses and deals no HP or Block damage, and that attempt spends the one-shot Dodge. Playing another cape refreshes an armed Dodge to 1 instead of stacking it, and an unused token expires at this hero's turn end. No target choice.\n%s") % [
				str(cape.get("display_name", card_id)), int(cape.get("cost", -1)),
				_positions(cape.get("from_positions", [])), cape_pips]
	if _jury_rules.is_supported_card(card_id):
		var card: Dictionary = _definition(card_id)
		if card.is_empty():
			return "Unknown card"
		return ("%s; Tinker; %d energy\nFrom %s; To self\n"
			+ "Once per combat, copy the last OTHER card genuinely played this combat and play that copy once at 0 energy. This build can copy only Tune Up or Tune Up+ (its printed draw, 1 or 2) or Spare Parts or Spare Parts+ (3 or 4 Block plus draw 1): the copy keeps exactly that card's printed effects on the living Tinker, with no second source-card payment. Any other preceding card leaves Jury-rig disabled. No target choice.\n%s") % [
				str(card.get("display_name", card_id)), int(card.get("cost", -1)),
				_positions(card.get("from_positions", [])),
				_pip_legend(card) if include_pips else ""]
	if _v3_guard_rules.is_supported_card(card_id):
		var card: Dictionary = _definition(card_id)
		if card.is_empty():
			return "Unknown card"
		return ("%s; Warden; %d energy\nFrom %s; To a living ally\n"
			+ "Give the chosen ally %d Block. Guard their next confirmed enemy hit once: it hits the living Warden instead, even through Block. Misses do not consume Guard.\n%s") % [
				str(card.get("display_name", card_id)), int(card.get("cost", -1)),
				_positions(card.get("from_positions", [])), int(card.get("effects", {}).get("block", 0)),
				_pip_legend(card) if include_pips else ""]
	if _loom_rules.is_supported_party_card(card_id):
		var loom: Dictionary = _definition(card_id)
		if loom.is_empty():
			return "Unknown card"
		var loom_effects: Dictionary = loom.get("effects", {})
		var loom_pips: String = _pip_legend(loom) if include_pips else ""
		return ("%s; Seamstress; %d energy\nFrom %s; all living heroes\n"
			+ "Heal each living hero %d HP, capped at max HP; each living hero gains %d Block. For each living hero choose one present Bleed, Weak or Exposed to remove completely; heal and Block alone if none are present. Torn heroes are excluded.\n%s") % [
				str(loom.get("display_name", card_id)), int(loom.get("cost", -1)),
				_positions(loom.get("from_positions", [])),
				int(loom_effects.get("heal", 0)), int(loom_effects.get("block", 0)), loom_pips]
	if not PRINTINGS.has(card_id):
		return super.base_effect_text(card_id, include_pips)
	var record: Dictionary = _definition(card_id)
	if record.is_empty():
		return "Unknown card"
	var effects: Dictionary = record.get("effects", {})
	var block: int = int(effects.get("block", 0))
	var thorns: int = int(effects.get("thorns", 0))
	var pips: String = _pip_legend(record) if include_pips else ""
	return ("%s; Button Golem; %d energy\nFrom %s; To self\n"
		+ "Gain %d Block and %d Thorns for one turn: each confirmed enemy hit on this Golem takes %d damage through enemy Block until your next turn. Re-arming refreshes, never stacks. No target choice.\n%s") % [
			str(record.get("display_name", card_id)), int(record.get("cost", -1)),
			_positions(record.get("from_positions", [])), block, thorns, thorns, pips]


## The shared renderer knows only catalog affordability. Jury-rig is useful only after
## the live presenter observed a verified supported-source (Tune Up/+ or Spare Parts/+)
## commit, so the drawn face and its reported state use the presenter's truthful
## admission instead of printed cost alone.
## The shared `visual` array is left to `super`: it keeps hover/aim tracking exact and
## avoids a per-frame playable flip. The brightness is reconciled on EVERY pass, because
## `super` rewrites it from catalog affordability: returning early on an unchanged
## verdict would leave a dim card drawn at full colour after that rewrite.
var _jury_playable: Dictionary = {}
## The shared renderer knows only catalog affordability. Moth Shroud is useful only
## while the mounted shared hand really admits it, so the face follows that preflight.
var _shroud_playable: Dictionary = {}
## The self-only cape printings follow the mounted shared hand's own paid
## admission: held copy, living Duelist in an authored seat, printed energy and
## this exact fight, turn and hand.
var _cape_playable: Dictionary = {}


func _update_visual(panel: Control) -> void:
	super._update_visual(panel)
	if not _bindings.has(panel):
		return
	var card_id: String = _bindings[panel].get("id", "")
	if _cape_rules.is_supported_card(card_id):
		_apply_cape_visual(panel, card_id)
		return
	if _shroud_rules.is_supported_card(card_id):
		_apply_shroud_visual(panel, card_id)
		return
	if not _jury_rules.CARD_IDS.has(card_id):
		return
	var presenter = _app.get_node_or_null("LiveSupportHand") if _app != null else null
	var playable: bool = presenter != null and is_instance_valid(presenter) \
		and presenter.has_method("jury_rig_actionable") \
		and bool(presenter.jury_rig_actionable(panel, card_id))
	_jury_playable[panel] = playable
	var colour := Color.WHITE if playable or _app == null else Color(0.72, 0.70, 0.68)
	if panel.self_modulate != colour:
		panel.self_modulate = colour
		panel.queue_redraw()


## The mounted face and its tests read the same corrected admission.
func visual_state(panel) -> Dictionary:
	var state: Dictionary = super.visual_state(panel)
	if _jury_playable.has(panel):
		state["playable"] = bool(_jury_playable[panel])
	if _shroud_playable.has(panel):
		state["playable"] = bool(_shroud_playable[panel])
	if _cape_playable.has(panel):
		state["playable"] = bool(_cape_playable[panel])
	return state


## A cape is enable-able only by the mounted shared hand's own paid admission:
## the held copy, a living Rag Duelist in an authored seat, printed energy and an
## active turn. Catalog knowledge alone never lights the face.
func _apply_cape_visual(panel: Control, card_id: String) -> void:
	var presenter = _app.get_node_or_null("LiveSupportHand") if _app != null else null
	var playable: bool = presenter != null and is_instance_valid(presenter) \
		and presenter.has_method("rag_duelist_cape_actionable") \
		and bool(presenter.rag_duelist_cape_actionable(panel, card_id))
	_cape_playable[panel] = playable
	var colour := Color.WHITE if playable or _app == null else Color(0.72, 0.70, 0.68)
	if panel.self_modulate != colour:
		panel.self_modulate = colour
		panel.queue_redraw()


## Moth Shroud is enable-able only by the mounted shared hand's own paid admission:
## a living Monk in an authored seat, the held copy, energy and a living ally.
func _apply_shroud_visual(panel: Control, card_id: String) -> void:
	var presenter = _app.get_node_or_null("LiveSupportHand") if _app != null else null
	var playable: bool = presenter != null and is_instance_valid(presenter) \
		and presenter.has_method("moth_shroud_actionable") \
		and bool(presenter.moth_shroud_actionable(panel, card_id))
	_shroud_playable[panel] = playable
	var colour := Color.WHITE if playable or _app == null else Color(0.72, 0.70, 0.68)
	if panel.self_modulate != colour:
		panel.self_modulate = colour
		panel.queue_redraw()


## Drop this face's own admission when the shared service unbinds its panel.
func _unbind(panel) -> void:
	_jury_playable.erase(panel)
	_shroud_playable.erase(panel)
	_cape_playable.erase(panel)
	super._unbind(panel)

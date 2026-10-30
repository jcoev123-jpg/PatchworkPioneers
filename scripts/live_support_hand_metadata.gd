extends "res://scripts/live_hand_card_metadata.gd"
## Display-only extension of the shared live-hand card metadata service for Button
## Golem's two Eyelet Guard printings.
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

## Read-only catalog authenticator. It never plays a card, never owns an armed
## mode and is never handed to the fight: the ONE armed authority lives on
## CombatRoundFlow.
var _catalog_rules := CombatButtonGolemEyeletGuardCards.new()


## The authentic pool record for one Eyelet Guard printing, detached. Anything
## else, and a rewritten or relinked pair, keeps the shared unknown/foreign face.
func _definition(card_id: String) -> Dictionary:
	if _v3_guard_rules.is_supported_card(card_id):
		return _v3_guard_rules._catalog_definition(card_id) if _v3_guard_rules.is_authentic_card(card_id) else {}
	if not PRINTINGS.has(card_id):
		return super._definition(card_id)
	if _catalog_rules._authenticate(card_id).is_empty():
		return {}
	return ButtonGolemPoolCards.new().get_definition(card_id)


## The terse drawn face line: only the printed Block and the one-turn Thorns.
func _rules(id: String) -> String:
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
	if _v3_guard_rules.is_supported_card(card_id):
		var card: Dictionary = _definition(card_id)
		if card.is_empty():
			return "Unknown card"
		return ("%s; Warden; %d energy\nFrom %s; To a living ally\n"
			+ "Give the chosen ally %d Block. Guard their next confirmed enemy hit once: it hits the living Warden instead, even through Block. Misses do not consume Guard.\n%s") % [
				str(card.get("display_name", card_id)), int(card.get("cost", -1)),
				_positions(card.get("from_positions", [])), int(card.get("effects", {}).get("block", 0)),
				_pip_legend(card) if include_pips else ""]
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

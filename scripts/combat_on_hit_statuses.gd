class_name CombatOnHitStatuses
extends RefCounted
## Pure adapter: emits authored on-hit status payloads for confirmed starter attacks.
## Does not play cards, mutate deck/party/enemies, or persist statuses on actors.
## Side-effect-free; never mutates catalog definitions or caller-owned dictionaries.

func status_for_confirmed_hit(card_id: String, hit_confirmed: bool) -> Dictionary:
	if not hit_confirmed:
		return {}
	
	var catalog = StarterCards.new()
	var def: Dictionary = catalog.get_definition(card_id)
	if def.is_empty():
		return {}
	
	# Only recognize the two status-producing starter attacks by exact ID and owner
	if card_id == "seamstress_prick":
		# Verify owner and authored bleed effect
		if def.get("owner") == "seamstress" and def.get("effects", {}).has("bleed"):
			# Authored bleed 2 + Seamstress passive +1 = 3
			var authored_bleed: int = def["effects"].get("bleed", 0)
			if authored_bleed == 2:
				return {"bleed": 3}
		return {}
	
	if card_id == "warden_shield_bash":
		# Verify owner and authored weak effect
		if def.get("owner") == "warden" and def.get("effects", {}).has("weak"):
			var authored_weak: int = def["effects"].get("weak", 0)
			if authored_weak == 1:
				return {"weak": 1}
		return {}
	
	# All other starter cards (including non-status attacks) emit no status
	return {}
class_name CombatStatuses
extends RefCounted
## Pure, actor-local rules. No entrypoint changes a caller's status dictionary.
## Bleed, Weak, Exposed and Tangled counts represent remaining *owner* turns,
## including the current turn. Riposte is not an N-turn counter: N is the
## counterdamage returned by each confirmed hit during its single owner turn.
## Fear is the literal boolean `cannot_buff_next_turn: true`: a one-owner-turn
## buff lock with no count, never created or aged by the Weak authored beside it.

const MAX_INT := 9223372036854775807


## Invalid damage or status data fails closed to zero, never an unmodified attack.
## Integer quotient/remainder arithmetic floors ONCE and avoids overflow.
## A positive-base attack adds Tangled's flat +2 after the Weak/Exposed floor,
## once per attack regardless of the defender's stack count.
func adjusted_attack_damage(base_damage: int, attacker_statuses: Dictionary, defender_statuses: Dictionary) -> int:
	if base_damage < 0 or not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return 0

	var weak: bool = attacker_statuses.get("weak", 0) > 0
	var exposed: bool = defender_statuses.get("exposed", 0) > 0
	var numerator := 1
	var denominator := 1
	if weak and exposed:
		numerator = 9
		denominator = 8
	elif weak:
		numerator = 3
		denominator = 4
	elif exposed:
		numerator = 3
		denominator = 2

	@warning_ignore("integer_division")
	var whole: int = base_damage / denominator
	@warning_ignore("integer_division")
	var partial: int = (base_damage % denominator) * numerator / denominator
	@warning_ignore("integer_division")
	if whole > (MAX_INT - partial) / numerator:
		return 0
	var adjusted: int = whole * numerator + partial
	if base_damage > 0 and defender_statuses.get("tangled", 0) > 0:
		if adjusted > MAX_INT - 2:
			return 0
		adjusted += 2
	return adjusted


## Riposte N means "when hit, strike back N". N is damage, never a duration: an
## active Riposte may counter every separate confirmed hit during its one owner
## turn, then expires completely at that owner's turn end.
## The authoritative caller owns hit confirmation, eligibility and the actual
## damage transaction; this pure projection only reports the counterdamage.
## Invalid status input, an unconfirmed (skipped) hit, and no/zero Riposte all
## return 0. Nothing here mutates HP, Block, RNG, cards, statuses or attackers.
func riposte_damage_for_confirmed_hit(statuses: Dictionary, hit_confirmed: bool) -> int:
	if not hit_confirmed or not _valid_statuses(statuses):
		return 0
	var riposte: int = statuses.get("riposte", 0)
	if riposte <= 0:
		return 0
	return riposte


## Projected receipt for an attempted incoming attack on a hero that may bear
## an active one-turn Dodge token. Returns an independent receipt; never touches
## the caller's original dictionary, actual HP, Block, RNG, cards or intents.
## Only integer 0 or 1 for dodge_next_attack is accepted; everything else fails
## closed. On the first confirmed attempt with token 1 the attack misses and the
## token is consumed (removed); on no token (absent or 0) or on an unattempted
## attack nothing changes. A second attempt against the returned state sees no
## token and reports no miss.
func dodge_project_for_attempt(statuses: Dictionary, attempt_made: bool) -> Dictionary:
	var snapshot: Dictionary = statuses.duplicate(true)
	if not attempt_made is bool or not _valid_statuses(statuses):
		return {"ok": false, "miss": false, "statuses": snapshot}
	var next_statuses: Dictionary = statuses.duplicate(true)
	var dodge: Variant = statuses.get("dodge_next_attack", 0)
	if not dodge is int or (dodge != 0 and dodge != 1):
		return {"ok": false, "miss": false, "statuses": snapshot}
	if dodge == 0:
		return {"ok": true, "miss": false, "statuses": next_statuses}
	# dodge == 1
	if attempt_made:
		next_statuses.erase("dodge_next_attack")
		return {"ok": true, "miss": true, "statuses": next_statuses}
	else:
		return {"ok": true, "miss": false, "statuses": next_statuses}


## Fear is the Scarecrow's authored `cannot_buff_next_turn: true` flag, stored on
## the affected enemy as a status whose single accepted value is the literal
## boolean true. This pure query answers whether that enemy's own announced
## self-buff may run during its next enemy turn. It never ages, consumes or
## rewrites the lock: only that actor's owner-turn end removes it. The future
## enemy-phase caller owns hit confirmation, enemy actions and the actual buff;
## this projection only reports permission and changes nothing.
## Absent means "no lock". Any present value other than boolean true, or any
## unsupported status key beside it, is malformed and fails closed.
func can_apply_buff(statuses: Dictionary) -> Dictionary:
	if not _valid_statuses(statuses):
		return {"ok": false, "allowed": false}
	return {"ok": true, "allowed": not statuses.has("cannot_buff_next_turn")}


## One affected actor's turn ends. Bleed is direct HP loss, never Block damage.
## Weak, Exposed and Tangled expire at this boundary, after applying during this turn.
## Riposte is removed completely after this one owner turn, whatever its N was.
## An unspent one-turn Dodge token (0 or 1) also disappears at this boundary.
## Blind is a one-shot "next attack misses" marker, never an N-turn counter: an
## active Blind 1 is copied unchanged to the next state, an inert Blind 0 is
## discarded, and merely ending an owner turn never spends it. Only a later
## attack-attempt resolver may consume the token.
## Fear (`cannot_buff_next_turn: true`) is deliberately not carried into the
## next state: it covers only the affected enemy's next enemy turn, so this same
## owner-turn boundary is where it expires. Weak is authored and aged separately
## and is never created, doubled or cleared by Fear.
## Invalid state returns ok=false and an independent, unchanged deep snapshot.
func end_owner_turn(hp: int, block: int, statuses: Dictionary) -> Dictionary:
	var next_statuses: Dictionary = statuses.duplicate(true)
	if hp < 0 or block < 0 or not _valid_statuses(statuses):
		return {"ok": false, "hp": hp, "block": block, "statuses": next_statuses, "bleed_hp_loss": 0}

	var loss: int = mini(hp, statuses.get("bleed", 0))
	next_statuses.clear()
	for name in ["bleed", "weak", "exposed", "tangled"]:
		var remaining: int = statuses.get(name, 0)
		if remaining > 1:
			next_statuses[name] = remaining - 1
	if statuses.get("blind_next_attack", 0) == 1:
		next_statuses["blind_next_attack"] = 1
	return {"ok": true, "hp": hp - loss, "block": block, "statuses": next_statuses, "bleed_hp_loss": loss}


## Blind shares Dodge's canonical one-shot shape: an integer token 0 (inert) or 1
## (active). No stack, duration or boolean form is accepted.
## Fear's `cannot_buff_next_turn` is the opposite shape: only the literal boolean
## true is accepted, and it is absent when inactive. `false`, `1`, `1.0` and
## `"true"` are malformed rather than inactive.
func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String:
			return false
		if name == "dodge_next_attack" or name == "blind_next_attack":
			var count = statuses[name]
			if not count is int or (count != 0 and count != 1):
				return false
			continue
		if name == "cannot_buff_next_turn":
			var fear = statuses[name]
			if not fear is bool or not bool(fear):
				return false
			continue
		if name not in ["bleed", "weak", "exposed", "tangled", "riposte"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true

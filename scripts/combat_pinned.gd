class_name CombatPinned
extends RefCounted
## Per-enemy Pinned token rule: records which hero pinned each enemy; a later
## pin replaces the earlier one. A successful cross-hero attack consumes the
## token once and grants +5 damage before Weak/Exposed. Same-hero attacks,
## failed attempts, and previews never consume. Tokens persist across turns and
## clear only on explicit combat reset.

var _pinner_by_position: Dictionary = {}
var _consumed: Array[Dictionary] = []
var _relay_used := false
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
var _wardrobe_state: Dictionary = {}
var _torn_state: Dictionary = {}
var _commit: Dictionary = {}


func _init() -> void:
	_pinner_by_position = {}


## Attempts to pin the enemy at the given position with the given pinner ID.
## Returns true on success. Only living enemies at valid positions can be pinned.
func pin_enemy(enemies: CombatEnemies, position: int, pinner_id: String) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	if not _valid_pinner_id(pinner_id):
		return false
	if not enemies._valid_position(position):
		return false
	if enemies.is_slain(position):
		return false
	_pinner_by_position[position] = pinner_id
	return true


## Returns the pinner ID for the enemy at the given position, or empty string if none.
func pinner_for_enemy(position: int) -> String:
	if not _pinner_by_position.has(position):
		return ""
	return _pinner_by_position[position]


## Returns the cross-hero bonus (+5) that would apply if the given attacker
## attacks the enemy at the given position. Returns 0 if no pin, if the attacker
## is the same as the pinner, or if the target is invalid/dead. Does not consume.
func bonus_for_attack(enemies: CombatEnemies, position: int, attacker_id: String) -> int:
	if enemies == null or not enemies.is_valid():
		return 0
	if not _valid_pinner_id(attacker_id):
		return 0
	if not enemies._valid_position(position):
		return 0
	if enemies.is_slain(position):
		return 0
	var pinner: String = _pinner_by_position.get(position, "")
	if pinner.is_empty() or pinner == attacker_id:
		return 0
	return 5


## Consumes the pin after a confirmed successful cross-hero attack.
## Returns true if the pin was consumed, false otherwise.
## Previews (hit_confirmed=false), same-hero attacks, and missing pins never consume.
## Allows consumption on a lethal confirmed hit (enemy reaches 0 HP).
func consume_after_attack(position: int, attacker_id: String, hit_confirmed: bool) -> bool:
	if not hit_confirmed:
		return false
	if not _valid_pinner_id(attacker_id):
		return false
	if not _pinner_by_position.has(position):
		return false
	var pinner: String = _pinner_by_position[position]
	if pinner == attacker_id:
		return false
	_pinner_by_position.erase(position)
	if not _commit.is_empty():
		_consumed.append({"position": position, "pinner": pinner, "consumer": attacker_id})
	return true


## Removes any token on the given position. A lethal confirmed attack clears the
## pin it would otherwise leave on a slain enemy. Returns true when a token was
## removed; missing tokens are a no-op.
func clear_pin(position: int) -> bool:
	if not _pinner_by_position.has(position):
		return false
	_pinner_by_position.erase(position)
	return true


## Clears all pinned tokens. Called at combat end.
func reset_combat() -> void:
	_pinner_by_position.clear()
	_consumed.clear()
	_commit.clear()
	_relay_used = false


func bind_relay(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		wardrobe: RunPatchWardrobe, torn: RunTornMending) -> void:
	_deck = deck
	_party = party
	_enemies = enemies
	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_state = wardrobe.get_snapshot()
	_torn_state = torn.read_state()


## Only the mounted committed resolver opens this boundary, never a forecast.
func begin_confirmed_cast(card_id: String, owner_id: String = "", cost: int = -1) -> void:
	_commit.clear()
	_consumed.clear()
	if _deck == null or _party == null or _enemies == null or not _deck.turn_active:
		return
	if not _deck.hand.has(card_id) or not _party.is_valid() or not _enemies.is_valid():
		return
	_commit = {"card": card_id, "owner": owner_id, "cost": cost, "energy": _deck.energy,
		"hand": _deck.hand.duplicate(), "discard": _deck.discard_pile.duplicate(),
		"enemies": _enemies.get_enemies()}


## Reconcile actual consumed-token provenance with the paid live hit receipt.
## Clear the boundary even on rejection, so stale/replayed receipts are inert.
func finish_confirmed_cast(receipt: Dictionary) -> bool:
	var before := _commit
	var consumed := _consumed.duplicate(true)
	_commit = {}
	_consumed.clear()
	if before.is_empty() or _relay_used or receipt.get("ok") != true:
		return false
	if not _deck.turn_active or _deck.energy < 0:
		return false
	if before.cost >= 0 and _deck.energy != before.energy - before.cost:
		return false
	if before.cost < 0 and _deck.energy >= before.energy:
		return false
	var hand: Array = before.hand.duplicate()
	hand.erase(before.card)
	var discard: Array = before.discard.duplicate()
	discard.append(before.card)
	if hand != _deck.hand.slice(0, hand.size()) or discard != _deck.discard_pile:
		return false
	var hits: Variant = receipt.get("hits", [])
	if not hits is Array:
		return false
	for token in consumed:
		if not before.owner.is_empty() and before.owner != token.consumer:
			continue
		if not active_wearer(_party, _wardrobe, _torn, _wardrobe_state,
				_torn_state, token.pinner, "relay_bobbin"):
			continue
		var consumer_lives := false
		for hero in _party.get_heroes():
			if hero.id == token.consumer and hero.hp > 0:
				consumer_lives = true
		if not consumer_lives or token.consumer == token.pinner:
			continue
		for hit in hits:
			if not hit is Dictionary or hit.get("position") != token.position:
				continue
			var valid_hit := true
			for field in ["damage", "hp_loss", "block_absorbed"]:
				if not hit.get(field) is int or hit[field] < 0:
					valid_hit = false
			if not valid_hit or hit.hp_loss + hit.block_absorbed <= 0:
				continue
			var old: Dictionary = before.enemies[token.position - 1]
			var now := _enemies.get_enemy(token.position)
			if old.hp > 0 and now.id == old.id and hit.get("damage", 0) > 0 \
					and old.hp - now.hp >= hit.get("hp_loss", -1) \
					and old.block - now.block >= hit.get("block_absorbed", -1) \
					and hit.get("hp_loss", -1) >= 0 and hit.get("block_absorbed", -1) >= 0:
				_relay_used = true
				_deck.combat_state.energy = mini(3, _deck.energy + 1)
				return true
	return false


## Frozen authenticated run equipment plus current battle liveness, by identity.
static func active_wearer(party: CombatParty, wardrobe: RunPatchWardrobe,
		torn: RunTornMending, wardrobe_state: Dictionary, torn_state: Dictionary,
		hero_id: String, patch_id: String) -> bool:
	if party == null or not party.is_valid() or wardrobe == null or torn == null:
		return false
	if not wardrobe.is_valid() or not torn.is_valid() \
			or wardrobe.get_snapshot() != wardrobe_state or torn.read_state() != torn_state:
		return false
	if torn_state.get("tear_counts", {}).get(hero_id, -1) != 0:
		return false
	var projection := wardrobe.project_active(torn_state)
	if not projection.get("ok", false) or not projection.active.get(hero_id, []).has(patch_id):
		return false
	for hero in party.get_heroes():
		if hero.id == hero_id:
			return hero.hp > 0
	return false


## The authored hero identities allowed to place or consume a token. The V3-1 Button Golem
## owns a Pin rider (Button Knuckle), so it is admitted beside the original trio; every other
## unknown id still fails closed. Later V3 heroes join this list with their own Pin cards.
func _valid_pinner_id(pinner_id: String) -> bool:
	return pinner_id is String and not pinner_id.is_empty() \
		and pinner_id in ["warden", "seamstress", "tinker", "button_golem"]

class_name CombatHeirloomPatchTriggers
extends RefCounted
## P12 scene-free battle receipt service. Not mounted into the hand or shops.
## Quotes are provisional; only observed real HP/Block contact commits a use.
## This service never owns an inventory, a deck, RNG or a Pinned token.

const CATALOG := "res://data/patches/mpw_heirloom_patches.json"
const NEEDLE := "needle_echo"
const HEM := "shared_hem"

var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _party: CombatParty = null
var _enemies: CombatEnemies = null
var _pinned: CombatPinned = null
var _wardrobe_receipt: Dictionary = {}
var _torn_receipt: Dictionary = {}
var _members: Dictionary = {}
var _valid := false
var _turn := 0
var _ticket := 0
var _needle_used := false
var _hem_used := false
var _pending_needle: Dictionary = {}
var _pending_block: Dictionary = {}


## A rebind, including a rejected rebind, discards all earlier entitlements.
func bind_battle(wardrobe: RunPatchWardrobe, torn: RunTornMending,
        party: CombatParty, enemies: CombatEnemies, pinned: CombatPinned) -> bool:
    _valid = false
    _wardrobe = null
    _torn = null
    _party = null
    _enemies = null
    _pinned = null
    _wardrobe_receipt.clear()
    _torn_receipt.clear()
    _members.clear()
    _turn = 0
    _ticket = 0
    _needle_used = false
    _hem_used = false
    _pending_needle.clear()
    _pending_block.clear()
    if wardrobe == null or torn == null or party == null or enemies == null or pinned == null:
        return false
    if not wardrobe.is_valid() or not torn.is_valid() or not party.is_valid() or not enemies.is_valid():
        return false
    if not _catalog_is_authored():
        return false
    var wardrobe_state: Dictionary = wardrobe.get_snapshot()
    var torn_state: Dictionary = torn.read_state()
    if not _valid_run_state(wardrobe_state, torn_state, party):
        return false
    _wardrobe = wardrobe
    _torn = torn
    _party = party
    _enemies = enemies
    _pinned = pinned
    _wardrobe_receipt = wardrobe_state.duplicate(true)
    _torn_receipt = torn_state.duplicate(true)
    for hero in party.get_heroes():
        _members[hero["id"]] = hero["max_hp"]
    _valid = true
    return true


## Only the exact published P12 records are authority, not ID prefixes.
func _catalog_is_authored() -> bool:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
    if not raw is Array:
        return false
    var seen := {}
    for item in raw:
        if not item is Dictionary:
            return false
        var id: Variant = item.get("id")
        if not id is String or id.is_empty():
            return false
        if not RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED.has(id):
            continue
        if seen.has(id) or not RunAuthoredPatchDefinitions._valid_heirloom(item):
            return false
        seen[id] = true
    for id in [NEEDLE, HEM]:
        if not seen.has(id):
            return false
    return true


## Reject mismatched run ledgers BEFORE project_active (which expects the
## same selected hero IDs), including a detached but otherwise valid trio.
func _valid_run_state(state: Dictionary, torn_state: Dictionary, party: CombatParty) -> bool:
    if state.get("valid") != true or torn_state.get("ok") != true:
        return false
    var run_heroes: Variant = state.get("heroes")
    var torn_heroes: Variant = torn_state.get("heroes")
    var worn: Variant = state.get("worn")
    var owned: Variant = state.get("owned")
    var definitions: Variant = state.get("definitions")
    var tears: Variant = torn_state.get("tear_counts")
    if not run_heroes is Array or not torn_heroes is Array or not worn is Dictionary \
            or not owned is Array or not definitions is Dictionary or not tears is Dictionary:
        return false
    if run_heroes.size() != CombatParty.PARTY_SIZE or torn_heroes != run_heroes \
            or worn.size() != CombatParty.PARTY_SIZE or tears.size() != CombatParty.PARTY_SIZE:
        return false
    var ids := {}
    var worn_ids := {}
    for hero in party.get_heroes():
        var id: Variant = hero.get("id")
        if not id is String or not RunV3PartyAdmission.HERO_IDS.has(id) or ids.has(id):
            return false
        ids[id] = hero.get("max_hp")
    if ids.size() != CombatParty.PARTY_SIZE:
        return false
    for hero in torn_heroes:
        if not hero is Dictionary or not ids.has(hero.get("id")) \
                or hero.get("max_hp") != ids[hero.get("id")]:
            return false
        var id: String = hero["id"]
        if not tears.get(id) is int or tears[id] < 0:
            return false
        var slots: Variant = worn.get(id)
        if not slots is Dictionary or slots.size() != RunPatchWardrobe.SLOTS.size():
            return false
        for slot in RunPatchWardrobe.SLOTS:
            var patch: Variant = slots.get(slot)
            if not patch is String:
                return false
            if patch == "":
                continue
            if not owned.has(patch) or definitions.get(patch) != slot or worn_ids.has(patch):
                return false
            worn_ids[patch] = true
    for id in [NEEDLE, HEM]:
        if owned.has(id) and definitions.get(id) != RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[id]["slot"]:
            return false
    return true


func is_current() -> bool:
    if not _valid or _wardrobe == null or _torn == null or _party == null \
            or _enemies == null or _pinned == null:
        return false
    if not _wardrobe.is_valid() or not _torn.is_valid() or not _party.is_valid() \
            or not _enemies.is_valid():
        return false
    if _wardrobe.get_snapshot() != _wardrobe_receipt \
            or _torn.read_state() != _torn_receipt:
        return false
    var roster := _party.get_heroes()
    if roster.size() != _members.size():
        return false
    for hero in roster:
        if not _members.has(hero.get("id")) or hero.get("max_hp") != _members[hero["id"]]:
            return false
    return true


func _wearer(patch_id: String) -> Dictionary:
    if not is_current():
        return {}
    var slot: String = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[patch_id]["slot"]
    if not _wardrobe_receipt["owned"].has(patch_id) \
            or _wardrobe_receipt["definitions"].get(patch_id) != slot:
        return {}
    var active := _wardrobe.project_active(_torn_receipt)
    if not active.get("ok", false):
        return {}
    for hero in _party.get_heroes():
        var id: String = hero["id"]
        if _wardrobe_receipt["worn"][id].get(slot) != patch_id:
            continue
        if not active["active"].get(id, []).has(patch_id):
            return {}
        if _torn_receipt["tear_counts"].get(id, -1) != 0 or hero["hp"] <= 0:
            return {}
        for run_hero in _torn_receipt["heroes"]:
            if run_hero["id"] == id:
                return hero if run_hero["hp"] > 0 else {}
    return {}


## Explicit owner-turn boundary, including invalidating pending observations.
func start_player_turn() -> bool:
    if not is_current():
        return false
    _turn += 1
    _needle_used = false
    _hem_used = false
    _pending_needle.clear()
    _pending_block.clear()
    return true


## Read the live pin BEFORE a hit. A different hero's hit may consume it
## during resolution; finish_needle_hit does not require it to remain set.
## Caller adds bonus_damage to the authentic hit resolver's damage input.
func quote_needle_hit(attacker_id: Variant, position: Variant) -> Dictionary:
    _pending_needle.clear()
    var rejected := {"ok": false, "bonus_damage": 0}
    if not attacker_id is String or not position is int or _needle_used or _turn == 0:
        return rejected
    var wearer := _wearer(NEEDLE)
    if wearer.is_empty() or wearer["id"] != attacker_id:
        return rejected
    var before := _enemies.get_enemy(position)
    if before.is_empty() or before.get("hp", 0) <= 0:
        return rejected
    var pinner := _pinned.pinner_for_enemy(position)
    if pinner.is_empty() or not RunV3PartyAdmission.HERO_IDS.has(pinner):
        return rejected
    _ticket += 1
    var quote := {"ok": true, "bonus_damage": 1, "ticket": _ticket, "turn": _turn,
        "attacker_id": attacker_id, "position": position}
    _pending_needle = {"quote": quote.duplicate(true),
        "before": before.duplicate(true), "pinner": pinner}
    return quote.duplicate(true)


## A sealed, still-live quote may authorize ONLY the one supported held-hand
## Warden starter hit. The caller's claimed bonus is never the authority.
func authorizes_needle_hit(quote: Dictionary, party: CombatParty,
        enemies: CombatEnemies, card_id: String, position: int) -> bool:
    if card_id not in ["warden_strike", "warden_strike_plus"] \
            or party != _party or enemies != _enemies or _pending_needle.is_empty() \
            or _needle_used or not is_current() or _turn <= 0:
        return false
    if quote != _pending_needle["quote"] or quote.get("ok") != true \
            or quote.get("bonus_damage") != 1 or quote.get("position") != position \
            or quote.get("attacker_id") != "warden" or quote.get("turn") != _turn:
        return false
    var wearer := _wearer(NEEDLE)
    if wearer.is_empty() or wearer["id"] != "warden":
        return false
    var old: Dictionary = _pending_needle["before"]
    var now := _enemies.get_enemy(position)
    return not now.is_empty() and now == old and now.get("hp", 0) > 0 \
        and _pinned.pinner_for_enemy(position) == _pending_needle["pinner"]


## A refused paid commit must not leave a quote capable of later replay.
func cancel_needle_hit() -> void:
    _pending_needle.clear()


## Accept either the genuine CombatStatusAttacks event or a CombatAttackCards
## result with hit rows; require exact authoritative Block/HP deltas, not the
## mere claim of a paid card, label, preview, or non-contact success.
func finish_needle_hit(quote: Variant, receipt: Variant) -> bool:
    if _pending_needle.is_empty() or not quote is Dictionary \
            or quote != _pending_needle["quote"]:
        return false
    var pending := _pending_needle.duplicate(true)
    _pending_needle.clear()
    if _needle_used or not is_current() or not receipt is Dictionary \
            or receipt.get("ok") != true:
        return false
    var wearer := _wearer(NEEDLE)
    if wearer.is_empty() or wearer["id"] != quote["attacker_id"]:
        return false
    var position: int = quote["position"]
    var old: Dictionary = pending["before"]
    var now := _enemies.get_enemy(position)
    if now.is_empty() or old.get("id") != now.get("id") or old.get("hp", 0) <= 0:
        return false
    var pin_after := _pinned.pinner_for_enemy(position)
    if pin_after != "" and pin_after != pending["pinner"]:
        return false
    var hit: Variant = receipt
    if receipt.has("hits"):
        hit = null
        if not receipt["hits"] is Array:
            return false
        for row in receipt["hits"]:
            if row is Dictionary and row.get("position") == position:
                if hit != null:
                    return false
                hit = row
    if not hit is Dictionary:
        return false
    for field in ["damage", "hp_loss", "block_absorbed"]:
        if not hit.get(field) is int or hit[field] < 0:
            return false
    var contact: int = hit["hp_loss"] + hit["block_absorbed"]
    if hit["damage"] <= 0 or contact <= 0 or contact > hit["damage"]:
        return false
    if old["hp"] - now["hp"] != hit["hp_loss"] \
            or old["block"] - now["block"] != hit["block_absorbed"]:
        return false
    _needle_used = true
    return true


## Observe a genuine party transition, not the printed Block effect on a card.
## No caller-supplied before/after dictionaries can forge an award.
func begin_block_gain(source_id: Variant) -> Dictionary:
    _pending_block.clear()
    var rejected := {"ok": false}
    if not source_id is String or _hem_used or _turn == 0 or not is_current():
        return rejected
    var wearer := _wearer(HEM)
    if wearer.is_empty() or wearer["id"] == source_id:
        return rejected
    var source: Dictionary = {}
    for hero in _party.get_heroes():
        if hero["id"] == source_id:
            source = hero
    if source.is_empty() or source["hp"] <= 0:
        return rejected
    _ticket += 1
    var quote := {"ok": true, "ticket": _ticket, "turn": _turn,
        "source_id": source_id, "wearer_id": wearer["id"]}
    _pending_block = {"quote": quote.duplicate(true), "source": source.duplicate(true),
        "wearer": wearer.duplicate(true)}
    return quote.duplicate(true)


## Only CombatParty.gain_block performs the one-point bonus. Replaying a
## receipt, resetting the turn, or rebinding never repeats the side effect.
func finish_block_gain(quote: Variant) -> int:
    if _pending_block.is_empty() or not quote is Dictionary \
            or quote != _pending_block["quote"]:
        return 0
    var pending := _pending_block.duplicate(true)
    _pending_block.clear()
    if _hem_used or not is_current():
        return 0
    var wearer := _wearer(HEM)
    if wearer.is_empty() or wearer["id"] != quote["wearer_id"] \
            or wearer != pending["wearer"]:
        return 0
    var before: Dictionary = pending["source"]
    var now: Dictionary = {}
    for hero in _party.get_heroes():
        if hero["id"] == quote["source_id"]:
            now = hero
    if now.is_empty() or now["hp"] <= 0 or before["hp"] <= 0 \
            or now["hp"] != before["hp"] or now["max_hp"] != before["max_hp"] \
            or now["position"] != before["position"] \
            or now["block"] <= before["block"]:
        return 0
    if not _party.gain_block(wearer["position"], 1):
        return 0
    _hem_used = true
    return 1

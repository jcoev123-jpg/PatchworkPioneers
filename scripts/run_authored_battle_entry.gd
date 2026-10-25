class_name RunAuthoredBattleEntry
extends RefCounted
## Scene-free entry for an ALREADY committed, legal RunMap Fight/Elite/Boss.
## entry_current_battle(map, run_rng, selector) returns {"success": false}
## atomically on rejection; on success it returns {"success": true,
## "node_type": String, "encounter_id": String, "definitions": Array,
## "enemies": CombatEnemies, "intents": CombatEnemyIntents}.
## Uses the run's ONE RNG and selector; does not choose a node, launch a
## scene, modify party/deck/gold, or change any authored JSON. Each call
## creates independent actor and intent instances, including cached reads.
##
## The typed selector still chooses the canonical encounter (and its authored
## positional schedule, returned as "definitions"/"intents"). On an ordinary
## Fight that encounter only supplies the executable action formats and the
## canonical encounter ID: the concrete enemy group is drawn from the current
## floor band through the accepted RunV3FloorBandRoster, with the same run RNG,
## and the group is cached with the node so re-entry never rerolls it. Elite and
## floor-12 Boss keep their typed authored rosters. Floor HP scaling stays with
## the live app caller (once, after entry), never here.

const POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const CATALOG_PATHS := [
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
    "res://data/enemies/boss.json",
    "res://data/enemies/m04_elites.json",
]
## Only these catalogs hold ordinary normal-Fight actors; the Boss and Elite
## catalogs are deliberately excluded from every floor band.
const BAND_CATALOG_PATHS := [
    "res://data/enemies/starter_enemies.json",
    "res://data/enemies/run_enemies.json",
]
const BOSS_FLOOR := 12


func entry_current_battle(map: RunMap, run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection) -> Dictionary:
    if map == null or run_rng == null or selector == null:
        return {"success": false}
    var file := FileAccess.open(POOLS_PATH, FileAccess.READ)
    if file == null:
        return {"success": false}
    var parser := JSON.new()
    var parse_error := parser.parse(file.get_as_text())
    file.close()
    if parse_error != OK:
        return {"success": false}
    return _entry_from_data(map, run_rng, selector, parser.data)


## Narrow injection seam for negative tests. Does not retain or mutate the
## supplied registry; production always reads POOLS_PATH above. The optional
## band_pools argument likewise never leaves tests: production derives the
## three floor bands from the authored normal-enemy catalogs.
func _entry_from_data(map: RunMap, run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection, registry: Variant,
        band_pools: Variant = null) -> Dictionary:
    var failure := {"success": false}
    if map == null or run_rng == null or selector == null or not map.is_generated():
        return failure
    var current_id: String = map.get_current_node_id()
    if current_id.is_empty() or not map.get_route().has(current_id):
        return failure
    var node: Dictionary = map.get_node(current_id)
    var kind = node.get("type")
    if not kind is String or kind not in ["Fight", "Elite", "Boss"]:
        return failure
    if not registry is Dictionary or not registry.has(kind) or not registry[kind] is Dictionary:
        return failure
    var candidates: Dictionary = registry[kind]
    if candidates.is_empty():
        return failure

    # A malformed *other* kind cannot prevent entry at the current kind.
    # Validate ALL candidates of this kind before the selector can draw/cache.
    var available_normal := {}
    var available_boss := {}
    for catalog_index in range(CATALOG_PATHS.size()):
        var file := FileAccess.open(CATALOG_PATHS[catalog_index], FileAccess.READ)
        if file == null:
            return failure
        var records := RunTypedBattleRoster._parse_catalog_text(file.get_as_text())
        file.close()
        if records.is_empty():
            return failure
        for record in records:
            var enemy_id: String = record["id"]
            # RunTypedBattleRoster.assemble remains responsible for rejecting
            # duplicates spanning multiple catalogs and invalid actor models.
            if catalog_index == 2:
                available_boss[enemy_id] = true
            else:
                available_normal[enemy_id] = true

    # Only these two M05 Fight alternatives intentionally reuse earlier schedules.
    # All pre-existing named encounters must keep their canonical binding.
    var schedule_aliases := {
        "felt_moth_pressure": "res://data/encounters/bobbin_skirmish.json",
        "pin_thread_crossfire": "res://data/encounters/buttonhole_holdout.json",
    }
    var paths := {}
    var rosters := {}
    var schedules := {}
    var assembler := RunTypedBattleRoster.new()
    for id in candidates:
        if not id is String or id.strip_edges().is_empty() or id != id.strip_edges():
            return failure
        var entry = candidates[id]
        if not entry is Dictionary or entry.size() != 2 or not entry.has("schedule") \
                or not entry.has("enemy_ids"):
            return failure
        var path = entry["schedule"]
        var ids = entry["enemy_ids"]
        # Several named Fight alternatives intentionally reuse a validated
        # two-source schedule. Keep the path canonical and inside encounters.
        if not path is String or path.get_base_dir() != "res://data/encounters" \
                or not path.ends_with(".json") or path != path.simplify_path() \
                or (path != "res://data/encounters/%s.json" % id
                    and not (kind == "Fight" and schedule_aliases.get(id) == path)) \
                or not FileAccess.file_exists(path) or not ids is Array or ids.is_empty():
            return failure
        for enemy_id in ids:
            if not enemy_id is String or not (available_boss if kind == "Boss" \
                    else available_normal).has(enemy_id):
                return failure
        var schedule_file := FileAccess.open(path, FileAccess.READ)
        if schedule_file == null:
            return failure
        var definitions := RunFightEncounterSelection._parse_schedule_text(
            schedule_file.get_as_text())
        schedule_file.close()
        if definitions.is_empty():
            return failure
        var binding := {}
        binding[id] = ids
        var probe := assembler.assemble({
            "success": true, "node_type": kind, "encounter_id": id,
            "definitions": definitions,
        }, binding, CATALOG_PATHS)
        if not probe.get("ok", false):
            return failure
        paths[id] = path
        rosters[id] = ids.duplicate(true)
        schedules[id] = definitions

    # Ordinary Fights need their legal floor band beside the schedule. Both the
    # authored normal records and the three bands are validated before the
    # selector can consume the run RNG or cache anything.
    var floor_number = node.get("floor")
    var band_material := {"ok": true, "pools": {}, "records": {}}
    if kind == "Fight":
        if not floor_number is int or floor_number < 1 or floor_number >= BOSS_FLOOR:
            return failure
        band_material = _floor_band_material(band_pools)
        if not band_material.get("ok", false):
            return failure

    # Everything from here on can spend the run RNG, so keep an exact receipt
    # of the selector and generator to roll back a late, unexpected rejection.
    var rng_before: int = run_rng.state
    var bound_before: RunMap = selector._bound_map
    var cached_before: Dictionary = selector._selected.duplicate(true)

    var typed_pools := {}
    typed_pools[kind] = paths
    var selected := selector.select_current_battle(map, run_rng, typed_pools)
    if not selected.get("success", false) or selected.get("node_type") != kind:
        _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
        return failure
    var chosen = selected.get("encounter_id")
    # A previously cached encounter from a different pool must not be
    # substituted for the newly validated binding.
    if not chosen is String or not schedules.has(chosen) \
            or selected.get("definitions") != schedules[chosen]:
        _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
        return failure
    var assembled := assembler.assemble(selected, rosters, CATALOG_PATHS)
    if not assembled.get("ok", false):
        _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
        return failure
    var detached: Array = assembled["definitions"].duplicate(true)
    var enemies: CombatEnemies = assembled["enemies"]
    var group: Array = []
    if kind == "Fight":
        var count: int = detached.size()
        if count < RunV3FloorBandRoster.MIN_GROUP_SIZE \
                or count > RunV3FloorBandRoster.MAX_GROUP_SIZE:
            _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
            return failure
        var resolved := _resolve_floor_group(map, run_rng, selector, current_id,
            count, floor_number, band_material, selected)
        if not resolved.get("ok", false):
            _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
            return failure
        group = resolved["enemy_ids"]
        var ordered: Array = []
        var seen: Array[String] = []
        for enemy_id in group:
            if not enemy_id is String or enemy_id in seen \
                    or not band_material["records"].has(enemy_id):
                _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
                return failure
            seen.append(enemy_id)
            ordered.append(band_material["records"][enemy_id].duplicate(true))
        enemies = CombatEnemies.new(ordered)
        if not enemies.is_valid() or enemies.get_enemies().size() != count:
            _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
            return failure
    var intents := CombatEnemyIntents.new(detached)
    if not intents.is_valid():
        _restore_entry_state(run_rng, selector, rng_before, bound_before, cached_before)
        return failure
    # Commit the group into the selector's node cache only now, so a cached
    # re-entry later returns the same group without another draw.
    if kind == "Fight":
        selector._selected[current_id]["enemy_ids"] = group.duplicate()
    return {
        "success": true,
        "node_type": kind,
        "encounter_id": chosen,
        "definitions": detached,
        "enemies": enemies,
        "intents": intents,
    }


## Restore the exact run-RNG and selector receipt after a late rejection.
static func _restore_entry_state(run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection, rng_state: int,
        bound_map: RunMap, cached: Dictionary) -> void:
    run_rng.state = rng_state
    selector._bound_map = bound_map
    selector._selected = cached


## The exact committed group for this node: a cached group is re-validated
## against the current floor band, otherwise one legal group is drawn with the
## run RNG through the accepted floor-band service.
func _resolve_floor_group(map: RunMap, run_rng: RandomNumberGenerator,
        selector: RunFightEncounterSelection, current_id: String, count: int,
        floor_number: int, band_material: Dictionary,
        selected: Dictionary) -> Dictionary:
    var pools: Dictionary = band_material["pools"]
    var band: String = RunV3FloorBandRoster._band_for_floor(floor_number)
    if band.is_empty() or not pools.has(band):
        return {"ok": false}
    var candidates: Array = pools[band]
    if not candidates is Array or candidates.size() < count:
        return {"ok": false}
    var group: Array = []
    if selected.has("enemy_ids"):
        var cached = selected["enemy_ids"]
        if not cached is Array or cached.size() != count or not _legal_group(
                cached, candidates, band_material["records"]):
            return {"ok": false}
        group = cached.duplicate()
    else:
        var picked := RunV3FloorBandRoster.new().pick(
            floor_number, count, run_rng, pools)
        if not picked.get("ok", false) or picked.get("band") != band:
            return {"ok": false}
        var drawn = picked.get("enemy_ids")
        if not drawn is Array or drawn.size() != count or not _legal_group(
                drawn, candidates, band_material["records"]):
            return {"ok": false}
        group = drawn.duplicate()
    return {"ok": true, "enemy_ids": group}


## Distinct, trimmed String IDs that all belong to the current band and have an
## authenticated normal-enemy record with an authored executable intent.
static func _legal_group(ids: Array, band_candidates: Array,
        records: Dictionary) -> bool:
    var seen: Array[String] = []
    for enemy_id in ids:
        if not enemy_id is String or enemy_id.is_empty() \
                or enemy_id != enemy_id.strip_edges() or enemy_id in seen:
            return false
        if not band_candidates.has(enemy_id) or not records.has(enemy_id):
            return false
        seen.append(enemy_id)
    return not seen.is_empty()


## Read only the ordinary normal-enemy catalogs and split their authored actors
## into the three exact floor bands, ordered by authored max HP and then ID so
## the weakest actors fight early and the strongest late. Every band is checked
## before any RNG draw. band_pools is the test-only injection seam.
static func _floor_band_material(band_pools: Variant) -> Dictionary:
    var records := {}
    var entries: Array = []
    for path in BAND_CATALOG_PATHS:
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            return {"ok": false}
        var parsed := RunTypedBattleRoster._parse_catalog_text(file.get_as_text())
        file.close()
        if parsed.is_empty():
            return {"ok": false}
        for record in parsed:
            var enemy_id: String = record["id"]
            if records.has(enemy_id) or not _is_playable_normal(record):
                return {"ok": false}
            records[enemy_id] = record
            entries.append({"id": enemy_id, "max_hp": record["max_hp"]})
    if entries.size() < RunV3FloorBandRoster.MIN_IDS_PER_BAND \
            * RunV3FloorBandRoster.BAND_KEYS.size():
        return {"ok": false}
    entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if a["max_hp"] != b["max_hp"]:
            return a["max_hp"] < b["max_hp"]
        return a["id"] < b["id"])
    var ordered_ids: Array = []
    for entry in entries:
        ordered_ids.append(entry["id"])
    var pools := _split_floor_bands(ordered_ids)
    if band_pools != null:
        if not band_pools is Dictionary:
            return {"ok": false}
        pools = band_pools
    if RunV3FloorBandRoster._validated_bands(pools).is_empty():
        return {"ok": false}
    return {"ok": true, "pools": pools, "records": records}


## Three contiguous, non-overlapping bands of the ordered normal roster. The
## larger remainder goes to the earlier bands so each stays at the authored
## minimum group size whenever the roster is large enough.
static func _split_floor_bands(ordered_ids: Array) -> Dictionary:
    var total := ordered_ids.size()
    if total < RunV3FloorBandRoster.MIN_IDS_PER_BAND * 3:
        return {}
    var low_end := int(ceilf(total / 3.0))
    var mid_end := low_end + int(ceilf((total - low_end) / 2.0))
    return {
        RunV3FloorBandRoster.BAND_LOW: ordered_ids.slice(0, low_end),
        RunV3FloorBandRoster.BAND_MID: ordered_ids.slice(low_end, mid_end),
        RunV3FloorBandRoster.BAND_HIGH: ordered_ids.slice(mid_end, total),
    }


## A normal-Fight actor needs its authored identity, art and a fully executable
## weighted intent; anything else fails the whole entry closed.
static func _is_playable_normal(record: Dictionary) -> bool:
    for field in ["name", "art_path"]:
        var value = record.get(field)
        if not value is String or value.strip_edges().is_empty():
            return false
    var max_hp = record.get("max_hp")
    if not max_hp is int or max_hp <= 0:
        return false
    return not CombatEnemyIntents._weighted_slot(1, record.get("intent")).is_empty()

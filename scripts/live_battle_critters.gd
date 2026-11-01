extends RefCounted
## Small authored animal loops perched on each still battle backdrop (a rabbit
## on the meadow hills, an owl in the woods...). Each loop is one strip of
## square cells played at 12 fps; the ambient layer draws them itself for its
## admitted profile, so no extra node exists. Fast mode holds every critter on
## its first cell. Absent strips draw nothing.

const FPS := 12.0
const DIR := "res://assets/paper/critters/"
## profile -> [critter id, bottom-centre anchor as a fraction of the stage,
## cell height as a fraction of the stage height, mirrored]. Anchors sit on the
## far horizon or in the sky, above the fighters' heads and intent badges.
const PLACEMENTS := {
	"pollen": [["meadow_rabbit", Vector2(0.345, 0.255), 0.078, false],
		["meadow_moth", Vector2(0.47, 0.15), 0.111, true]],
	"leaves": [["woods_owl", Vector2(0.12, 0.2), 0.123, false],
		["woods_squirrel", Vector2(0.345, 0.255), 0.103, true]],
	"fireflies": [["marsh_frog", Vector2(0.345, 0.255), 0.069, false],
		["marsh_dragonfly", Vector2(0.5, 0.14), 0.092, true]],
	"snow": [["peaks_fox", Vector2(0.345, 0.255), 0.112, false],
		["peaks_owl", Vector2(0.93, 0.18), 0.095, true]],
	"ash": [["ruins_crow", Vector2(0.1, 0.21), 0.121, false],
		["ruins_rat", Vector2(0.345, 0.255), 0.114, true]],
	"scraps": [["boss_bat", Vector2(0.55, 0.16), 0.179, false],
		["boss_mouse", Vector2(0.345, 0.255), 0.105, true]],
}

## Admit every strip once, before seeded play; absent art is simply skipped.
static func load_strips() -> Dictionary:
	var strips := {}
	for family in PLACEMENTS:
		for spot in PLACEMENTS[family]:
			var path: String = DIR + spot[0] + "_loop.png"
			if FileAccess.file_exists(path) and ResourceLoader.exists(path, "Texture2D"):
				strips[spot[0]] = load(path) as Texture2D
	return strips


## Pure placement, shared by the renderer and diagnostics.
static func critters_for(family: String, bounds: Vector2, elapsed: float, fast_mode: bool, sizes: Dictionary) -> Array:
	var marks: Array = []
	if not PLACEMENTS.has(family) or bounds.x < 40.0 or bounds.y < 40.0:
		return marks
	for spot in PLACEMENTS[family]:
		if not sizes.has(spot[0]):
			continue
		var strip: Vector2 = sizes[spot[0]]
		var count := maxi(1, int(strip.x / strip.y))
		var cell := 0 if fast_mode else int(elapsed * FPS) % count
		var side: float = bounds.y * spot[2]
		var foot: Vector2 = bounds * spot[1]
		var rect := Rect2(foot - Vector2(side * 0.5, side), Vector2(side, side))
		if spot[3]:
			rect = Rect2(rect.position + Vector2(side, 0.0), Vector2(-side, side))
		marks.append({"id": spot[0], "rect": rect, "src": Rect2(strip.y * cell, 0.0, strip.y, strip.y)})
	return marks

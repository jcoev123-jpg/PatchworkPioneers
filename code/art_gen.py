"""
Paper-art asset generator: ChatGPT image generation in the relay Chrome, with the owner's style
references attached (see .review/full_game/ART_STYLE.md).

    generate(category, asset_id, description) -> raw PNG bytes (transparent where the category allows)
    process(raw_png, out_png, category)       -> trimmed, scaled game asset

The planner requests assets in an @@ASSETS_START@@ block, one per line: `<category>/<id>: <description>`.

    python art_gen.py <category>/<id> "<description>"     # one-off generation into the repo
"""
from __future__ import annotations

import base64
import io
import json
import os
import re
import sys
import threading
import time
from pathlib import Path
from typing import Callable

import game as G

HERE = Path(__file__).resolve().parent
REFS_DIR = HERE.parent / "full_game" / "art_refs"
RAW_DIR = HERE.parent / "full_game" / "art_raw"          # gitignored originals (about 2 MB each)

CATEGORIES = {
    # category: (max side px, transparent?, framing)
    "enemies": (256, True, "a single enemy character, full body, walking to the RIGHT in a 3/4 view"),
    "bosses": (512, True, "a single large boss character, full body, heavy and imposing, walking to the RIGHT in a 3/4 view"),
    "heroes": (320, True, "a single hero character, full body, heroic ready pose, facing RIGHT in a 3/4 view"),
    "troops": (192, True, "a single small soldier unit, full body, facing RIGHT in a 3/4 view"),
    "towers": (320, True, "a single tower-defense tower building seen from a front 3/4 view, base at the bottom, whole building visible"),
    "projectiles": (96, True, "a single small projectile or missile, flying to the RIGHT"),
    "vfx": (256, True, "a single visual effect burst made of paper scraps"),
    "props": (256, True, "a single map decoration prop (for example a tree, rock or ruin) seen from a 3/4 top-down view"),
    "portraits": (512, True, "a head-and-shoulders character portrait, facing slightly RIGHT"),
    "icons": (128, True, "a single bold square game icon, centred, readable at small size"),
    "ui": (512, True, "a blank patchwork user-interface piece (a stitched fabric-and-paper panel, a torn cardboard, "
                      "wood or leather plank button with stitched edges, a pinned ribbon or a sewn badge) seen "
                      "straight-on and flat, with even straight-ish edges so it can be stretched as a 9-slice, NO "
                      "text or letters on it"),
    "terrain": (1280, False, "a seamless, tileable texture swatch filling the whole square, seen from directly above"),
    "backgrounds": (1280, False, "a full-bleed wide 16:9 scene illustration with no characters and no text"),
    # stage briefings: as "ui" they came out as cut-out landmarks with blank label tabs (2026-10-07)
    "briefings": (1024, False, "a full-bleed wide 16:9 illustration of a battle location seen from an elevated 3/4 "
                               "view, the scene filling the whole canvas edge to edge, no frame, no labels, no text"),
    "cards": (768, False, "a portrait-orientation 3:4 playing-card illustration that fills the whole canvas, one clear "
                          "central subject, no text, no card frame or border"),
}

# Owner 2026-10-17 ("make the game visuals match the character artstyles"): every image uses the PATCHWORK style of
# the approved character sprites (art_refs/ref_8..12) and, for UI and screens, the owner's patchwork menu
# (ref_13_menu_ui.jpg). The old torn-paper ref_1..4 are no longer attached (style_sheet below).
STYLE = (
    "Use the attached reference sheet ONLY for the ART STYLE, never for its subjects, layout or text: PATCHWORK craft "
    "made of cut paper, card, felt and fabric pieces with torn, fibrous edges, sewn together with visible cross "
    "stitches and running stitches, stitched-on patches, and where it suits the subject sewn buttons, rivets, safety "
    "pins and rope lacing; flat matte layers, little paint, no gloss, no outlines, no gradients. It must NOT look "
    "like a 3D render, low-poly model, clay or plastic. Palette: muted earthy colours (olive and moss green, brown, "
    "rust orange, dusty purple, slate blue, bone grey, charcoal) with one or two brighter accent patches; use the "
    "palette given for this subject when one is given. It will be shown small in a game (about 64 to 128 pixels "
    "tall), so use FEWER, LARGER pieces than a poster would and an instantly readable silhouette. Characters and "
    "creatures are chibi like the reference characters: an oversized head (about a third of the height) on a "
    "compact body, mismatched eyes (one huge round staring eye, one droopy, narrowed or X-stitched eye) with dark "
    "eye bags; unsettling-cute, not gory."
)
STYLE = G.GAME.get("art_style") or STYLE
CHAR_REFS = tuple(G.GAME.get("art_refs", {}).get("chars") or (
    "ref_8_harpy.jpg", "ref_9_viking.jpg", "ref_10_troll.jpg", "ref_11_ranger.jpg", "ref_12_wizard.jpg"))
UI_REF = G.GAME.get("art_refs", {}).get("ui") or "ref_13_menu_ui.jpg"
# A short form of the style for backends that lose the subject in long prompts (meta_prompt, Flow).
STYLE_SHORT = G.GAME.get("art_style_short") or (
    "Patchwork craft exactly like the attached reference (cut paper, card and felt pieces with torn fibrous edges "
    "sewn together with visible cross stitches, flat matte layers, chibi characters with mismatched eyes)")
# Accent styles (owner 2026-10-25: "a combination of artstyles ... the main artstyle is kept gothic ragdoll"): each
# relay.json game.art_accents entry {name, categories, match, match_categories, style, short, ref} replaces the main
# style and reference for its categories, and for a match_categories asset whose description matches the regex "match".
ACCENTS = [a for a in (G.GAME.get("art_accents") or []) if a.get("name") and a.get("style") and a.get("ref")]


def accent_for(category: str | None, description: str = "") -> dict | None:
    for a in ACCENTS:
        if category in a.get("categories", ()) or (a.get("match") and category in a.get("match_categories", ())
                                                   and re.search(a["match"], description or "", re.I)):
            return a
    return None


def accent_of(prompt: str | None) -> dict | None:
    """The accent a built prompt was written in (build_prompt starts the prompt with its style)."""
    return next((a for a in ACCENTS if prompt and prompt.startswith(a["style"])), None)
# The game's own framing per category (relay.json game.art_framing): a string replaces the framing text, a list
# [max px, transparent, framing] defines the category outright.
for _cat, _fr in (G.GAME.get("art_framing") or {}).items():
    if isinstance(_fr, str) and _cat in CATEGORIES:
        CATEGORIES[_cat] = (*CATEGORIES[_cat][:2], _fr)
    elif isinstance(_fr, (list, tuple)) and len(_fr) == 3:
        CATEGORIES[_cat] = (int(_fr[0]), bool(_fr[1]), str(_fr[2]))
CHAR_CATEGORIES = ("enemies", "bosses", "heroes", "troops", "portraits")


def style_sheet(category: str | None, prompt: str | None = None) -> Path:
    """The ONE reference image sent with a request: the accent's own reference when the prompt is in an accent
    style, else the character refs in a row (characters), the UI ref (ui, icons), or the UI ref above the character
    row (everything else)."""
    from PIL import Image
    accent = accent_of(prompt)
    if accent:
        out = HERE / "firefly_slots" / f"style_accent_{re.sub(r'[^a-z0-9]+', '_', accent['name'].lower())}.png"
        if not out.exists():
            out.parent.mkdir(parents=True, exist_ok=True)
            Image.open(REFS_DIR / accent["ref"]).convert("RGB").save(out)
        return out
    group = "chars" if category in CHAR_CATEGORIES else ("ui" if category in ("ui", "icons") else "mixed")
    out = HERE / "firefly_slots" / f"style_{group}.png"
    if out.exists():
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    tiles = []
    for name in CHAR_REFS:
        im = Image.open(REFS_DIR / name).convert("RGB")
        w, h = im.size
        s = min(w, h)
        tiles.append(im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s)).resize((300, 300)))
    strip = Image.new("RGB", (300 * len(tiles) + 16 * (len(tiles) + 1), 332), (245, 242, 236))
    for i, t in enumerate(tiles):
        strip.paste(t, (16 + i * 316, 16))
    menu = Image.open(REFS_DIR / UI_REF).convert("RGB")
    if group == "chars":
        sheet = strip
    elif group == "ui":
        sheet = menu
    else:
        menu = menu.resize((strip.width, round(menu.height * strip.width / menu.width)))
        sheet = Image.new("RGB", (strip.width, menu.height + strip.height), (245, 242, 236))
        sheet.paste(menu, (0, 0))
        sheet.paste(strip, (0, menu.height))
    sheet.save(out)
    return out

DESIGNS_PATH = HERE.parent / "full_game" / "CHARACTER_DESIGNS.md"
COPILOT_URL = "https://copilot.microsoft.com/"
COPILOT_EDITOR = '[aria-label="Message Copilot"][contenteditable="true"]'
COPILOT_FILE = "input#upload-file-button"
COPILOT_MAX_REFS = 2
GEMINI_URL = "https://gemini.google.com/app"
GEMINI_EDITOR = '[aria-label="Enter a prompt for Gemini"]'
GEMINI_MAX_REFS = 2
GEMINI_IMAGE = "generated-image img.image"
# Gemini's blob URLs cannot be re-fetched; copy the displayed image through a canvas instead.
CANVAS_IMAGE_JS = """e => { const c = document.createElement('canvas'); c.width = e.naturalWidth;
    c.height = e.naturalHeight; c.getContext('2d').drawImage(e, 0, 0);
    return c.toDataURL('image/png').split(',')[1]; }"""
DEFAULT_BACKENDS = ("firefly", "copilot", "bing", "gemini", "meta")   # owner choice: no ChatGPT images; Meta AI added 2026-10-06
META_URL = "https://www.meta.ai/"
BING_URL = "https://www.bing.com/images/create"
FIREFLY_URL = "https://firefly.adobe.com/generate/image"
PERCHANCE_URL = "https://perchance.org/ai-text-to-image-generator"
BACKEND_UNTIL = {"firefly": "2026-10-14"}   # owner's Firefly Pro trial (second one, from 2026-10-07)
BACKEND_GAP_S = {"firefly": 15, "gemini": 60, "sogni": 30, "flow": 30, "chatgpt": 60}   # gemini: owner "use gemini app more" (2026-10-07 16:00)   # owner: use every service slowly so none of them rate-limits or flags the account
BING_BLOCK_RE = re.compile(r"content warning|unsafe image content|blocked by our content policy|can.t create that", re.I)
META_EDITOR = '[contenteditable="true"]:visible'   # Meta also has a hidden editable box; never type into that one
META_IMAGE = 'img[data-testid="ur-image-tile"]'
META_CHIP = '[aria-label^="Open "], [aria-label^="Remove"]'
META_MAX_REFS = 2
BLOCK_PATH = HERE / "art_blocked.json"      # backends waiting for the owner to clear a security check
PACE_PATH = HERE / "art_pace.json"          # last generation time per backend
MIN_GAP_S = 120                             # at least this long between images on one service (owner: go slow)
# Bot/security checks are for the human owner to clear; the relay never interacts with them.
SECURITY_SEL = {
    "copilot": '[aria-label*="security check" i], iframe[src*="captcha" i], iframe[title*="challenge" i]',
    "gemini": 'iframe[src*="recaptcha" i], iframe[title*="recaptcha" i], form[action*="sorry" i]',
    "meta": 'iframe[src*="captcha" i], iframe[title*="challenge" i], form[action*="checkpoint" i]',
    "bing": 'iframe[src*="captcha" i], iframe[title*="challenge" i], #turnstile-widget',
    "firefly": 'iframe[src*="captcha" i], iframe[title*="challenge" i]',
}
SECURITY_TEXT = re.compile(r"unusual traffic|verify (that )?you('| a)re (a )?human|are you a robot|security check", re.I)


class SecurityCheck(Exception):
    pass


def _load(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def blocked_backends() -> dict:
    return _load(BLOCK_PATH)


def clear_block(backend: str | None = None) -> None:
    data = blocked_backends()
    for k in ([backend] if backend else list(data)):
        data.pop(k, None)
    BLOCK_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def _security_check(page, backend: str) -> bool:
    try:
        # Only a VISIBLE check counts: Copilot keeps a hidden "Security check required" box in the page.
        if page.locator(SECURITY_SEL[backend]).filter(visible=True).count():
            return True
        return bool(SECURITY_TEXT.search(page.locator("body").inner_text(timeout=5_000)[-3000:]))
    except Exception:
        return False


DESIGN_LOCK = threading.Lock()
PACE_LOCK = threading.Lock()


def _wait_for(backend: str) -> float:
    last = _load(PACE_PATH).get(backend, 0)
    return BACKEND_GAP_S.get(backend, MIN_GAP_S) - (time.time() - last)


def _pace(backend: str, log) -> None:
    wait = _wait_for(backend)
    if wait > 0:
        log(f"art: pacing {backend} for {int(wait)}s")
        time.sleep(wait)
    _paced(backend)   # claim it now, so parallel workers pick a different service meanwhile


def _paced(backend: str) -> None:
    with PACE_LOCK:
        data = _load(PACE_PATH)
        data[backend] = time.time()
        PACE_PATH.write_text(json.dumps(data), encoding="utf-8")
FETCH_IMAGE_JS = """async (e) => {
    const r = await fetch(e.currentSrc || e.src); const b = await r.blob();
    const buf = new Uint8Array(await b.arrayBuffer()); let s = "";
    for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
    return {type: b.type, b64: btoa(s)}; }"""
# Calibrated on the first three paper bosses, which looked alike: colour 0.94-0.97, shape 0.57-0.68.
SIMILAR_HUE = 0.88      # cosine similarity of saturation-weighted hue histograms: same colour family...
SIMILAR_HUE_SHAPE = 0.50   # ...counts only together with a broadly similar shape (overlap x proportions)
SIMILAR_BOTH = (0.80, 0.75)   # or fairly close colours AND a near-identical outline


class ArtError(Exception):
    pass


def load_designs() -> dict[str, str]:
    """CHARACTER_DESIGNS.md blocks: '### <category>/<id>' followed by '- key: value' lines."""
    try:
        text = DESIGNS_PATH.read_text(encoding="utf-8")
    except OSError:
        return {}
    out = {}
    for m in re.finditer(r"^###\s+([a-z_]+/[a-z0-9_]+)\s*$(.*?)(?=^###\s|\Z)", text, re.M | re.S):
        out[m.group(1)] = m.group(2).strip()
    return out


def remove_design(key: str) -> str | None:
    """Drop one entry from CHARACTER_DESIGNS.md (before a redesign) and return its old text."""
    try:
        text = DESIGNS_PATH.read_text(encoding="utf-8")
    except OSError:
        return None
    m = re.search(rf"^###\s+{re.escape(key)}\s*$.*?(?=^###\s|\Z)", text, re.M | re.S)
    if not m:
        return None
    DESIGNS_PATH.write_text((text[:m.start()] + text[m.end():]).rstrip() + "\n", encoding="utf-8")
    return m.group(0).strip()


def design_text(entry: str) -> str:
    fields = dict(re.findall(r"^-\s*([a-z_]+)\s*:\s*(.+)$", entry, re.M))
    parts = [f"{k}: {fields[k]}" for k in ("name", "silhouette", "palette", "features", "pose") if k in fields]
    return "; ".join(parts) or entry


def build_prompt(category: str, description: str, design: str | None = None, avoid: str | None = None) -> str:
    side, transparent, framing = CATEGORIES[category]
    bg = ("a fully TRANSPARENT background (PNG with alpha), no ground, no cast shadow"
          if transparent else "no transparency, fill the entire canvas")
    subject = f"Design (follow it exactly, especially silhouette and palette): {design}" if design \
        else f"Subject: {description}"
    extra = f"\nIMPORTANT: {avoid}" if avoid else ""
    accent = accent_for(category, description)
    return (f"{accent['style'] if accent else STYLE}\n\nCreate exactly ONE image in that style: {framing}. {subject}. "
            f"Centred, nothing cropped, no text, no watermark, no border, {bg}.{extra}\n"
            "Reply with the image only.")


def _signature(png: Path):
    """(hue histogram, 48x48 silhouette mask, width/height aspect) of a processed asset."""
    from PIL import Image
    im = Image.open(png).convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox() or (0, 0, im.width, im.height)
    aspect = (box[2] - box[0]) / max(1, box[3] - box[1])
    im.thumbnail((128, 128))
    hsv = im.convert("RGB").convert("HSV")
    hist = [0.0] * 24
    for (h, s, v), a in zip(zip(*[iter(hsv.tobytes())] * 3), im.getchannel("A").tobytes()):
        if a > 128 and v > 30:
            hist[h * 24 // 256] += (0.25 + s / 255.0)
    mask = im.getchannel("A").resize((48, 48)).point(lambda v: 255 if v > 128 else 0)
    return hist, set(i for i, v in enumerate(mask.tobytes()) if v), aspect


def similarity(a: Path, b: Path) -> tuple[float, float]:
    """(colour, shape) similarity in 0..1. Shape blends silhouette overlap with how alike the proportions are,
    so a wide low crawler and a tall bruiser in the same dark palette are not look-alikes."""
    ha, ma, aa = _signature(a)
    hb, mb, ab = _signature(b)
    dot = sum(x * y for x, y in zip(ha, hb))
    na, nb = sum(x * x for x in ha) ** 0.5, sum(y * y for y in hb) ** 0.5
    hue = dot / (na * nb) if na and nb else 0.0
    iou = len(ma & mb) / len(ma | mb) if (ma or mb) else 0.0
    prop = min(aa, ab) / max(aa, ab) if max(aa, ab) > 0 else 1.0
    return hue, iou * prop


def closest_sibling(png: Path, category: str, asset_id: str) -> tuple[str, float, float] | None:
    """Most similar other asset in the same category, if it is too similar (see the thresholds above)."""
    worst = None
    for other in sorted(png.parent.glob("*.png")):
        if other.stem == asset_id:
            continue
        hue, iou = similarity(png, other)
        too_close = ((hue >= SIMILAR_HUE and iou >= SIMILAR_HUE_SHAPE)
                     or (hue >= SIMILAR_BOTH[0] and iou >= SIMILAR_BOTH[1]))
        if too_close and (worst is None or hue + iou > worst[1] + worst[2]):
            worst = (other.stem, hue, iou)
    return worst


# Planners sometimes open the block with @@ASSETS@@ or name a repo path ("assets/paper/vfx/x.png — desc", cycle 217
# lost three images that way); both forms are accepted.
ASSET_BLOCK_RE = r"@@ASSETS(?:_START)?@@(.*?)@@ASSETS_END@@"


def parse_assets(text: str) -> list[dict]:
    m = re.search(ASSET_BLOCK_RE, text or "", re.S)
    out = []
    for line in (m.group(1).splitlines() if m else []):
        mm = re.match(r"\s*[-*]?\s*`?(?:assets/paper/)?([a-z_]+)/([a-z0-9_]+)(?:\.png)?(!?)`?\s*(?::|\u2014|\u2013|-)\s*(.+)$",
                      line.strip())
        if mm and mm.group(1) in CATEGORIES:
            out.append({"category": mm.group(1), "id": mm.group(2), "description": mm.group(4).strip(),
                        "regenerate": mm.group(3) == "!"})
    return out


def asset_path(repo: Path, category: str, asset_id: str) -> Path:
    return repo / "assets" / "paper" / category / f"{asset_id}.png"


_REMBG = {}
_REMBG_LOCK = threading.Lock()


def _border_opaque(im) -> float:
    """Share of opaque pixels in the outer 3% ring (a cut-out subject leaves its border mostly transparent)."""
    a = im.getchannel("A")
    w, h = im.size
    m = max(2, min(w, h) * 3 // 100)
    ring = [a.getpixel((x, y)) for x in range(0, w, 3) for y in list(range(m)) + list(range(h - m, h))]
    ring += [a.getpixel((x, y)) for y in range(0, h, 3) for x in list(range(m)) + list(range(w - m, w))]
    return sum(1 for v in ring if v > 16) / max(1, len(ring))


def _clean_residue(im):
    """Compare the colour-key alpha with an AI matting mask; if a noticeable share of what the key kept is backdrop
    (streaks, texture, off-magenta), keep only what both agree on (matting mask widened so edges stay intact)."""
    from PIL import ImageChops, ImageFilter
    try:
        mat = _rembg(im).getchannel("A")
    except Exception:   # noqa: BLE001 - matting is best effort
        return im
    key = im.getchannel("A")
    kept = [k > 16 for k in key.getdata()]
    bad = sum(1 for k, m in zip(kept, mat.getdata()) if k and m < 64)
    if not any(kept) or bad / max(1, sum(kept)) < 0.08:
        return im
    wide = mat.filter(ImageFilter.MaxFilter(5))
    out = im.copy()
    out.putalpha(ImageChops.darker(key, wide))
    return out


def _rembg(im):
    """Background removal with rembg (isnet-general-use), for backdrops the magenta key cannot handle."""
    from PIL import Image
    from rembg import new_session, remove
    with _REMBG_LOCK:
        if "s" not in _REMBG:
            _REMBG["s"] = new_session("isnet-general-use")
        flat = Image.new("RGBA", im.size, (255, 255, 255, 255))
        flat.alpha_composite(im)
        return remove(flat.convert("RGB"), session=_REMBG["s"]).convert("RGBA")


def process(raw: bytes, out_png: Path, category: str) -> Path:
    from PIL import Image
    side, transparent, _ = CATEGORIES[category]
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    if transparent:
        if im.getchannel("A").getextrema()[0] == 255:      # generator ignored "transparent": key out the paper
            im = _key_background(im)
        im = _clean_residue(im)   # textured/odd backdrop that survived the colour key
        mask = im.getchannel("A").point(lambda v: 255 if v > 16 else 0)
        box = mask.getbbox()
        if not box:
            raise ArtError("image is fully transparent")
        im = im.crop(box)
    if not transparent:
        holes = sum(1 for v in im.getchannel("A").resize((64, 64)).getdata() if v < 250) / 4096
        if holes > 0.02:   # full-canvas art must be solid; magenta painted into it was keyed out as holes
            raise ArtError(f"full-canvas image has {holes:.0%} transparent holes")
        im = im.convert("RGB").convert("RGBA")
    if category == "cards" and im.width / im.height > 3 / 4 + 0.01:   # cards are portrait 3:4: crop the centre
        w = round(im.height * 3 / 4)
        left = (im.width - w) // 2
        im = im.crop((left, 0, left + w, im.height))
    if category in ("backgrounds", "briefings") and im.width / im.height < 16 / 9 - 0.01:   # screens are 16:9: crop the centre
        h = round(im.width * 9 / 16)
        top = (im.height - h) // 2
        im = im.crop((0, top, im.width, top + h))
    scale = side / max(im.size)
    if scale < 1:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    if transparent:
        pad = max(4, side // 64)
        canvas = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        canvas.paste(im, (pad, pad))
        im = canvas
    out_png.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_png, optimize=True)
    return out_png


def _key_background(im):
    """Flood-fill the uniform paper background from the corners and make it transparent."""
    from PIL import ImageDraw
    rgb = im.convert("RGB")
    marker = (255, 0, 255)
    for xy in ((0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)):
        if rgb.getpixel(xy) != marker:
            ImageDraw.floodfill(rgb, xy, marker, thresh=28)
    alpha = rgb.point(lambda v: 0).convert("L")
    px, apx = rgb.load(), alpha.load()
    for y in range(im.height):
        for x in range(im.width):
            apx[x, y] = 0 if px[x, y] == marker else 255
    out = im.copy()
    out.putalpha(alpha)
    return out


def _type_prompt(page, editor, text: str) -> None:
    """Type into the composer and make sure it arrived; an empty composer must never be 'sent'."""
    from playwright.sync_api import Error as PWError
    for attempt in range(3):
        try:
            editor.click()
            if attempt == 0:
                page.keyboard.insert_text(text)
            else:
                editor.fill(text)
            time.sleep(1)
            if len(editor.inner_text(timeout=3_000).strip()) >= min(40, len(text) // 2):
                return
        except PWError:
            pass
        time.sleep(2)
    raise ArtError("could not type the prompt into the composer")


def _send_and_confirm(page, button, editor, backend: str) -> None:
    """Click Send and make sure the prompt actually left the input box (a covered or ignored click must not
    turn into a 15-minute wait)."""
    from playwright.sync_api import Error as PWError
    try:
        if len(editor.inner_text(timeout=3_000).strip()) < 20:
            raise ArtError(f"{backend}: composer is empty before sending")
    except PWError:
        pass
    for _ in range(3):
        try:
            button.click(timeout=10_000)
        except PWError:
            if _security_check(page, backend):
                raise SecurityCheck("security check covers the Send button")
        for _ in range(15):
            time.sleep(1)
            try:
                if len(editor.inner_text(timeout=2_000).strip()) < 20:
                    return
            except PWError:
                return   # the input was replaced by the conversation view: sent
    if _security_check(page, backend):
        raise SecurityCheck("security check after Send")
    raise ArtError(f"{backend} did not accept the message")


def _notify(title: str, text: str) -> None:
    try:
        import subprocess
        ps = ("Add-Type -AssemblyName System.Windows.Forms; $n = New-Object System.Windows.Forms.NotifyIcon; "
              "$n.Icon = [System.Drawing.SystemIcons]::Warning; $n.Visible = $true; "
              f"$n.ShowBalloonTip(15000, '{title}', '{text}', 'Warning'); Start-Sleep 16; $n.Dispose()")
        subprocess.Popen(["powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps])
    except OSError:
        pass


def meta_prompt(prompt: str) -> str:
    """Meta AI loses the subject in long prompts (tested 2026-10-06): send a compact version with the technique,
    the subject/design and the magenta backdrop only."""
    full = "fill the entire canvas" in prompt   # terrain, backgrounds, cards: no cut-out subject
    m = re.search(r"(?:Design \(follow it exactly, especially silhouette and palette\): |Subject: )(.*?)\. Centred", prompt, re.S)
    subject = (m.group(1) if m else prompt)[:700]
    framing = re.search(r"in that style: (.*?)\. (?:Design|Subject)", prompt, re.S)
    extra = re.search(r"IMPORTANT: (.*?)\n", prompt)
    accent = accent_of(prompt)
    return ("Create an image. " + ((accent.get("short") or accent["style"][:400]) if accent else STYLE_SHORT)
            + ", but NOT the reference's subjects, layout or text. "
            + (framing.group(1) + ". " if framing else "")
            + (f"Subject: {subject}. One subject, centred, nothing cropped, no text. " if not full
               else f"Subject: {subject}. ")
            + (extra.group(1) + " " if extra else "")
            + ("Fill the entire canvas edge to edge with the scene or texture: no border, no frame, no backdrop "
               "colour, no text, no writing, no captions, no signature." if full
               else "Plain solid flat pure magenta background in one even colour, no ground or shadow, no magenta on "
                    "the subject, no lettering anywhere."))   # no hex code: Firefly Image 5 printed "#FF00FF" as text


def _img_bytes(page, el) -> bytes:
    """Bytes of a shown <img>: canvas copy first; a cross-origin image taints the canvas (SecurityError), so then
    download its URL with the page's cookies, and as a last resort screenshot the element."""
    try:
        return base64.b64decode(el.evaluate(CANVAS_IMAGE_JS))
    except Exception as e:   # noqa: BLE001
        if "SecurityError" not in str(e) and "toDataURL" not in str(e):
            raise
    src = el.evaluate("e => e.currentSrc || e.src")
    if src.startswith("http"):
        r = page.request.get(src)
        if r.ok:
            return r.body()
    return el.screenshot()


REST_PATH = HERE / "art_rest.json"   # services resting until their own usage limit resets ({backend: epoch})


def _resting(backend: str) -> bool:
    return _load(REST_PATH).get(backend, 0) > time.time()


def _rest_if_limited(backend: str, page) -> None:
    """If the page says the account's limit resets at a time (e.g. Gemini: "Your limit resets at 4:37 AM"), rest
    the service until then instead of timing out on every attempt."""
    import datetime
    try:
        text = page.locator("body").inner_text(timeout=5_000)
    except Exception:   # noqa: BLE001
        return
    m = re.search(r"limit resets (?:at|after) (\d{1,2}):(\d{2})\s*([AP]M)?", text, re.I)
    if not m:
        return
    h, mi = int(m.group(1)), int(m.group(2))
    if m.group(3):
        h = h % 12 + (12 if m.group(3).upper() == "PM" else 0)
    now = datetime.datetime.now()
    until = now.replace(hour=h, minute=mi, second=0, microsecond=0) + datetime.timedelta(minutes=3)
    if until <= now:
        until += datetime.timedelta(days=1)
    with PACE_LOCK:
        data = _load(REST_PATH)
        data[backend] = until.timestamp()
        REST_PATH.write_text(json.dumps(data), encoding="utf-8")


class _AllSitesBusy(Exception):
    pass


SITE_LOCK_DIR = HERE / "firefly_slots"


def _site_lock(backend: str):
    """One generation at a time per site, across every art process (stale after 15 min)."""
    if backend == "firefly":   # Firefly has its own lane slots
        return SITE_LOCK_DIR / "_unused_firefly_site"
    SITE_LOCK_DIR.mkdir(exist_ok=True)
    p = SITE_LOCK_DIR / f"site_{backend}"
    try:
        if p.exists() and time.time() - p.stat().st_mtime > 900:
            p.unlink(missing_ok=True)
        os.close(os.open(p, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
        return p
    except FileExistsError:
        return None


class FireflyBusy(Exception):
    pass


class FireflySignedOut(Exception):
    pass


_SIGNIN_NOTIFIED = [0.0]


FIREFLY_BUSY_RE = re.compile(r"Something went wrong|Please try again later", re.I)
# Firefly lanes (both free in the trial). Gemini 3.1 follows designs best but Adobe rate-limits it ("Something went
# wrong"); Adobe's own Firefly Image 5 is reliable but looser, so it gets the non-character categories.
FIREFLY_GEMINI = "Gemini 3.1 (Nano Banana 2)"
FIREFLY_ADOBE = "Firefly Image 5"
FIREFLY_PARTNER_OK = False   # Adobe has refused every partner model on both accounts since 2026-10-07 10:50
FIREFLY_LANES = {FIREFLY_GEMINI: 1, FIREFLY_ADOBE: 3}   # simultaneous generations per model, across all processes
ADOBE_CATEGORIES = {"ui", "icons", "vfx", "props", "terrain", "backgrounds", "projectiles", "briefings"}
FIREFLY_SLOTS = 4
FIREFLY_SLOT_DIR = HERE / "firefly_slots"
FIREFLY_COOLDOWN = HERE / "firefly_cooldown.txt"


def _firefly_acquire(should_stop, model: str = "") -> Path:
    FIREFLY_SLOT_DIR.mkdir(exist_ok=True)
    lane = "adobe" if model == FIREFLY_ADOBE else "gemini"
    while True:
        if should_stop():
            raise ArtError("stop requested")
        for i in range(FIREFLY_LANES.get(model, FIREFLY_SLOTS)):
            p = FIREFLY_SLOT_DIR / f"{lane}{i}"
            try:
                if p.exists() and time.time() - p.stat().st_mtime > 600:   # a crashed holder
                    p.unlink(missing_ok=True)
                fd = os.open(p, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(fd, str(os.getpid()).encode())
                os.close(fd)
                return p
            except FileExistsError:
                continue
            except OSError:
                continue
        time.sleep(2)


def _firefly_pick_model(page, model: str) -> None:
    """Choose the generation model in Firefly's "Model" picker (no-op when it is already selected)."""
    pick = page.locator("button, [role=button], [role=combobox]").filter(has_text=re.compile(
        r"Gemini|Firefly Image|GPT Image|Imagen|Flux", re.I)).filter(has_text=re.compile(r"\bModel\b"))
    btn = None
    for _ in range(20):   # the settings panel renders a few seconds after the prompt box
        btn = next((pick.nth(i) for i in range(pick.count()) if pick.nth(i).is_visible()), None)
        if btn is not None:
            break
        time.sleep(1)
    if btn is None:
        raise ArtError("firefly: model picker not found")
    if model in btn.inner_text():
        return
    btn.click()
    time.sleep(1.5)
    opt = page.get_by_text(model, exact=True)
    target = next((opt.nth(i) for i in range(opt.count()) if opt.nth(i).is_visible()), None)
    if target is None:
        page.keyboard.press("Escape")
        raise ArtError(f"firefly: model {model!r} not in the picker")
    target.click()
    time.sleep(1.5)


def _cooldown_path(model: str) -> Path:
    return FIREFLY_COOLDOWN.with_name(f"firefly_cooldown_{'adobe' if model == FIREFLY_ADOBE else 'gemini'}.txt")


def _firefly_cooldown(seconds: float, model: str = "") -> None:
    path = _cooldown_path(model)
    try:
        until = max(float(path.read_text()), time.time() + seconds)
    except (OSError, ValueError):
        until = time.time() + seconds
    path.write_text(str(until))


def _firefly_wait_cooldown(should_stop, model: str = "") -> None:
    while True:
        try:
            left = float(_cooldown_path(model).read_text()) - time.time()
        except (OSError, ValueError):
            return
        if left <= 0:
            return
        if should_stop():
            raise ArtError("stop requested")
        time.sleep(min(5, left))


def _accept_firefly_rights(page) -> None:
    """The owner accepted Firefly's upload-rights confirmation (2026-10-06); confirm it if it is shown."""
    m = page.locator('[data-testid="upload-permission-modal"]')
    try:
        if m.count() and m.first.is_visible():
            m.first.locator("sp-button, button").filter(
                has_text=re.compile(r"accept|agree|continue|confirm|upload|ok", re.I)).first.click()
            time.sleep(2)
    except Exception:
        pass


def firefly_short_prompt(prompt: str, limit: int = 1000) -> str:
    """Adobe's own Firefly models accept at most 1024 prompt characters: keep style, framing, silhouette, palette and
    features, drop pose/comparison notes, and always keep the background instruction at the end."""
    p = bing_prompt(prompt).replace("Create an image. ", "")
    i = max(p.find(" One subject, centred"), p.find(" Fill the entire canvas"))
    head, tail = (p[:i], p[i:]) if i >= 0 else (p, "")
    head = re.sub(r";?\s*(pose|differs_from|name):[^;]*", "", head)
    room = limit - len(tail)
    if len(head) > room:
        head = head[:room - 1].rsplit(" ", 1)[0].rstrip(" ;,") + "."
    return head + tail


def bing_prompt(prompt: str) -> str:
    """Text-only version of the compact prompt: Bing cannot see the reference images, so describe the style."""
    return meta_prompt(prompt).replace(
        "Flat torn-paper collage exactly like the attached references (jagged hand-torn edges, paper grain, layered "
        "pieces, chibi proportions), but NOT their colours or characters.",
        "Flat torn-paper collage game art: jagged hand-torn paper pieces with pale torn fibre edges, visible paper "
        "grain, flat overlapping layers, no outlines, no 3D shading, chibi proportions for characters.")


def _magenta_distance(raw: bytes) -> float:
    """How far an image's corners are from pure #FF00FF (lower = cleaner backdrop to key out)."""
    from PIL import Image
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    pts = [(2, 2), (im.width - 3, 2), (2, im.height - 3), (im.width - 3, im.height - 3)]
    return sum(((255 - r) ** 2 + g ** 2 + (255 - b) ** 2) ** 0.5 for r, g, b in (im.getpixel(p) for p in pts)) / 4


_KEYCTX = threading.local()   # make() marks full-canvas categories: their art must not be keyed at all


def key_magenta(raw: bytes) -> bytes:
    """Turn a solid magenta backdrop into transparency (soft edge, magenta spill removed)."""
    from PIL import Image
    im = Image.open(io.BytesIO(raw)).convert("RGBA")
    if getattr(_KEYCTX, "full_canvas", False):   # terrain/backgrounds/cards: magenta in them is just colour
        out = io.BytesIO()
        im.save(out, "PNG")
        return out.getvalue()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            d = ((255 - r) ** 2 + g ** 2 + (255 - b) ** 2) ** 0.5     # distance from #FF00FF
            if d < 80:
                px[x, y] = (0, 0, 0, 0)
            elif d < 160 and r > g + 40 and b > g + 40:              # magenta-tinted edge: fade and despill
                k = (d - 80) / 80
                px[x, y] = (min(r, g + 40), g, min(b, g + 40), int(a * k))
    corners = [(0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)]
    if any(im.getpixel(c)[3] for c in corners):
        # The backdrop was not magenta (e.g. dark purple): key out the flat colour connected to the corners.
        im = _key_background(im)
    out = io.BytesIO()
    im.save(out, "PNG")
    return out.getvalue()


class ArtGenerator:
    def __init__(self, chatgpt_cfg: dict, log: Callable[[str], None] = print,
                 should_stop: Callable[[], bool] = lambda: False, backends: list[str] | None = None):
        self.cfg = chatgpt_cfg
        self.log = log
        self.should_stop = should_stop
        if not backends:   # relay.json "art.backends" picks the side-art sources (owner 2026-10-07: Gemini + Sogni)
            try:
                backends = json.loads((HERE / "relay.json").read_text(encoding="utf-8")).get("art", {}).get("backends")
            except (OSError, ValueError):
                backends = None
        if not backends and time.strftime("%Y-%m-%d") <= BACKEND_UNTIL["firefly"]:
            # Firefly first while the trial lasts; when its Gemini lane is rate-limited, characters go on to the
            # other sites (Gemini directly has its own quota) instead of waiting.
            backends = ["firefly", "gemini", "copilot", "bing", "perchance"]   # meta: its chat stopped starting
        self.backends = list(backends or DEFAULT_BACKENDS)

    def refs(self) -> list[Path]:
        refs = sorted(REFS_DIR.glob("ref_*.png"))
        if not refs:
            raise ArtError(f"no style references in {REFS_DIR}")
        return refs

    def generate(self, prompt: str, timeout_s: int = 900) -> bytes:
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        sel = self.cfg["selectors"]
        page = bridge.new_tab()
        try:
            page.goto(self.cfg["new_chat_url"], wait_until="domcontentloaded", timeout=60_000)
            page.locator(sel["composer"]).first.wait_for(state="visible", timeout=60_000)
            bridge._select_mode(page, "chat")
            page.locator('input[type="file"]').first.set_input_files([str(r) for r in self.refs()])
            composer = page.locator(sel["composer"]).first
            composer.click()
            composer.fill(prompt)
            send = page.locator(sel["send"]).first
            deadline = time.time() + 120            # attachments upload before Send enables
            while not (send.count() and send.is_enabled()):
                if time.time() > deadline:
                    raise ArtError("reference upload did not finish")
                time.sleep(1)
            before = set(page.locator('img[alt^="Generated image"]').evaluate_all(
                "els => els.map(e => e.currentSrc || e.src)"))
            replies_before = page.locator(sel["assistant"]).count()
            send.click()
            return self._wait_for_image(page, sel, timeout_s, before, replies_before)
        except (PWError, BridgeError) as e:
            raise ArtError(f"browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def _wait_for_image(self, page, sel, timeout_s, before: set, replies_before: int) -> bytes:
        """Only an image inside the NEW assistant reply counts; the page can already show earlier generations
        (library thumbnails, previous results), which must never be returned."""
        from chatgpt_bridge import ERROR_RE
        deadline, stable, last = time.time() + timeout_s, 0, None
        reply = page.locator(sel["assistant"]).nth(replies_before)
        gen = reply.locator('img[alt^="Generated image"]')
        while time.time() < deadline:
            if self.should_stop():
                raise ArtError("stop requested")
            time.sleep(5)
            if page.get_by_text(ERROR_RE).count():
                raise ArtError("ChatGPT error banner")
            streaming = page.locator(sel["stop"]).count() > 0
            n = gen.count() if reply.count() else 0
            src = gen.last.evaluate("e => e.currentSrc || e.src") if n else None
            if src in before:
                n, src = 0, None
            sig = (n, src)
            stable = stable + 1 if (n and not streaming and sig == last) else 0
            last = sig
            if stable >= 3:
                data = gen.last.evaluate("""async (e) => {
                    const r = await fetch(e.currentSrc || e.src); const b = await r.blob();
                    const buf = new Uint8Array(await b.arrayBuffer()); let s = "";
                    for (let i = 0; i < buf.length; i += 0x8000)
                        s += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
                    return {type: b.type, b64: btoa(s)}; }""")
                return base64.b64decode(data["b64"])
            if not n and not streaming and time.time() > deadline - timeout_s + 180:
                text = reply.inner_text(timeout=5_000) if reply.count() else ""
                if text.strip():
                    raise ArtError(f"no image, ChatGPT replied: {text.strip()[:200]}")
        raise ArtError("image generation timed out")

    def generate_any(self, prompt: str) -> bytes:
        """Try each configured image backend in order. One image at a time per site (owner: "only 1 of each"): a
        site busy with another worker is skipped; if every site is busy, wait for one."""
        while True:
            try:
                return self._generate_any_once(prompt)
            except _AllSitesBusy:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(10)

    def _generate_any_once(self, prompt: str) -> bytes:
        errors, busy = [], 0
        # Firefly first (trial); the rest by whichever service is free soonest, so parallel workers spread out.
        first = [b for b in self.backends if b == "firefly"]
        # Perchance is the last resort (weaker style, soft rate limits); the others go by who is free soonest.
        rest = sorted((b for b in self.backends if b != "firefly"), key=lambda b: (b == "perchance", _wait_for(b)))
        for backend in first + rest:
            if _resting(backend):
                errors.append(f"{backend}: resting until its usage limit resets")
                continue
            if backend in blocked_backends():
                errors.append(f"{backend}: waiting for the owner to clear a security check")
                continue
            if BACKEND_UNTIL.get(backend, "9999") < time.strftime("%Y-%m-%d"):
                continue   # e.g. a trial that has ended
            if backend == "perchance" and getattr(self, "category", None) in ("terrain", "backgrounds", "cards", "briefings"):
                continue   # its 450 px captures are too small for full-canvas art
            site = _site_lock(backend)
            if site is None:
                busy += 1
                continue
            try:
                _pace(backend, self.log)
                try:
                    if backend == "copilot":
                        return self.generate_copilot(prompt, 300)
                    if backend == "gemini":
                        return self.generate_gemini(prompt, 300)
                    if backend == "meta":
                        return self.generate_meta(prompt)
                    if backend == "bing":
                        return self.generate_bing(prompt, 300)
                    if backend == "firefly":
                        return self.generate_firefly(prompt)
                    if backend == "perchance":
                        return self.generate_perchance(prompt)
                    if backend == "sogni":
                        return self.generate_sogni(prompt)
                    if backend == "flow":
                        return self.generate_flow(prompt)
                    if backend == "chatgpt":
                        return self.generate_chatgpt(prompt)
                    return self.generate(prompt)
                finally:
                    _paced(backend)
            except SecurityCheck as e:
                data = blocked_backends()
                data[backend] = {"since": time.strftime("%Y-%m-%d %H:%M:%S"), "detail": str(e)}
                BLOCK_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")
                self.log(f"art: {backend} is showing a security check; paused until the owner clears it "
                         f"(then run: python art_gen.py --unblock {backend})")
                _notify(f"{G.NAME} art: {backend} needs you",
                        f"{backend} shows a security check in the relay Chrome. Please complete it.")
                errors.append(f"{backend}: security check")
            except ArtError as e:
                if self.should_stop():
                    raise
                errors.append(f"{backend}: {e}")
                self.log(f"art: {backend} failed ({e}); trying next backend")
            finally:
                site.unlink(missing_ok=True)
        if busy and not errors:
            raise _AllSitesBusy()
        raise ArtError("; ".join(errors) or "no image backend configured")

    def generate_gemini(self, prompt: str, timeout_s: int = 900) -> bytes:
        """Google Gemini (gemini.google.com, signed in inside the relay Chrome). Gemini images have no alpha,
        so a solid magenta backdrop is requested and keyed out here."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(GEMINI_URL, wait_until="domcontentloaded", timeout=60_000)
            editor = page.locator(GEMINI_EDITOR).first
            editor.wait_for(state="visible", timeout=60_000)
            if _security_check(page, "gemini"):
                raise SecurityCheck("security check shown on load")
            gen = page.locator(GEMINI_IMAGE)
            before = gen.count()
            refs = self.refs()[:GEMINI_MAX_REFS]
            page.locator('button[aria-label="Upload & tools"]').first.click()
            with page.expect_file_chooser(timeout=20_000) as chooser:
                page.locator('button:has-text("Files"), [role=menuitem]:has-text("Files")').first.click()
            chooser.value.set_files([str(r) for r in refs])
            deadline = time.time() + 120
            while page.locator('img[alt="attachment"]').count() < len(refs):
                if time.time() > deadline:
                    raise ArtError("gemini reference upload did not finish")
                time.sleep(1)
            time.sleep(2)
            editor.click()
            _type_prompt(page, editor, "Generate an image. " + prompt.replace(
                "a fully TRANSPARENT background (PNG with alpha), no ground, no cast shadow",
                "a perfectly flat, solid pure magenta (#FF00FF) background with nothing else on it, no ground, "
                "no cast shadow, and no magenta anywhere on the subject"))
            time.sleep(1)
            _send_and_confirm(page, page.locator('button[aria-label="Send message"]').first, editor, "gemini")
            deadline, stable, last = time.time() + timeout_s, 0, None
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(5)
                if _security_check(page, "gemini"):
                    raise SecurityCheck("security check shown while generating")
                n = gen.count()   # only Gemini's own output counts, never the uploaded reference previews
                w = gen.nth(n - 1).evaluate("e => e.complete ? e.naturalWidth : 0") if n > before else 0
                busy = page.locator('button[aria-label*="Stop" i]').count() > 0
                sig = (n, w) if (n > before and w >= 512) else None
                stable = stable + 1 if (sig and sig == last and not busy) else 0
                last = sig
                if stable >= 3:
                    raw = _img_bytes(page, gen.nth(n - 1))
                    return key_magenta(raw)
            _rest_if_limited("gemini", page)
            raise ArtError("gemini image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"gemini browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def generate_meta(self, prompt: str, timeout_s: int = 900) -> bytes:
        """Meta AI (www.meta.ai, signed in inside the relay Chrome). No alpha: a magenta backdrop is keyed out."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(META_URL, wait_until="domcontentloaded", timeout=60_000)
            editor = page.locator(META_EDITOR).first
            editor.wait_for(state="visible", timeout=60_000)
            if _security_check(page, "meta"):
                raise SecurityCheck("security check shown on load")
            gen = page.locator(META_IMAGE)
            before = gen.count()
            refs = self.refs()[:META_MAX_REFS]
            chips_before = page.locator(META_CHIP).count()
            page.locator('input[type="file"]').first.set_input_files([str(r) for r in refs])
            deadline = time.time() + 120
            while page.locator(META_CHIP).count() < chips_before + len(refs):
                if time.time() > deadline:
                    raise ArtError("meta reference upload did not finish")
                time.sleep(1)
            time.sleep(12)   # the chip shows before the upload finishes; sending earlier drops the message (2026-10-07)
            editor.click()
            _type_prompt(page, editor, meta_prompt(prompt))
            time.sleep(1)
            _send_and_confirm(page, page.locator('[aria-label="Send"]').first, editor, "meta")
            started = time.time()
            while "/prompt/" not in page.url:
                if time.time() - started > 60:
                    raise ArtError("meta: the conversation did not start after sending")
                time.sleep(2)
            deadline, stable, last = time.time() + timeout_s, 0, None
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(5)
                if _security_check(page, "meta"):
                    raise SecurityCheck("security check shown while generating")
                n = gen.count()   # only Meta's generated tiles count, never the uploaded reference chips
                w = gen.nth(n - 1).evaluate("e => e.complete ? e.naturalWidth : 0") if n > before else 0
                sig = (n, w, gen.nth(n - 1).evaluate("e => (e.currentSrc || e.src).slice(0, 200)") if w else None)
                stable = stable + 1 if (n > before and w >= 512 and sig == last) else 0
                last = sig
                if stable >= 3:
                    src = gen.nth(n - 1).evaluate("e => e.currentSrc || e.src")
                    if src.startswith("http"):
                        raw = page.request.get(src).body()
                    else:
                        raw = _img_bytes(page, gen.nth(n - 1))
                    return key_magenta(raw)
            raise ArtError("meta image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"meta browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def generate_bing(self, prompt: str, timeout_s: int = 600) -> bytes:
        """Bing Image Creator (MAI-Image, signed in inside the relay Chrome). Text-only: an uploaded image switches
        Bing to edit mode, so the paper style is described in words. Four variants come back; the first is used."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(BING_URL, wait_until="domcontentloaded", timeout=60_000)
            box = page.locator("textarea:visible").first
            box.wait_for(state="visible", timeout=60_000)
            if _security_check(page, "bing"):
                raise SecurityCheck("security check shown on load")
            before = set(page.locator("img").evaluate_all("els => els.map(e => e.currentSrc || e.src)"))
            text = bing_prompt(prompt)
            for _fill in range(3):   # the page can reset the box while it finishes loading: re-check, refill
                box.click()
                box.fill(text)
                time.sleep(1.5 + 2 * _fill)
                if len(box.input_value()) >= min(40, len(text) // 2):
                    break
            else:
                raise ArtError("bing: prompt did not arrive in the text box")
            page.get_by_role("button", name="Generate").first.click()
            deadline = time.time() + timeout_s
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(5)
                if _security_check(page, "bing"):
                    raise SecurityCheck("security check shown while generating")
                body = page.locator("body").inner_text(timeout=5_000)
                if BING_BLOCK_RE.search(body):
                    raise ArtError("bing refused the prompt (content policy)")
                fresh = page.locator("img").evaluate_all(
                    """(els, before) => els.filter(e => e.complete && e.naturalWidth >= 512
                        && /th\\.bing\\.com\\/th\\/id\\/OIG/.test(e.currentSrc || e.src)
                        && !before.includes(e.currentSrc || e.src)).map(e => e.currentSrc || e.src)""",
                    list(before))
                if fresh:
                    time.sleep(4)   # let all four variants arrive
                    fresh = page.locator("img").evaluate_all(
                        """(els, before) => els.filter(e => e.complete && e.naturalWidth >= 512
                            && /th\\.bing\\.com\\/th\\/id\\/OIG/.test(e.currentSrc || e.src)
                            && !before.includes(e.currentSrc || e.src)).map(e => e.currentSrc || e.src)""",
                        list(before))
                    urls = list(dict.fromkeys(u.split("?")[0] + "?pid=ImgGn" for u in fresh))[:4]
                    shots = [page.request.get(u).body() for u in urls]
                    return key_magenta(min(shots, key=_magenta_distance))
            raise ArtError("bing image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"bing browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def generate_firefly(self, prompt: str, timeout_s: int = 240) -> bytes:
        """Firefly with a machine-wide cap on simultaneous generations (FIREFLY_SLOTS, shared by every art process)
        and a shared back-off: too many at once makes Firefly answer "Something went wrong. Please try again later"."""
        model = FIREFLY_ADOBE if getattr(self, "category", None) in ADOBE_CATEGORIES else FIREFLY_GEMINI
        if model == FIREFLY_GEMINI and not FIREFLY_PARTNER_OK:
            raise ArtError("firefly: partner models blocked by Adobe; characters go to the other sites")
        if model == FIREFLY_GEMINI:
            try:
                if float(_cooldown_path(model).read_text()) > time.time():
                    raise ArtError("firefly Gemini lane is cooling down; using the next site")
            except (OSError, ValueError):
                pass
        attempt = 0
        while attempt < (1 if model == FIREFLY_GEMINI else 4):   # Gemini lane: one try, then the next site
            _firefly_wait_cooldown(self.should_stop, model)
            if model == FIREFLY_GEMINI:   # one slot: never queue for it, use the next site instead
                slot = FIREFLY_SLOT_DIR / "gemini0"
                try:
                    FIREFLY_SLOT_DIR.mkdir(exist_ok=True)
                    if slot.exists() and time.time() - slot.stat().st_mtime > 600:
                        slot.unlink(missing_ok=True)
                    fd = os.open(slot, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                    os.write(fd, str(os.getpid()).encode())
                    os.close(fd)
                except FileExistsError:
                    raise ArtError("firefly Gemini lane is busy; using the next site")
            else:
                slot = _firefly_acquire(self.should_stop, model)
            try:
                return self._generate_firefly_once(prompt, timeout_s, model)
            except FireflySignedOut:
                # Not signed in to Adobe: wait (all art processes) until the owner signs in again, then retry.
                slot.unlink(missing_ok=True)
                if time.time() - _SIGNIN_NOTIFIED[0] > 1800:
                    _SIGNIN_NOTIFIED[0] = time.time()
                    self.log("art: Adobe Firefly is signed out; waiting for the owner to sign in again")
                    _notify(f"{G.NAME} art paused", "Sign in to Adobe Firefly in the relay Chrome window")
                _firefly_cooldown(60, model)
                continue
            except FireflyBusy:
                # Adobe rate-limits its Gemini lane for long stretches: rest it 30 min, the other sites carry on.
                wait = 7200 if model == FIREFLY_GEMINI else min(600, 60 * (attempt + 1))   # Gemini: refused all night
                _firefly_cooldown(wait, model)
                self.log(f"art: firefly {model} busy; backing off {wait}s (attempt {attempt + 1})")
                attempt += 1
            finally:
                slot.unlink(missing_ok=True)
        raise ArtError(f"firefly {model} stayed busy")

    def _generate_firefly_once(self, prompt: str, timeout_s: int = 240, model: str | None = None) -> bytes:
        """Adobe Firefly "Generate image" (Gemini 3.1 Nano Banana 2 inside Firefly; owner's unlimited trial until
        FIREFLY_UNTIL). One style reference is uploaded; the owner accepted Firefly's upload-rights dialog, so it is
        confirmed automatically when shown. No alpha: a magenta backdrop is keyed out."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(FIREFLY_URL, wait_until="domcontentloaded", timeout=90_000)
            box = page.locator("textarea").first
            box.wait_for(state="visible", timeout=90_000)
            time.sleep(8)
            if _security_check(page, "firefly"):
                raise SecurityCheck("security check shown on load")
            sign_in = page.get_by_role("button", name="Sign in")
            seen = 0
            for _ in range(3):   # the button flashes for a moment while the login loads: confirm it stays
                if any(sign_in.nth(i).is_visible() for i in range(sign_in.count())):
                    seen += 1
                time.sleep(4)
            if seen == 3:
                raise FireflySignedOut("firefly: signed out")
            if model:
                _firefly_pick_model(page, model)
            if not (model and model.startswith("Firefly Image")):   # Adobe's models copy the reference's content
                refs = self.refs()
                page.locator('input[type="file"]').first.set_input_files(str(refs[0]))
                time.sleep(6)
                _accept_firefly_rights(page)
            before = set(page.locator("img").evaluate_all("els => els.map(e => e.currentSrc || e.src)"))
            text = ("Use the reference image ONLY for the technique: flat torn-paper collage, jagged hand-torn pieces "
                    "with pale torn fibre edges, paper grain, layered pieces. Do not copy its colours or character. "
                    + bing_prompt(prompt).split(" chibi proportions for characters.", 1)[-1].strip())
            if model and model.startswith("Firefly Image"):
                text = firefly_short_prompt(prompt)   # Adobe's models: 1024-character prompt limit
            for _fill in range(3):   # the page can reset the box while it finishes loading: re-check, refill
                box.click()
                box.fill(text)
                time.sleep(1.5 + 2 * _fill)
                if len(box.input_value()) >= min(40, len(text) // 2):
                    break
            else:
                raise ArtError("firefly: prompt did not arrive in the text box")
            base_err = page.get_by_text(FIREFLY_BUSY_RE).count()   # errors already on the page are history
            page.get_by_role("button", name="Generate").first.click()
            deadline, last, stable = time.time() + timeout_s, None, 0
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(5)
                _accept_firefly_rights(page)
                if _security_check(page, "firefly"):
                    raise SecurityCheck("security check shown while generating")
                if page.get_by_text(FIREFLY_BUSY_RE).count() > base_err:
                    raise FireflyBusy("firefly: Something went wrong / try again later")
                # The result is the large, newly shown image in the canvas area (gallery thumbnails are small).
                found = page.locator("img").evaluate_all(
                    """(els, before) => els.filter(e => e.complete && e.naturalWidth >= 700 && e.clientWidth >= 300
                        && !before.includes(e.currentSrc || e.src)).map(e => e.currentSrc || e.src)""", list(before))
                sig = found[0] if found else None
                stable = stable + 1 if (sig and sig == last) else 0
                last = sig
                if stable >= 2:
                    if sig.startswith("http"):
                        raw = page.request.get(sig).body()
                    else:
                        el = page.locator(f'img[src="{sig}"]').first
                        raw = _img_bytes(page, el)
                    return key_magenta(raw)
            raise ArtError("firefly image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"firefly browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def generate_flow(self, prompt: str) -> bytes:
        """Google Flow (owner's Plus plan, Nano Banana 2.1, 0 credits) with one style reference; the owner accepted
        its upload-rights dialog (never clicked by code)."""
        import firefly_ref
        cat = getattr(self, "category", None)
        kind = "wide" if cat in ("backgrounds", "briefings") else ("card" if cat == "cards" else "square")
        return key_magenta(firefly_ref.flow_image(self, meta_prompt(prompt), style_sheet(cat, prompt), kind))

    def generate_chatgpt(self, prompt: str) -> bytes:
        """ChatGPT chat image (owner 2026-10-17: "do flow and chatgpt chat. images are billed seperately") with one
        style reference, through firefly_ref.chatgpt_image (the old self.generate lost the image after a markup change)."""
        import firefly_ref
        return key_magenta(firefly_ref.chatgpt_image(self, prompt, style_sheet(getattr(self, "category", None), prompt)))

    def generate_sogni(self, prompt: str) -> bytes:
        """Sogni Create with one style reference (owner: it needs the reference for the paper style) and a short
        prompt; GPT Image 2.5 Flare, the only Sogni model that draws a NEW subject in the reference's style."""
        import firefly_ref
        flat = firefly_ref._flat_ref(self.refs()[0])
        try:
            raw = firefly_ref.sogni_image(self, firefly_ref.sogni_style_prompt(prompt), flat, short=False,
                                          model=firefly_ref.SOGNI_STYLE_MODEL)
        finally:
            flat.unlink(missing_ok=True)
        return key_magenta(raw)

    def generate_perchance(self, prompt: str, timeout_s: int = 120) -> bytes:
        """Perchance's free AI image generator (no account). Text only; 4 variants render inside sandboxed iframes, so
        each is captured as a 450 px element screenshot and the one with the cleanest magenta backdrop is kept."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        from PIL import Image
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(PERCHANCE_URL, wait_until="domcontentloaded", timeout=90_000)
            gen = None
            for _ in range(40):
                time.sleep(2)
                gen = next((fr for fr in page.frames if fr != page.main_frame
                            and fr.get_by_text("✨ generate").count()), None)
                if gen:
                    break
            if gen is None:
                raise ArtError("perchance: generator did not load")
            text = re.sub(r"[{}|]", " ", firefly_short_prompt(prompt))   # {a|b} is Perchance's random syntax
            gen.locator("textarea:visible").first.fill(text)
            try:
                gen.locator("select").first.select_option(label="𝗡𝗼 𝘀𝘁𝘆𝗹𝗲")
            except PWError:
                pass
            gen.get_by_text("✨ generate").first.click()
            deadline = time.time() + timeout_s
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(8)
                frames = gen.locator("iframe")
                shots = []
                for i in range(frames.count()):
                    el = frames.nth(i)
                    box = el.bounding_box()
                    if not box or box["width"] < 300:
                        continue
                    raw = el.screenshot()
                    im = Image.open(io.BytesIO(raw)).convert("HSV").resize((64, 64))
                    colourful = sum(1 for _, sat, _ in im.getdata() if sat > 70) / 4096
                    if colourful > 0.4:   # a finished picture; the grey "Starting..." placeholder is not
                        shots.append(raw)
                if len(shots) >= 4 or (shots and time.time() > deadline - 60):
                    time.sleep(6)   # let the last images finish painting
                    best = min(shots, key=_magenta_distance)
                    return key_magenta(best)
            raise ArtError("perchance image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"perchance browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    def generate_copilot(self, prompt: str, timeout_s: int = 900) -> bytes:
        """Microsoft Copilot (copilot.microsoft.com, signed in inside the relay Chrome)."""
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        from playwright.sync_api import Error as PWError
        bridge = ChatGPTBridge(self.cfg, self.log)
        page = bridge.new_tab()
        try:
            page.goto(COPILOT_URL, wait_until="domcontentloaded", timeout=60_000)
            editor = page.locator(COPILOT_EDITOR).first
            editor.wait_for(state="visible", timeout=60_000)
            if _security_check(page, "copilot"):
                raise SecurityCheck("security check shown on load")
            gen = page.locator('img[alt^="Generated image"]')
            before = set(gen.evaluate_all("els => els.map(e => (e.currentSrc || e.src).slice(0, 200))"))
            refs = self.refs()[:COPILOT_MAX_REFS]
            page.locator(COPILOT_FILE).first.set_input_files([str(r) for r in refs])
            # Upload is ready when every file has its "Remove attachment" chip and the Send button is shown.
            chips = page.locator('button[aria-label^="Remove attachment"]')
            send = page.locator('button[aria-label="Send"]')
            deadline = time.time() + 120
            while not (chips.count() >= len(refs) and send.count()):
                if time.time() > deadline:
                    raise ArtError("copilot reference upload did not finish")
                time.sleep(1)
            time.sleep(2)
            editor.click()
            _type_prompt(page, editor, "Create an image. " + prompt)
            time.sleep(1)
            _send_and_confirm(page, send.first, editor, "copilot")
            deadline, stable, last = time.time() + timeout_s, 0, None
            while time.time() < deadline:
                if self.should_stop():
                    raise ArtError("stop requested")
                time.sleep(5)
                if _security_check(page, "copilot"):
                    raise SecurityCheck("security check shown while generating")
                fresh = [i for i in range(gen.count())
                         if (gen.nth(i).evaluate("e => (e.currentSrc || e.src).slice(0, 200)") not in before
                             and (gen.nth(i).evaluate("e => e.complete && e.naturalWidth") or 0) >= 512)]
                sig = (fresh[-1], gen.nth(fresh[-1]).evaluate("e => (e.currentSrc || e.src).length")) if fresh else None
                stable = stable + 1 if (sig and sig == last) else 0
                last = sig
                if stable >= 3:
                    data = gen.nth(fresh[-1]).evaluate(FETCH_IMAGE_JS)
                    return base64.b64decode(data["b64"])
            raise ArtError("copilot image generation timed out")
        except (PWError, BridgeError) as e:
            raise ArtError(f"copilot browser error: {e}") from e
        finally:
            try:
                page.close()
            except PWError:
                pass
            bridge.disconnect()

    design_mode, design_effort, batch = "chat", None, ""   # set by generate_assets from relay.json "art"

    def design(self, category: str, asset_id: str, description: str, previous: str | None = None) -> str:
        """Design entry for an asset. Missing entries are written by ChatGPT (chat mode) so that they contrast
        with every existing entry, then appended to CHARACTER_DESIGNS.md."""
        key = f"{category}/{asset_id}"
        designs = load_designs()
        if key in designs:
            return designs[key]
        from chatgpt_bridge import ChatGPTBridge, BridgeError
        existing = "\n\n".join(f"### {k}\n{v}" for k, v in designs.items()) or "(none yet)"
        prompt = (
            f"You are the lead character designer for {G.NAME}, {G.DESC}. Every subject must be "
            "instantly distinguishable from every other one, even as a 64-pixel silhouette.\n\n"
            f"Existing design entries:\n{existing[-15000:]}\n\n"
            + (f"Being designed at the same time (also contrast with these): {self.batch}\n\n" if self.batch else "")
            + f"Write the design entry for {key}. Brief from the game planner: {description}\n"
            + (f"This is a REDESIGN: the previous design looked too much like other roster members. Move clearly "
               f"away from it (new silhouette and a palette no other entry uses):\n{previous}\n" if previous else "")
            + "Give it a body plan/silhouette and a dominant 2-3 colour palette (hex codes) that no existing entry in "
            "the same category uses, and 2-3 signature features nothing else has. Chibi proportions for creatures.\n"
            "Reply with exactly:\n@@DESIGN_START@@\n### " + key + "\n- name: ...\n- silhouette: ...\n- palette: ...\n"
            "- features: ...\n- pose: ...\n- differs_from: ...\n@@DESIGN_END@@")
        bridge = ChatGPTBridge(self.cfg, self.log)
        try:
            reply = bridge.ask(prompt, 150, mode=self.design_mode, effort=self.design_effort)   # slow: skip it
        except BridgeError as e:
            raise ArtError(f"design for {key} failed: {e}") from e
        m = re.search(r"@@DESIGN_START@@(.*?)(?:@@DESIGN_END@@|$)", reply, re.S)
        # The reply is read from the rendered page, so markdown markers ("### ", "- ") are usually gone:
        # rebuild the canonical block from the "field: value" lines.
        fields = dict(re.findall(r"^\s*[-*]?\s*(name|silhouette|palette|features|pose|differs_from)\s*:\s*(.+?)\s*$",
                                 m.group(1) if m else "", re.M))
        if not {"silhouette", "palette"} <= fields.keys():
            raise ArtError(f"design for {key}: unusable reply: {reply.strip()[:160]!r}")
        block = f"### {key}\n" + "\n".join(
            f"- {k}: {fields[k]}" for k in ("name", "silhouette", "palette", "features", "pose", "differs_from")
            if k in fields)
        with DESIGN_LOCK, DESIGNS_PATH.open("a", encoding="utf-8") as f:
            f.write("\n\n" + block + "\n")
        self.log(f"art: designed {key}")
        return load_designs().get(key, block)

    def make(self, repo: Path, category: str, asset_id: str, description: str, tries: int = 3,
             regenerate: bool = False, redesign: bool = False) -> Path:
        if category not in CATEGORIES:
            raise ArtError(f"unknown category {category}")
        out = asset_path(repo, category, asset_id)
        raw_path = RAW_DIR / f"{category}__{asset_id}.png"
        if raw_path.exists() and not regenerate:   # e.g. from a parked cycle: reuse, do not spend image quota
            self.log(f"art: reusing raw {raw_path.name}")
            return process(raw_path.read_bytes(), out, category)
        design = None
        previous = remove_design(f"{category}/{asset_id}") if redesign else None
        owner = next((f"{c}/{asset_id}" for c in ("heroes", "enemies", "bosses", "towers", "troops")
                      if category == "portraits" and f"{c}/{asset_id}" in load_designs()), None)
        if owner:   # a portrait shows the SAME character: reuse its design, never invent a contrasting one
            design = re.sub(r"(;\s*)?pose: [^;]*", "", design_text(load_designs()[owner]))
            design += ("; framing: HEAD AND SHOULDERS ONLY, cropped at the chest, face large and centred, "
                       "no legs or full body")
        elif category not in ("terrain", "backgrounds", "ui", "vfx", "projectiles", "props", "icons", "briefings"):
            try:
                design = design_text(self.design(category, asset_id, description, previous))
            except ArtError as e:   # a design entry is best effort; the planner's description still works
                self.log(f"art: {e}; using the planner's description")
        self.category = category   # lets generate_firefly route the category to a Firefly model
        _KEYCTX.full_canvas = not CATEGORIES[category][1]
        avoid, err, best = None, None, None
        for attempt in range(1, tries + 1):
            try:
                self.log(f"art: generating {category}/{asset_id} (try {attempt})")
                raw = self.generate_any(build_prompt(category, description, design, avoid))
            except ArtError as e:
                err = e
                self.log(f"art: {category}/{asset_id} failed: {e}")
                continue
            RAW_DIR.mkdir(parents=True, exist_ok=True)
            import hashlib
            digest = hashlib.sha256(raw).hexdigest()
            dup = next((q.name for q in RAW_DIR.glob("*.png")
                        if q.stat().st_size == len(raw) and hashlib.sha256(q.read_bytes()).hexdigest() == digest), None)
            if dup:   # a download bug, not a real generation: never pay for another image because of it
                raise ArtError(f"downloaded image is byte-identical to {dup} (stale page image); "
                               "check the ChatGPT chat history before regenerating")
            cand = RAW_DIR / f"{category}__{asset_id}.try{attempt}.png"
            cand.write_bytes(raw)
            process(raw, out, category)
            twin = closest_sibling(out, category, asset_id) if design else None
            score = (twin[1] + twin[2]) if twin else 0.0
            if best is None or score < best[0]:
                best = (score, cand)
            if not twin:
                break
            last_try = attempt == tries
            self.log(f"art: {category}/{asset_id} looks too similar to {twin[0]} "
                     f"(colour {twin[1]:.2f}, shape {twin[2]:.2f}); "
                     + ("keeping the most distinct attempt" if last_try else "regenerating"))
            avoid = (f"The previous attempt looked too much like {twin[0]}. Make the silhouette and the colours "
                     f"clearly different from {twin[0]}, strictly following this subject's own palette.")
        if best is None:
            raise ArtError(f"{category}/{asset_id}: {err}")
        raw = best[1].read_bytes()
        raw_path.write_bytes(raw)
        for p in RAW_DIR.glob(f"{category}__{asset_id}.try*.png"):
            p.unlink(missing_ok=True)
        return process(raw, out, category)


if __name__ == "__main__":
    # python art_gen.py <category>/<id> "<description>" [--regenerate] [--repo <dir>]
    cfg = json.loads((HERE / "relay.json").read_text(encoding="utf-8"))
    args = sys.argv[1:]
    if args and args[0] == "--unblock":
        clear_block(args[1] if len(args) > 1 else None)
        print("unblocked", args[1] if len(args) > 1 else "all", "| still blocked:", list(blocked_backends()))
        sys.exit(0)
    repo = Path(args[args.index("--repo") + 1]) if "--repo" in args else Path(cfg["repo"])
    cat, aid = args[0].split("/", 1)
    print(ArtGenerator(cfg["chatgpt"]).make(repo, cat, aid, args[1], regenerate="--regenerate" in args))

def generate_assets(cfg: dict, repo: Path, assets: list, log, should_stop, tick=lambda: None) -> list[str]:
    """Generate a cycle's requested assets in parallel (art.parallel workers, each with its own browser tabs);
    returns one result line per asset, in request order (shared by the ART phase and the background art_runner)."""
    from concurrent.futures import ThreadPoolExecutor
    ac = cfg.get("art", {})
    lines: list = [None] * len(assets)
    jobs, regens = [], 0
    for i, a in enumerate(assets):
        p = asset_path(repo, a["category"], a["id"])
        rel = p.relative_to(repo).as_posix()
        regen = bool(a.get("regenerate")) and p.exists()
        if regen and regens >= int(ac.get("max_regenerate_per_cycle", 3)):
            lines[i] = f"- {rel}: regeneration skipped (per-cycle limit); kept the current image"
        elif p.exists() and not regen and not ac.get("regenerate_existing"):
            lines[i] = f"- {rel}: already existed, kept"
        else:
            regens += regen
            jobs.append((i, a, rel, regen))
    batch = "; ".join(f"{a['category']}/{a['id']} ({a['description'][:80]})" for _, a, _, _ in jobs)

    def one_subprocess(job):
        """Each asset in its own process (art_worker.py) with a hard timeout: a hung browser call is killed, not
        left holding a worker forever."""
        import subprocess
        import tempfile
        i, a, rel, regen = job
        if should_stop():
            return i, None
        spec = {"repo": str(repo), "category": a["category"], "id": a["id"], "description": a["description"],
                "regenerate": regen, "design_mode": ac.get("design_mode", "work"),
                "design_effort": ac.get("design_effort", "light"), "batch": batch,
                "stop_files": [str(p) for p in ac.get("_stop_files", [])], "log_file": ac.get("_log_file")}
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(spec, f)
        proc = subprocess.Popen([sys.executable, str(HERE / "art_worker.py"), f.name], stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace",
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            out, _ = proc.communicate(timeout=int(ac.get("job_timeout_s", 900)))
        except subprocess.TimeoutExpired:
            try:
                import psutil
                for c in psutil.Process(proc.pid).children(recursive=True):
                    c.kill()
            except Exception:   # noqa: BLE001
                pass
            proc.kill()
            proc.communicate()
            log(f"art: {rel} stuck; its worker process was killed (retried in a later pass)")
            out = "RESULT MISSING stuck (worker killed)"
        finally:
            Path(f.name).unlink(missing_ok=True)
        tick()
        res = next((l for l in reversed(out.splitlines()) if l.startswith("RESULT ")), "RESULT MISSING no result")
        if res.startswith("RESULT OK"):
            return i, (f"- {rel}: {'REDESIGNED and regenerated' if regen else 'generated'} "
                       f"({a['description'][:100]})")
        return i, (None if should_stop() else f"- {rel}: MISSING ({res[15:135]}); keep the existing fallback for it")

    def one(job):
        if ac.get("subprocess"):
            return one_subprocess(job)
        i, a, rel, regen = job
        if should_stop():
            return i, None
        gen = ArtGenerator(cfg["chatgpt"], log, should_stop)
        gen.design_mode = ac.get("design_mode", "work")
        gen.design_effort = ac.get("design_effort", "light")
        gen.batch = batch
        try:
            gen.make(repo, a["category"], a["id"], a["description"], regenerate=regen, redesign=regen)
            line = (f"- {rel}: {'REDESIGNED and regenerated' if regen else 'generated'} "
                    f"({a['description'][:100]})")
        except ArtError as e:
            line = None if should_stop() else f"- {rel}: MISSING ({str(e)[:120]}); keep the existing fallback for it"
        tick()
        return i, line

    # Watchdog: a browser call can hang forever (no timeout on some CDP calls). A job running longer than
    # HUNG_S is written off as MISSING (a later pass retries it) so one stuck tab never stalls the whole batch.
    from concurrent.futures import FIRST_COMPLETED, wait
    hung_s = int(ac.get("job_timeout_s", 1200)) + (180 if ac.get("subprocess") else 0)   # backstop
    started: dict = {}

    def timed(job):
        started[job[0]] = time.time()
        return one(job)

    pool = ThreadPoolExecutor(max_workers=max(1, int(ac.get("parallel", 3))))
    futs = {pool.submit(timed, j): j for j in jobs}
    pending = set(futs)
    while pending:
        done, pending = wait(pending, timeout=15, return_when=FIRST_COMPLETED)
        for f in done:
            i, line = f.result()
            lines[i] = line
        for f in list(pending):
            i, _a, rel, _r = futs[f]
            if i in started and time.time() - started[i] > hung_s:
                lines[i] = f"- {rel}: MISSING (stuck for over {hung_s // 60} min; abandoned, retried later)"
                log(f"art: {rel} stuck for over {hung_s // 60} min; abandoning it")
                pending.discard(f)
    pool.shutdown(wait=False, cancel_futures=True)
    if should_stop():
        raise ArtError("stop requested")
    return [l for l in lines if l]

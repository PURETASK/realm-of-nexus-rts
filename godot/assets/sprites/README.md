# Sprite drop-in folder

The renderer looks here before drawing a glyph. Any file that exists is used; anything missing keeps the current placeholder, so art can land one asset at a time.

## Units and heroes — `units/<unit id>.png`

Ids are the keys in `godot/data/factions.json` (for example `units/acolyte.png`, `units/tyvaris.png`). Two formats are accepted:

- **8-direction strip** (preferred): a horizontal strip of 8 square frames, in the order East, South-East, South, South-West, West, North-West, North, North-East. The renderer picks the frame from the unit's facing. 64 px frames for normal units, 96 px for heroes and large units.
- **Single sprite**: one square image drawn facing right; the renderer rotates it to the unit's facing.

The sprite is scaled so its frame spans the unit's collision radius times two plus 16 px, so leave a little transparent margin around the figure. The team colour is drawn as a ring under the sprite; leaving a grey area on the model for later team-colour masking is still recommended.

## Buildings — `buildings/<building id>.png`

One image per building, scaled to the footprint width; taller images extend upward from the footprint (a 2x2 building drawn 128 px wide can be 160 px tall). Main bases may provide tier variants as `buildings/<base id>_t1.png`, `_t2.png`, `_t3.png`; the renderer falls back to the plain id if a tier file is missing.

## Producing sprites from Meshy models

`tools/render_sprites.py` renders any .glb/.fbx/.obj/.blend with Blender into exactly these formats (see the header of that script). Blender 5.2 is installed on this machine at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.

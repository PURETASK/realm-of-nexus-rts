"""Render a 3D model (from Meshy or anywhere) into the sprite format the Godot renderer loads.

Run with Blender in background mode:

  blender -b -P tools/render_sprites.py -- --model path/to/model.glb --kind unit --out godot/assets/sprites/units/acolyte.png
  blender -b -P tools/render_sprites.py -- --model path/to/base.glb --kind building --size 192 --out godot/assets/sprites/buildings/necropolis_t1.png
  blender -b -P tools/render_sprites.py -- --demo --out /tmp/demo.png          # renders a built-in test mesh

Units are rendered as an 8-frame horizontal strip (E, SE, S, SW, W, NW, N, NE), 64 px per frame by default,
from a camera 55 degrees above the ground so the top-down renderer's facing angle matches. Buildings are one
frame, square, from the same camera. Output is PNG with alpha. Supported inputs: .glb/.gltf, .fbx, .obj, .blend.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", help="mesh file to render")
    ap.add_argument("--demo", action="store_true", help="render the built-in monkey instead of a model")
    ap.add_argument("--kind", choices=["unit", "building"], default="unit")
    ap.add_argument("--size", type=int, default=0, help="frame size in px (default 64 units, 128 buildings)")
    ap.add_argument("--frames", type=int, default=8, help="directions for units")
    ap.add_argument("--elevation", type=float, default=55.0, help="camera angle above the ground, degrees")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--out", required=True)
    return ap.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_model(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == ".blend":
        with bpy.data.libraries.load(path) as (src, dst):
            dst.objects = src.objects
        for o in dst.objects:
            if o is not None:
                bpy.context.scene.collection.objects.link(o)
    else:
        raise SystemExit("unsupported model type: " + ext)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def demo_model():
    bpy.ops.mesh.primitive_monkey_add(size=1.6)
    monkey = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(radius1=0.35, depth=1.2, location=(0.9, 0, 0.2), rotation=(0, math.radians(90), 0))
    cone = bpy.context.object
    mat = bpy.data.materials.new("demo"); mat.diffuse_color = (0.55, 0.24, 1.0, 1.0)
    mat2 = bpy.data.materials.new("demo2"); mat2.diffuse_color = (0.9, 0.85, 0.7, 1.0)
    monkey.data.materials.append(mat); cone.data.materials.append(mat2)
    return [monkey, cone]


def fit_objects(objs):
    """Parent everything under one empty at the origin, resting on z=0, scaled so its footprint fits a 2-unit box."""
    pivot = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in objs:
        if o.parent is None:
            o.parent = pivot
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    size = hi - lo
    footprint = max(size.x, size.y, 1e-6)
    scale = 2.0 / footprint
    pivot.scale = (scale, scale, scale)
    center = (lo + hi) / 2.0
    pivot.location = (-center.x * scale, -center.y * scale, -lo.z * scale)
    bpy.context.view_layer.update()
    return pivot, size.z * scale


def setup_camera(elevation_deg, height_units):
    cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.6 + height_units * 0.5
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    dist = 12.0
    el = math.radians(elevation_deg)
    cam.location = (0.0, -dist * math.cos(el), dist * math.sin(el) + height_units * 0.35)
    cam.rotation_euler = (math.radians(90.0 - elevation_deg), 0.0, 0.0)
    sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 3.0; sun.angle = math.radians(20)
    sun_o = bpy.data.objects.new("sun", sun); bpy.context.scene.collection.objects.link(sun_o)
    sun_o.rotation_euler = (math.radians(40), math.radians(-25), math.radians(20))
    fill = bpy.data.lights.new("fill", "SUN"); fill.energy = 1.0
    fill_o = bpy.data.objects.new("fill", fill); bpy.context.scene.collection.objects.link(fill_o)
    fill_o.rotation_euler = (math.radians(60), math.radians(30), math.radians(200))
    world = bpy.data.worlds.new("w"); bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.35, 0.35, 0.4, 1.0); bg.inputs[1].default_value = 0.6


def render_frames(pivot, size, frames, samples):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") and "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x = size; sc.render.resolution_y = size; sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    if hasattr(sc, "eevee"):
        sc.eevee.taa_render_samples = samples
    paths = []
    tmp = bpy.app.tempdir or os.path.dirname(os.path.abspath(__file__))
    for i in range(frames):
        # frame 0 faces +X (east on screen); rotating the model clockwise on screen = negative Z in Blender
        pivot.rotation_euler = (0.0, 0.0, -i * (2.0 * math.pi / frames))
        p = os.path.join(tmp, "sprite_frame_%d.png" % i)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    return paths


def stitch(paths, size, out):
    strip = bpy.data.images.new("strip", size * len(paths), size, alpha=True)
    pixels = [0.0] * (size * size * len(paths) * 4)
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p)
        src = list(img.pixels)
        for y in range(size):
            row_src = (y * size) * 4
            row_dst = (y * size * len(paths) + i * size) * 4
            pixels[row_dst:row_dst + size * 4] = src[row_src:row_src + size * 4]
        bpy.data.images.remove(img)
    strip.pixels = pixels
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    strip.filepath_raw = out; strip.file_format = "PNG"
    strip.save_render(out)


def main():
    a = parse_args()
    a.out = os.path.abspath(a.out)
    if a.model: a.model = os.path.abspath(a.model)
    clear_scene()
    objs = demo_model() if a.demo else import_model(a.model)
    if not objs:
        raise SystemExit("no meshes found")
    pivot, height = fit_objects(objs)
    setup_camera(a.elevation, height)
    size = a.size or (64 if a.kind == "unit" else 128)
    frames = a.frames if a.kind == "unit" else 1
    paths = render_frames(pivot, size, frames, a.samples)
    if frames == 1:
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        os.replace(paths[0], a.out)
    else:
        stitch(paths, size, a.out)
        for p in paths:
            try:
                os.remove(p)
            except OSError:
                pass
    print("wrote", a.out, "frames", frames, "size", size)


main()

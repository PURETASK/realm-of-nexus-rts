"""Regenerate .godot/global_script_class_cache.cfg from the class_name lines in scripts/.

Godot only writes this cache when the project is opened in the editor; without it a
headless `godot -s` run cannot resolve class names like GData or Game.
Run from the godot/ folder:  python tools/gen_class_cache.py
"""
import glob
import os
import re

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(HERE)

items = []
for path in sorted(glob.glob("scripts/*.gd")):
    src = open(path, encoding="utf-8").read()
    cls = re.search(r"^class_name\s+(\w+)", src, re.M)
    ext = re.search(r"^extends\s+([\w.]+)", src, re.M)
    if not cls:
        continue
    base = ext.group(1) if ext else "RefCounted"
    items.append(
        '{\n"base": &"%s",\n"class": &"%s",\n"icon": "",\n"language": &"GDScript",\n"path": "res://%s"\n}'
        % (base, cls.group(1), path.replace(os.sep, "/"))
    )

os.makedirs(".godot", exist_ok=True)
with open(".godot/global_script_class_cache.cfg", "w", encoding="utf-8") as f:
    f.write("list=Array[Dictionary]([" + ", ".join(items) + "])\n")
print("class cache: %d classes" % len(items))

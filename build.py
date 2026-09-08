"""Bundle Realm of Nexus into single-file builds.

  python build.py            -> dist/realm-of-nexus.html   (standalone, double-click to play)
  python build.py --fragment -> dist/realm-of-nexus.fragment.html (no doctype/html/head/body, for hosted wrappers)
"""
import re, sys, os, pathlib

root = pathlib.Path(__file__).parent
html = (root / 'index.html').read_text(encoding='utf-8')
css = (root / 'css' / 'style.css').read_text(encoding='utf-8')

scripts = re.findall(r'<script src="([^"?]+)(?:\?[^"]*)?"></script>', html)
js_parts = []
for s in scripts:
    code = (root / s).read_text(encoding='utf-8')
    code = code.replace("window.addEventListener('DOMContentLoaded', setupMenu);",
                        "if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', setupMenu); else setupMenu();")
    js_parts.append(f'// ---- {s} ----\n{code}')
js = '\n'.join(js_parts)

body = re.search(r'<body>(.*)</body>', html, re.S).group(1)
body = re.sub(r'<script src="[^"]+"></script>\s*', '', body).strip()

fragment = f'<title>Realm of Nexus</title>\n<style>\n{css}\n</style>\n{body}\n<script>\n{js}\n</script>\n'
full = ('<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        + fragment.replace('<title>Realm of Nexus</title>\n<style>', '<title>Realm of Nexus</title>\n<style>', 1).split('</style>\n', 1)[0] + '</style>\n</head>\n<body>\n'
        + fragment.split('</style>\n', 1)[1] + '</body>\n</html>\n')

dist = root / 'dist'; dist.mkdir(exist_ok=True)
if '--fragment' in sys.argv:
    out = dist / 'realm-of-nexus.fragment.html'; out.write_text(fragment, encoding='utf-8')
else:
    out = dist / 'realm-of-nexus.html'; out.write_text(full, encoding='utf-8')
print(out, f'{out.stat().st_size/1024:.0f} KB')

"""Pack the mod for a release: dist/creator-palettes-<version>.zip, with the creator-palettes folder and each of the
palettes (palettes/palette-*) at its top, one mod a folder (the way wcmods adds mods from a .zip: one .zip can
hold several).

    python tools/pack.py
"""
import json
import os
import zipfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(HERE, "creator-palettes")
PALETTES = os.path.join(HERE, "palettes")


def add_folder(z, folder, top):
    for at, dirs, files in os.walk(folder):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(at, name)
            z.write(path, top + "/" + os.path.relpath(path, folder).replace(os.sep, "/"))


def main():
    with open(os.path.join(MOD, "mod.json"), encoding="utf-8") as f:
        version = json.load(f)["version"]
    out = os.path.join(HERE, "dist", f"creator-palettes-{version}.zip")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    palettes = sorted(d for d in os.listdir(PALETTES) if os.path.isfile(os.path.join(PALETTES, d, "mod.json"))) \
        if os.path.isdir(PALETTES) else []
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        add_folder(z, MOD, "creator-palettes")
        for name in palettes:
            add_folder(z, os.path.join(PALETTES, name), name)
    print(out, f"(the mod and {len(palettes)} palettes)")


if __name__ == "__main__":
    main()

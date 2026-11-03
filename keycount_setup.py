#!/usr/bin/env python3
"""Install Keycount's user binding and persist its unified configuration."""

import argparse
import json
import os
import tempfile
from pathlib import Path


PLUGIN_ID = "io.github.noobyco.keycount"
POSITIONS = {
    "center", "left-center", "right-center", "top-center", "bottom-center",
    "top-right-edge", "top-left-edge", "bottom-right-edge", "bottom-left-edge",
}
BINDING_START = "-- Keycount plugin binding"
BINDING_END = "-- End Keycount plugin binding"
BINDING = "\n".join((
    BINDING_START,
    'o.bind("SUPER + SHIFT + K", "Toggle Keycount", {',
    f'  panel = "{PLUGIN_ID}"',
    "})",
    BINDING_END,
))


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode if path.exists() else 0o644
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, encoding="utf-8") as handle:
        handle.write(content)
        temporary = Path(handle.name)
    os.chmod(temporary, mode)
    temporary.replace(path)


def bindings_path(home):
    return home / ".config" / "hypr" / "bindings.lua"


def config_path(home):
    return home / ".config" / "omarchy" / "keycount.json"


def ensure_binding(home):
    path = bindings_path(home)
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    if BINDING_START in existing or f'panel = "{PLUGIN_ID}"' in existing:
        return False
    suffix = "" if not existing or existing.endswith("\n") else "\n"
    atomic_write(path, existing + suffix + "\n" + BINDING + "\n")
    return True


def remove_binding(home):
    path = bindings_path(home)
    if not path.exists():
        return False
    existing = path.read_text(encoding="utf-8")
    start = existing.find(BINDING_START)
    end = existing.find(BINDING_END, start)
    if start < 0 or end < 0:
        return False
    end += len(BINDING_END)
    before = existing[:start].rstrip()
    after = existing[end:].lstrip("\n")
    atomic_write(path, (before + "\n" if before else "") + after)
    return True


def save_placement(home, placement):
    if placement not in POSITIONS:
        raise ValueError(f"invalid placement: {placement}")
    path = config_path(home)
    config = {}
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                config = loaded
        except (json.JSONDecodeError, OSError):
            pass
    config["position"] = placement
    atomic_write(path, json.dumps(config, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ensure-binding", action="store_true")
    parser.add_argument("--remove-binding", action="store_true")
    parser.add_argument("--placement", choices=sorted(POSITIONS))
    args = parser.parse_args()
    home_value = os.environ.get("HOME")
    if not home_value:
        parser.error("HOME is required")
    home = Path(home_value).expanduser()

    if args.ensure_binding:
        ensure_binding(home)
    if args.remove_binding:
        remove_binding(home)
    if args.placement:
        save_placement(home, args.placement)
    if not (args.ensure_binding or args.remove_binding or args.placement):
        parser.error("choose an action")


if __name__ == "__main__":
    main()

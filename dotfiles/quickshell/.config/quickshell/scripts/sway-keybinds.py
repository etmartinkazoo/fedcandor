#!/usr/bin/env python3
"""Print sway keybindings as JSON for the Quickshell keybinds overlay.

Reads ~/.config/sway/config plus the config.d drop-ins sway includes (user
files override same-named system ones). A "## Heading" comment starts a
section; a "# comment" describes the bindings below it, up to the next blank
line. Uncommented bindings are described by their sway command. Consecutive
bindings with the same description become one entry ("Super + H/J/K/L").

Output: [{"section", "desc", "keys": "Super + H/J/K/L",
          "combos": [{"mods": ["Super"], "keys": ["H", "J", "K", "L"]}, ...]}, ...]
(a "keys" of "1…0" stands for the whole run 1-0).
"""
import glob
import json
import os
import re

home = os.path.expanduser("~")
xdg = os.environ.get("XDG_CONFIG_HOME", os.path.join(home, ".config"))
main = os.path.join(xdg, "sway", "config")

dropins = {}
for d in ("/usr/share/sway/config.d", "/etc/sway/config.d", os.path.join(xdg, "sway", "config.d")):
    for f in sorted(glob.glob(os.path.join(d, "*.conf"))):
        dropins[os.path.basename(f)] = f
files = [main] + [dropins[k] for k in sorted(dropins)]

variables = {}
bindings = []
MODS = {"$mod": "Super", "mod4": "Super", "mod1": "Alt", "alt": "Alt", "shift": "Shift", "control": "Ctrl", "ctrl": "Ctrl"}
KEYS = {
    "period": ".", "comma": ",", "minus": "-", "equal": "=", "slash": "/", "space": "Space",
    "escape": "Esc", "left": "←", "right": "→", "up": "↑", "down": "↓", "grave": "`",
    "AudioRaiseVolume": "Vol +", "AudioLowerVolume": "Vol −", "AudioMute": "Mute",
    "AudioMicMute": "Mic Mute", "AudioPlay": "Play", "AudioPause": "Pause", "AudioNext": "Next",
    "AudioPrev": "Prev", "AudioStop": "Stop", "AudioForward": "Fwd", "AudioRewind": "Rew",
    "MonBrightnessUp": "Bright +", "MonBrightnessDown": "Bright −",
}


def expand(s):
    for k in sorted(variables, key=len, reverse=True):
        s = s.replace(k, variables[k])
    return s


def key_name(p):
    if p.startswith("XF86"):
        p = p[4:]
    if p in KEYS:
        return KEYS[p]
    if p.lower() in KEYS:
        return KEYS[p.lower()]
    return p[:1].upper() + p[1:] if len(p) > 1 else p.upper()


def split_keys(combo):
    """'$mod+Shift+h' -> (['Super', 'Shift'], 'H')"""
    parts = combo.split("+")
    mods = [MODS.get(p.lower(), key_name(p)) for p in parts[:-1]]
    return mods, key_name(parts[-1])


def describe(cmd):
    m = re.match(r"exec\s+(.*)", cmd)
    if m:
        c = m.group(1)
        q = re.search(r"qs ipc call (\w+) (\w+)", c)
        if q:
            return "Quickshell: %s %s" % (q.group(1), q.group(2))
        return "Run: " + c
    cmd = cmd.replace("splith", "split horizontal").replace("splitv", "split vertical").replace('"', "")
    return cmd[:1].upper() + cmd[1:]


def add(raw_combo, cmd, comment, section, mode):
    combo = expand(raw_combo)
    if combo.startswith("--"):
        return
    desc = comment or describe(expand(cmd))
    if mode and mode != "default":
        section = "%s mode" % mode.capitalize()
    mods, key = split_keys(combo)
    bindings.append({"section": section, "desc": desc, "mods": mods, "key": key})


def parse_bind(rest):
    # rest: everything after "bindsym", flags first
    toks = rest.split(None, 1)
    while toks and toks[0].startswith("--"):
        toks = toks[1].split(None, 1) if len(toks) > 1 else []
    if len(toks) < 2:
        return None
    return toks[0], toks[1]


for path in files:
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        continue
    section = "Other"
    comment = ""
    mode = None
    in_block = False
    for raw in lines:
        line = raw.strip()
        if not line:
            comment = ""
            continue
        if line.startswith("## "):
            section = line[3:].strip()
            comment = ""
            continue
        if line.startswith("#"):
            text = line.lstrip("#").strip()
            if text:
                comment = text
            continue
        if line.startswith("set "):
            parts = line.split(None, 2)
            if len(parts) == 3:
                variables[parts[1]] = expand(parts[2])
            continue
        m = re.match(r'mode\s+(?:--\S+\s+)?"?([^"{]+?)"?\s*\{', line)
        if m:
            mode = m.group(1)
            continue
        if line.startswith("bindsym") and line.endswith("{"):
            in_block = True
            continue
        if line == "}":
            if in_block:
                in_block = False
            else:
                mode = None
            continue
        if in_block:
            parts = line.split(None, 1)
            if len(parts) == 2:
                add(parts[0], parts[1], comment, section, mode)
            continue
        if line.startswith("bindsym "):
            parsed = parse_bind(line[len("bindsym "):])
            if parsed:
                add(parsed[0], parsed[1], comment, section, mode)

# Sway uses the last binding of a combo; drop earlier ones it overrides.
last = {}
for i, b in enumerate(bindings):
    last[(b["section"].endswith(" mode") and b["section"], tuple(b["mods"]), b["key"])] = i
bindings = [b for i, b in enumerate(bindings)
            if last[(b["section"].endswith(" mode") and b["section"], tuple(b["mods"]), b["key"])] == i]


def short_keys(keys):
    if len(keys) > 4 and all(k.isdigit() for k in keys):
        return [keys[0] + "…" + keys[-1]]
    return keys


def text(combo):
    keys = combo["keys"]
    sep = " " if any(len(k) == 1 and not k.isalnum() for k in keys) else "/"
    return " + ".join(combo["mods"] + [sep.join(keys)])


# Merge consecutive bindings with the same section and description; within an
# entry, bindings sharing modifiers collapse into one "Super + H/J/K/L".
out = []
for b in bindings:
    prev = out[-1] if out else None
    if prev and prev["section"] == b["section"] and prev["desc"] == b["desc"]:
        groups = prev["_groups"]
    else:
        prev = {"section": b["section"], "desc": b["desc"], "_groups": []}
        out.append(prev)
        groups = prev["_groups"]
    for mods, keys in groups:
        if mods == b["mods"]:
            if b["key"] not in keys:
                keys.append(b["key"])
            break
    else:
        groups.append((b["mods"], [b["key"]]))

for e in out:
    e["combos"] = [{"mods": mods, "keys": short_keys(keys)} for mods, keys in e.pop("_groups")]
    e["keys"] = " / ".join(text(c) for c in e["combos"])
# Drop-ins can add to a section from the main config: keep each section together,
# in order of first appearance.
order = {}
for e in out:
    order.setdefault(e["section"], len(order))
out.sort(key=lambda e: order[e["section"]])
print(json.dumps(out))

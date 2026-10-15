#!/usr/bin/env python3
"""Print sway keybindings as JSON for the Quickshell cheatsheet.

Reads ~/.config/sway/config plus the config.d drop-ins sway includes (user
files override same-named system ones). Sway commands describe
themselves ("focus left", "workspace number 3"); for exec bindings the comment
directly above is used when present, else the command line.
"""
import glob
import json
import os
import re
import shlex

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
MODS = {"$mod": "Super", "mod4": "Super", "mod1": "Alt", "shift": "Shift", "control": "Ctrl", "ctrl": "Ctrl"}


def expand(s):
    for k in sorted(variables, key=len, reverse=True):
        s = s.replace(k, variables[k])
    return s


def pretty_keys(combo):
    parts = []
    for p in combo.split("+"):
        low = p.lower()
        if low in MODS:
            parts.append(MODS[low])
        elif p.startswith("XF86"):
            parts.append(p[4:])
        else:
            parts.append(p[:1].upper() + p[1:] if len(p) > 1 else p.upper())
    return " + ".join(parts)


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


def add(raw_combo, cmd, comment, mode):
    combo = expand(raw_combo)
    if combo.startswith("--"):
        return
    cmd = expand(cmd)
    desc = (comment if cmd.startswith("exec") and comment else "") or describe(cmd)
    if mode and mode != "default":
        desc = "[%s] %s" % (mode, desc)
    bindings.append({"keys": pretty_keys(combo), "desc": desc})


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
    comment = ""
    mode = None
    in_block = False
    for raw in lines:
        line = raw.strip()
        if not line:
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
                add(parts[0], parts[1], "", mode)
            continue
        if line.startswith("bindsym "):
            parsed = parse_bind(line[len("bindsym "):])
            if parsed:
                add(parsed[0], parsed[1], comment, mode)

# Drop later duplicates of the same key combo (sway uses the last one, but the
# first is usually the documented one in the main config).
seen = set()
out = []
for b in bindings:
    if b["keys"] in seen:
        continue
    seen.add(b["keys"])
    out.append(b)
print(json.dumps(out))

#!/bin/sh
# Capture window snapshots for the overview and taskbar/dock previews.
# Usage: window-thumbs.sh DIR CON_ID TOPLEVEL_ID [CON_ID TOPLEVEL_ID ...]
# Each window is captured with grim (by its foreign-toplevel identifier) at
# half scale into DIR/CON_ID.png. DIR is private to the user.
set -u
dir=$1
shift
mkdir -p "$dir" && chmod 700 "$dir" || exit 1
while [ $# -ge 2 ]; do
    id=$1 toplevel=$2
    shift 2
    case $id$toplevel in *[!0-9a-f]*) continue ;; esac
    { grim -s 0.5 -T "$toplevel" "$dir/$id.png.tmp" 2>/dev/null && mv -f "$dir/$id.png.tmp" "$dir/$id.png"; } &
done
wait

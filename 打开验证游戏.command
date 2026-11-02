#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v godot >/dev/null 2>&1; then
	exec godot --path "$DIR"
fi
exec "/Applications/Godot.app/Contents/MacOS/Godot" --path "$DIR"

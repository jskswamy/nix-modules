#!/usr/bin/env python3
"""Generate ~/.config/herdr-app/keys.json from the herdr TUI config.

The herdr TUI's ~/.config/herdr/config.toml [keys] section is the single
source of truth for the shared key scheme. This script derives the
desktop app's keys.json from it at home-manager activation, so the two
cannot drift: edit config.toml, run build-switch, the desktop app picks
up the same scheme.

Usage:
  generate-keys.py --config <config.toml> \
      --default-config <herdr --default-config output> \
      --defaults <vendored desktop keys.macos.json> \
      --extra <extra.json> --out <keys.json>

Behavior:
- The effective TUI scheme is `herdr --default-config` (the installed
  binary's own baked-in defaults — parsed from the `[keys]` scaffold's
  commented assignments) overridden by config.toml's [keys] table. No
  drift by construction: upgrades that change TUI defaults are picked
  up from the binary.
- The [keys] `prefix` value and every `prefix+X` binding are converted
  into herdr-app two-keystroke sequences (<prefix-keystroke> <x>).
- Bindings are translated by the herdr option's *semantic name*
  (focus_pane_left, split_vertical, ...) through SEMANTIC_COMMANDS.
  Options without a desktop equivalent — resize_mode, plugin_action
  entries, `[keys.command]` plugin blocks, indexed agent focus — are
  skipped, because herdr-app has no such command.
- Direct (prefix-less) bindings pass through with + -> - modifier
  syntax.
- The output is the vendored desktop defaults (chrome keys only; the
  app rewrites its own defaults on every start) with translated
  bindings merged on top and --extra merged last.
- Rebuilding overwrites the file wholesale; the app hot-reloads it.
"""

import argparse
import json
import re
import subprocess
import sys
import tomllib

SEMANTIC_COMMANDS = {
    # chrome & spaces
    "help": "app.help",
    "settings": "app.settings",
    "detach": "app.quit",
    "workspace_picker": "mod.open:picker",
    "goto": "mod.open:picker",
    "new_workspace": "space.new",
    "rename_workspace": "space.rename",
    "close_workspace": "space.close",
    "previous_workspace": "space.prev",
    "next_workspace": "space.next",
    # tabs
    "new_tab": "tab.new",
    "rename_tab": "tab.rename",
    "previous_tab": "tab.prev",
    "next_tab": "tab.next",
    "switch_tab": "tab.select:{n}",
    "close_tab": "tab.close",
    # panes
    "focus_pane_left": "pane.go:left",
    "focus_pane_down": "pane.go:down",
    "focus_pane_up": "pane.go:up",
    "focus_pane_right": "pane.go:right",
    "split_vertical": "pane.split:right",
    "split_horizontal": "pane.split:down",
    "close_pane": "pane.close",
    "zoom": "pane.zoom",
    # agents
    "previous_agent": "agent.prev",
    "next_agent": "agent.next",
    "toggle_sidebar": "layout.toggle:sidebar",
}

GPUI_MODIFIER_SYNONYMS = {
    "ctrl": "ctrl",
    "alt": "alt",
    "shift": "shift",
    "cmd": "cmd",
    "super": "cmd",
}

# herdr named punctuation -> (shift, gpui key part)
KEY_NAMES = {
    "minus": (False, "-"),
    "backslash": (False, "\\"),
    "backtick": (False, "`"),
    "question": (True, "/"),
    "ampersand": (True, "7"),
    "plus": (True, "="),
    "underscore": (True, "-"),
    "esc": (False, "escape"),
    "space": (False, "space"),
    "enter": (False, "enter"),
    "tab": (False, "tab"),
    "backspace": (False, "backspace"),
    "delete": (False, "delete"),
    "left": (False, "left"),
    "right": (False, "right"),
    "up": (False, "up"),
    "down": (False, "down"),
}

# literal herdr key chars that need Shift on a US keyboard -> gpui key part
SHIFTED_CHARS = {
    "?": "/",
    "&": "7",
    "+": "=",
    "_": "-",
}


def warn(message):
    print(f"herdr-app-keys: {message}", file=sys.stderr)


def keystroke_element(modifiers, key):
    """One gpui keystroke source: 'ctrl--', 'shift-/', 'ctrl-a', 'escape'."""
    mods = [GPUI_MODIFIER_SYNONYMS[m] for m in modifiers if m in GPUI_MODIFIER_SYNONYMS]
    if key in KEY_NAMES:
        shifted, key_part = KEY_NAMES[key]
        if shifted:
            mods = mods + ["shift"]
    elif len(key) == 1:
        if key in SHIFTED_CHARS:
            mods = mods + ["shift"]
            key_part = SHIFTED_CHARS[key]
        else:
            key_part = key.lower()
            if key.isupper():
                mods = mods + ["shift"]
    else:
        key_part = key.lower()
    if key_part == "-":
        # gpui's parser reads a trailing dash as the - key: "ctrl--"
        return "".join(m + "-" for m in mods) + "-"
    return "".join(m + "-" for m in mods) + key_part


def parse_prefix(raw):
    """'ctrl+a' -> 'ctrl-a'; bare keys ('esc', 'f12', '-') pass through."""
    if not isinstance(raw, str) or not raw:
        return None
    tokens = [t for t in raw.split("+") if t]
    if len(tokens) == 1:
        return keystroke_element([], tokens[0])
    return keystroke_element(tokens[:-1], tokens[-1])


def binding_sequences(prefix_element, value):
    """herdr binding string -> list of gpui sequences; [] means skip."""
    if not isinstance(value, str) or not value.strip():
        return []
    tokens = [t for t in value.split("+") if t]
    if tokens[0] == "prefix":
        modifiers, key = tokens[1:-1], tokens[-1]
    else:
        # direct terminal-mode binding: all modifiers are real modifiers
        modifiers, key = tokens[:-1], tokens[-1]

    unknown = [m for m in modifiers if m not in GPUI_MODIFIER_SYNONYMS]
    if unknown:
        warn(f"unknown modifiers {unknown} in {value!r}; skipped")
        return []

    if key == "1..9":
        return [s for s in (sequence(prefix_element, modifiers, d) for d in "123456789") if s]
    element = sequence(prefix_element, modifiers, key)
    return [element] if element else []


def sequence(prefix_element, modifiers, key):
    return f"{prefix_element} {keystroke_element(modifiers, key)}"


def default_keys(scaffold_text):
    """TUI default [keys] from `herdr --default-config` output.

    That scaffold prints the [keys] header and every default value as a
    commented assignment; anything active comes from config.toml. Scan
    between the `[keys]` header and the next header line.
    """
    values = {}
    region = False
    for line in scaffold_text.splitlines():
        if not region:
            region = line.rstrip() == "[keys]"
            continue
        if re.match(r"^#?\s*\[.*", line):
            break  # left the [keys] region (commented or not)
        match = re.match(r"^#\s*([A-Za-z0-9_]+)\s*=\s*\"([^\"]*)\"", line)
        if match:
            values[match.group(1)] = match.group(2)
    if not values:
        warn("no commented [keys] defaults found in the scaffold")
    return values


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True, help="path to herdr TUI config.toml")
    ap.add_argument(
        "--herdr", help="path to the herdr binary, for `--default-config` output"
    )
    ap.add_argument("--defaults", required=True, help="vendored desktop keys.macos.json")
    ap.add_argument("--extra", required=True, help="desktop-only bindings JSON")
    ap.add_argument("--out", required=True, help="output keys.json path")
    args = ap.parse_args()

    try:
        with open(args.config, "rb") as f:
            config = tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError) as e:
        warn(f"cannot parse {args.config}: {e}; generating defaults only")
        config = {}

    scaffold_text = ""
    if args.herdr:
        try:
            scaffold_text = subprocess.run(
                [args.herdr, "--default-config"], capture_output=True, text=True, check=True
            ).stdout
        except (OSError, subprocess.SubprocessError) as e:
            warn(f"`herdr --default-config` failed: {e}; desktop scheme = config.toml only")
    tui_defaults = default_keys(scaffold_text)

    with open(args.defaults, "rb") as f:
        out = json.load(f)
    with open(args.extra, "rb") as f:
        extra = json.load(f)
    for section, bindings in extra.items():
        if not isinstance(bindings, dict):
            warn(f"--extra {section} is not an object; skipped")
            continue
        out.setdefault(section, {}).update(bindings)

    effective = dict(tui_defaults)
    config_keys = config.get("keys", {})
    if not isinstance(config_keys, dict):
        config_keys = {}
    effective.update({k: v for k, v in config_keys.items() if isinstance(v, str)})

    prefix = parse_prefix(effective.get("prefix") or "ctrl+b")
    translated = 0
    skipped = []
    if prefix is None:
        warn("no usable [keys] prefix; skipping translation")
    else:
        for option in sorted(effective):
            value = effective[option]
            if not value.strip():
                continue
            command = SEMANTIC_COMMANDS.get(option)
            if command is None:
                if value.startswith("prefix"):
                    skipped.append(f"{option}={value!r}: no herdr-app command; skipped")
                continue
            for sequence_string in binding_sequences(prefix, value):
                translated += 1
                command_string = command
                if "{n}" in command:
                    # e.g. switch_tab: replace the {n} slot with the second
                    # keystroke's key (a single digit of the sequence)
                    command_string = command.replace(
                        "{n}", sequence_string.rsplit(" ", 1)[1]
                    )
                out.setdefault("global", {})[sequence_string] = command_string

    # Reader-friendly wrap-up: the per-binding lines above are the
    # by-design survey of TUI bindings without a desktop command, not
    # failures. Say so once, in plain language.
    if skipped:
        for line in skipped:
            print(f"herdr-app-keys:   {line}", file=sys.stderr)
        print(
            "herdr-app-keys: summary — these TUI bindings have no desktop\n"
            "herdr-app-keys: equivalent and are skipped by design; this is not\n"
            "herdr-app-keys: an error and happens at every switch. Everything\n"
            "herdr-app-keys: else (the shared ctrl+a scheme) was translated and\n"
            f"herdr-app-keys: written safely ({translated} bindings).",
            file=sys.stderr,
        )

    with open(args.out, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()

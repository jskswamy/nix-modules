#!/usr/bin/env python3
"""Make Skillshare's OpenCode plugin registrations loadable by OpenCode V2.

Skillshare 0.27.0 records each plugin as a file URL of its entry
(``file://…/index.js``) and writes that into ``plugins``. OpenCode V2 skips a
path that is not a directory, so the plugin never loads and neither do the
skills it would register.

This keeps Skillshare's file URL, which is the identity it matches on the next
sync, and adds the parent directory beside it. OpenCode skips the file and
loads ``index.js`` from the directory. A directory previously added here is
removed once its file URL is gone, so an uninstalled plugin does not stay loaded.
Other plugin entries are left alone.
"""

import json
import os
import sys
from urllib.parse import unquote, urlparse, urlunparse

MARKER = "/skillshare/plugins/"


def file_path(entry):
    if not isinstance(entry, str) or not entry.startswith("file:"):
        return None
    parsed = urlparse(entry)
    if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
        return None
    return os.path.normpath(unquote(parsed.path))


def file_url(path):
    return urlunparse(("file", "", os.path.normpath(path), "", "", ""))


def managed(path):
    return path is not None and MARKER in path


def rewrite(entries):
    wanted = []
    for entry in entries:
        path = file_path(entry)
        if managed(path) and os.path.isfile(path):
            parent = os.path.dirname(path)
            if parent not in wanted:
                wanted.append(parent)
    wanted_urls = [file_url(path) for path in wanted]
    kept = []
    for entry in entries:
        path = file_path(entry)
        if managed(path) and os.path.isdir(path) and path not in wanted:
            continue
        kept.append(entry)
    present = {entry for entry in kept if isinstance(entry, str)}
    for url in wanted_urls:
        if url not in present:
            kept.append(url)
    return kept


def replace_plugins(text, plugins):
    marker = '"plugins"'
    idx = text.find(marker)
    if idx < 0:
        return text, False
    i = idx + len(marker)
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    if i >= len(text) or text[i] != ":":
        raise ValueError("plugins key has no value")
    i += 1
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    _, end = json.JSONDecoder().raw_decode(text, i)
    updated = text[:i] + json.dumps(plugins, separators=(",", ":")) + text[end:]
    return updated, updated != text


def config_path(directory):
    found = []
    for name in ("opencode.json", "opencode.jsonc"):
        path = os.path.join(directory, name)
        if os.path.lexists(path):
            found.append(path)
    if len(found) > 1:
        raise ValueError(f"both opencode.json and opencode.jsonc exist in {directory}")
    return found[0] if found else None


def repair(directory):
    path = config_path(directory)
    if path is None:
        return False
    if os.path.islink(path):
        raise ValueError(f"{path} is a symlink; refusing to edit it")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    data = json.loads(text)
    plugins = data.get("plugins")
    if not isinstance(plugins, list):
        return False
    rewritten = rewrite(plugins)
    if rewritten == plugins:
        return False
    updated, changed = replace_plugins(text, rewritten)
    if not changed:
        return False
    mode = os.stat(path).st_mode & 0o777
    temporary = path + ".opencode-plugins.tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        handle.write(updated)
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary, mode)
    os.replace(temporary, path)
    return True


def main(argv):
    status = 0
    for directory in argv:
        try:
            if repair(directory):
                print(f"opencode plugins: updated registrations in {directory}", file=sys.stderr)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            print(f"opencode plugins: warning: {directory}: {error}", file=sys.stderr)
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

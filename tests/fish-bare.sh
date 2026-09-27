#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
cleanup() {
	rm -rf "$tmp"
}
trap cleanup EXIT

if grep -n -E 'alias[[:space:]]+[^=]+=(eza|bat|difft|nvim|lazygit|tmuxp|direnv|jump|any-nix-shell|fzf|fd)|set[[:space:]]+-gx[[:space:]]+(EDITOR|MANPAGER|FZF_DEFAULT_OPTS|GPG_TTY)' modules/tools/fish/config/conf.d/*.fish; then
	exit 1
fi

mkdir -p "$tmp/bin" "$tmp/home"
for cmd in env sh bash git tty; do
	ln -s "$(command -v "$cmd")" "$tmp/bin/$cmd"
done

if command -v fish >/dev/null 2>&1; then
	fish_bin=$(command -v fish)
else
	fish_bin=$(nix build --no-link --print-out-paths nixpkgs#fish)/bin/fish
fi

# shellcheck disable=SC2016 # This is fish code; variables expand in fish.
script='for f in modules/tools/fish/config/conf.d/*.fish; source $f; end; for var in EDITOR MANPAGER FZF_DEFAULT_OPTS GPG_TTY; set -q $var; and echo "$var is set"; end'

set +e
output=$(env -i HOME="$tmp/home" PATH="$tmp/bin" TERM=xterm "$fish_bin" --no-config -i -c "$script" 2>&1)
set -e
output=$(perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g' <<<"$output")
output=${output%$'\n'}

if [[ -n $output ]]; then
	printf '%s\n' "$output" >&2
	exit 1
fi

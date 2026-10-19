#!/usr/bin/env bash
# Supply the module's runtime packages on PATH; this never activates Home Manager.
# cold [new-directory] bootstraps pinned plugins; warm DIRECTORY reuses that state.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
mode=${1:?usage: nvim-smoke.sh cold [directory] | warm directory}
case "$mode" in
cold)
	state=${2:-$(mktemp -d)}
	if [[ -d "$state/config" || -d "$state/data" ]]; then
		echo "Refusing to overwrite existing smoke-test state: $state" >&2
		exit 1
	fi
	mkdir -p "$state"
	state=$(cd "$state" && pwd)
	mkdir -p "$state/config" "$state/data/nvim/lazy" "$state/state" "$state/cache" "$state/work"
	cp -R "$repo/modules/tools/nvim/config" "$state/config/nvim"
	chmod -R u+w "$state/config/nvim"
	# Seed both spec providers before setup can resolve newer plugin specifications.
	python3 - "$state" <<'PY'
import json, pathlib, subprocess, sys
state = pathlib.Path(sys.argv[1])
lock = json.loads((state / 'config/nvim/lazy-lock.json').read_text())
for name, repo in [('lazy.nvim', 'folke/lazy.nvim'), ('LazyVim', 'LazyVim/LazyVim')]:
    directory = state / 'data/nvim/lazy' / name
    subprocess.run(['git', 'clone', '--quiet', '--filter=blob:none', '--no-checkout', f'https://github.com/{repo}.git', str(directory)], check=True)
    subprocess.run(['git', '-C', str(directory), 'checkout', '--quiet', lock[name]['commit']], check=True)
PY
	;;
warm)
	state=$(cd "${2:?warm requires the cold run directory}" && pwd)
	test -f "$state/config/nvim/lazy-lock.json"
	;;
*)
	echo "Unknown smoke-test mode: $mode" >&2
	exit 2
	;;
esac
export XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" XDG_STATE_HOME="$state/state" XDG_CACHE_HOME="$state/cache"
export NVIM_SMOKE_REPO="$repo" NVIM_SMOKE_STATE="$state" NVIM_SMOKE_MODE="$mode"
echo "Smoke-test state: $state"
# Mirror the module's managed XDG files before LazyVim tries to install parsers.
data=$(nix build --impure --no-link --print-out-paths --file "$repo/tests/nvim-runtime.nix" data)
mkdir -p "$state/data/nvim/site/"{parser,parser-info,queries}
for file in parser/latex.so parser-info/latex.revision queries/latex; do
	ln -sfn "$data/$file" "$state/data/nvim/site/$file"
done
cd "$state/work"
python3 -m pip --version
python3 -m venv "$state/venv-$mode"
printf 'int main(void) { return 0; }\n' >"$state/compiler.c"
cc "$state/compiler.c" -o "$state/compiler-$mode"
"$state/compiler-$mode"
timeout 900s nvim --headless -i NONE '+lua dofile(os.getenv("NVIM_SMOKE_REPO") .. "/tests/nvim-health.lua")' >"$state/$mode.log" 2>&1
# Verify actual checkouts, not just whether lazy left the lockfile unchanged.
python3 - "$state" "$repo" <<'PY'
import json, pathlib, subprocess, sys
state, repo = map(pathlib.Path, sys.argv[1:])
expected = json.loads((repo / 'modules/tools/nvim/config/lazy-lock.json').read_text())
actual = json.loads((state / 'config/nvim/lazy-lock.json').read_text())
assert actual == expected, 'Plugin lock changed during bootstrap'
# The lock also retains disabled plugins; only active plugins need checkouts.
active = (state / 'active-plugins.txt').read_text().splitlines()
assert active, 'No active plugins reported'
for name in active:
    assert name in expected, f'Active plugin missing from source lock: {name}'
    directory = state / 'data/nvim/lazy' / name
    revision = subprocess.check_output(['git', '-C', str(directory), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == expected[name]['commit'], f'{name}: {revision} != {expected[name]["commit"]}'
print(f'PASS {len(active)} active plugin revisions match the unchanged source lock')
PY
printf 'PASS %s smoke test; logs: %s\n' "$mode" "$state"

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
for name, pin in expected.items():
    directory = state / 'data/nvim/lazy' / name
    revision = subprocess.check_output(['git', '-C', str(directory), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == pin['commit'], f'{name}: {revision} != {pin["commit"]}'
print(f'PASS {len(expected)} plugin revisions match the source lock')
PY
printf 'PASS %s smoke test; logs: %s\n' "$mode" "$state"

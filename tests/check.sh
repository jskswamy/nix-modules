#!/usr/bin/env bash
# tests/check.sh integration        assert every integration case holds
# tests/check.sh nix-upgrade        assert nix-upgrade introspection holds
# tests/check.sh nvim-config        assert Mason and Biome config contracts
# tests/check.sh fish-bare          assert fish config is quiet without tools
# tests/check.sh skillshare         assert the skillshare reconcile contract
# tests/check.sh snapshot OUT.json  write the full-tool-set snapshot
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
integration)
	out=$(nix eval --impure --json -f tests/integration.nix)
	jq -r 'to_entries[] | "\(if .value then "PASS" else "FAIL" end)  \(.key)"' <<<"$out"
	jq -e 'all(.[]; . == true)' <<<"$out" >/dev/null
	;;
nix-upgrade)
	out=$(nix eval --impure --json -f tests/nix-upgrade.nix)
	jq -r 'to_entries[] | "\(if .value then "PASS" else "FAIL" end)  \(.key)"' <<<"$out"
	jq -e 'all(.[]; . == true)' <<<"$out" >/dev/null
	;;
nvim-config)
	nvim --headless -u NONE -i NONE -l tests/nvim-config.lua
	;;
fish-bare)
	tests/fish-bare.sh
	;;
skillshare)
	tests/skillshare-reconcile.sh
	;;
snapshot)
	nix eval --impure --json -f tests/snapshot.nix | jq -S . >"${2:?usage: check.sh snapshot OUT.json}"
	;;
*)
	echo "usage: $0 integration | nix-upgrade | nvim-config | fish-bare | skillshare | snapshot OUT.json" >&2
	exit 2
	;;
esac

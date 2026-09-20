#!/usr/bin/env bash
# tests/check.sh integration        assert every integration case holds
# tests/check.sh snapshot OUT.json  write the full-tool-set snapshot
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
integration)
	out=$(nix eval --impure --json -f tests/integration.nix)
	jq -r 'to_entries[] | "\(if .value then "PASS" else "FAIL" end)  \(.key)"' <<<"$out"
	jq -e 'all(.[]; . == true)' <<<"$out" >/dev/null
	;;
snapshot)
	nix eval --impure --json -f tests/snapshot.nix | jq -S . >"${2:?usage: check.sh snapshot OUT.json}"
	;;
*)
	echo "usage: $0 integration | snapshot OUT.json" >&2
	exit 2
	;;
esac

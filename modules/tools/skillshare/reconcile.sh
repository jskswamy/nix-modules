#!/usr/bin/env bash
# Reconciles mutable Skillshare state with Home Manager's declarations.
#
#   reconcile.sh SKILLSHARE DECLARATIONS.json [--no-sync]
#
# DECLARATIONS.json holds lists under targets, skills, plugins, mcp and
# hooks; `excludes`, a map of target to skill exclude patterns; and
# `agents`, the agent CLIs plugin sync drives. Each list entry is
# {name, args, dirs?}: `args` is the Skillshare CLI
# call that adds it, run only when `name` is absent from that kind's JSON
# listing, after creating `dirs`. Present entries are never touched, so
# explicit `skillshare update` results survive. A failed add only warns;
# nothing is ever removed. Sync failures make the exit status nonzero,
# but only after every step has been attempted.
set -uo pipefail

ss=$1 decl=$2 mode=${3:-sync}
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/skillshare/config.yaml"
status=0

warn() { echo "skillshare: warning: $*" >&2; }

# Skillshare writes resolved versions and bindings back into config.yaml,
# so it must stay a regular file that Skillshare itself created.
if [[ ! -e $cfg ]]; then
	"$ss" init --no-copy --no-git --no-skill --no-targets >/dev/null ||
		{
			warn "init failed; nothing reconciled"
			exit 1
		}
fi

# ensure KIND JQ_FILTER LIST_CMD...
# Filters treat null or a missing key as an empty listing, so the first
# entry of a kind is still added; only non-JSON output skips the kind.
ensure() {
	local kind=$1 filter=$2 out existing entry name
	shift 2
	# Exit status is ignored: `mcp check` fails whenever a server has
	# findings, yet still prints the full listing.
	out=$("$@" --json 2>/dev/null)
	if [[ -z $out ]] || ! existing=$(jq -r "$filter" <<<"$out"); then
		warn "could not list $kind; skipped adding any"
		return
	fi
	while IFS= read -r entry; do
		name=$(jq -r .name <<<"$entry")
		grep -qxF -- "$name" <<<"$existing" && continue
		local dirs=() args=()
		mapfile -t dirs < <(jq -r '.dirs // [] | .[]' <<<"$entry")
		mapfile -t args < <(jq -r '.args[]' <<<"$entry")
		((${#dirs[@]})) && mkdir -p "${dirs[@]}"
		"$ss" "${args[@]}" </dev/null >/dev/null || warn "could not add $kind $name; existing state kept"
	done < <(jq -c --arg k "$kind" '.[$k] // [] | .[]' "$decl")
}

ensure targets '(.targets // [])[].name' "$ss" target list

# Missing excludes go in one call per target; each call costs a second or
# more, and there are dozens of patterns.
if ! out=$("$ss" target list --json 2>/dev/null) || [[ -z $out ]] || ! jq . >/dev/null 2>&1 <<<"$out"; then
	warn "could not list targets; skipped adding excludes"
else
	while IFS= read -r line; do
		mapfile -t missing < <(jq -r '.[]' <<<"$line")
		t=${missing[0]} args=()
		for p in "${missing[@]:1}"; do args+=(--add-exclude "$p"); done
		"$ss" target "$t" "${args[@]}" </dev/null >/dev/null || warn "could not add excludes to target $t; existing state kept"
	done < <(jq -c --argjson cur "$out" '.excludes // {} | to_entries[]
		| .key as $t
		| (.value - ([($cur.targets // [])[] | select(.name == $t) | .exclude // []] | add // []))
		| select(length > 0) | [$t] + .' "$decl")
fi
ensure skills '(. // [])[].name' "$ss" list
ensure plugins '(.packages // {}) | keys[]' "$ss" plugin list
ensure mcp '(.servers // [])[].name' "$ss" mcp check --no-dns
ensure hooks '(.source.entries // {}) | keys[]' "$ss" hooks list

if [[ $mode != --no-sync ]]; then
	# A declared hook owns its Agent entries: an identical hook another tool
	# wrote (Aide's RTK hook) is a conflict that blocks every hook write.
	# --replace takes over only that entry's duplicates.
	while IFS= read -r name; do
		"$ss" hooks sync "$name" --replace </dev/null >/dev/null || {
			warn "could not take over agent entries for hook $name"
			status=1
		}
	done < <(jq -r '.hooks // [] | .[].name' "$decl")
	"$ss" sync --all || {
		warn "sync --all failed"
		status=1
	}
	# Plugin sync installs through each agent's own CLI.
	while IFS= read -r agent; do
		command -v "$agent" >/dev/null || warn "plugin sync needs \`$agent\` on PATH; its plugins stay pending"
	done < <(jq -r '.agents // [] | .[]' "$decl")
	"$ss" sync plugins || {
		warn "sync plugins failed"
		status=1
	}
fi
exit "$status"

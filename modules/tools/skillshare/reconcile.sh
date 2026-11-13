#!/usr/bin/env bash
# Reconciles mutable Skillshare state with Home Manager's declarations.
#
#   reconcile.sh SKILLSHARE DECLARATIONS.json [--no-sync] [--update]
#
# --update updates plugins and standalone skills whatever the
# updateOnActivation policy says; `skillshare-update` runs it on demand.
#
# DECLARATIONS.json holds lists under targets, skills, plugins, mcp and
# hooks; `excludes`, a map of target to skill exclude patterns; and
# `agents`, the agent CLIs plugin sync drives. Each list entry is
# {name, args, dirs?}: `args` is the Skillshare CLI
# call that adds it, run only when `name` is absent from that kind's JSON
# listing, after creating `dirs`. Existing plugins gain missing bindings
# from their saved source/ref; upstream updates require `updateOnActivation`.
# A failed add only warns;
# nothing is explicitly removed. Update/sync failures make the exit status nonzero,
# but only after every step has been attempted.
set -uo pipefail

ss=$1 decl=$2
shift 2
sync=1 update=0
for arg; do
	case $arg in
	--no-sync) sync=0 ;;
	--update) update=1 ;;
	*)
		echo "skillshare: unknown option $arg" >&2
		exit 2
		;;
	esac
done
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/skillshare/config.yaml"
status=0

warn() { echo "skillshare: warning: $*" >&2; }
say() { echo "skillshare: $*"; }

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
	out=$("$@" --json 2>/dev/null </dev/null)
	if [[ -z $out ]] || ! existing=$(jq -r "$filter" <<<"$out"); then
		warn "could not list $kind; skipped adding any"
		return
	fi
	local todo=() n=0 total
	while IFS= read -r entry; do
		name=$(jq -r .name <<<"$entry")
		if grep -qxF -- "$name" <<<"$existing"; then
			[[ $kind == plugins ]] || continue
			# Add only new targets, keeping explicit updates and disabled bindings.
			entry=$(jq -c --argjson cur "$out" '
				. as $e | $cur.packages[.name] as $p
				| [.args | to_entries[] | select(.value == "--target")
					| $e.args[.key + 1] as $t
					| select(($p.bindings // {} | has($t)) | not) | $t] as $missing
				| select(($missing | length) > 0)
				| select(($p.source // "") != "")
				| .args = (["plugin", "add", $p.source, "--plugin", ($p.plugin // .name), "--name", .name]
					+ (if ($p.sourceRef // "") == "" then [] else ["--source-ref", $p.sourceRef] end)
					+ ($missing | map(["--target", .]) | add) + ["--json"])
			' <<<"$entry") || {
				warn "could not read plugin bindings for $name"
				continue
			}
			[[ -n $entry ]] || continue
		fi
		todo+=("$entry")
	done < <(jq -c --arg k "$kind" '.[$k] // [] | .[]' "$decl")
	total=${#todo[@]}
	((total)) && say "adding $total missing $kind"
	for entry in "${todo[@]}"; do
		name=$(jq -r .name <<<"$entry")
		n=$((n + 1))
		say "[$n/$total] $kind: $name"
		local dirs=() args=()
		mapfile -t dirs < <(jq -r '.dirs // [] | .[]' <<<"$entry")
		mapfile -t args < <(jq -r '.args[]' <<<"$entry")
		((${#dirs[@]})) && mkdir -p "${dirs[@]}"
		if [[ $kind == skills ]]; then
			[[ -d ${cfg%/config.yaml}/skills/$name ]] && chmod -R u+w "${cfg%/config.yaml}/skills/$name"
			for i in "${!args[@]}"; do
				if [[ -d ${args[i]} && ! -w ${args[i]} ]]; then
					local stage="${cfg%/config.yaml}/.nix-sources/$name"
					rm -rf "$stage" && mkdir -p "$(dirname "$stage")"
					cp -R "${args[i]}" "$stage" && chmod -R u+w "$stage"
					args[i]=$stage
				fi
			done
		fi
		"$ss" "${args[@]}" </dev/null || warn "could not add $kind $name; existing state kept"
	done
}

# OpenCode itself and Aide write `opencode.jsonc`; Skillshare creates
# `opencode.json` only when `opencode.jsonc` is absent. Seed `opencode.jsonc`
# in empty OpenCode config directories before Skillshare binds or syncs.
mapfile -t opencode_dirs < <(jq -r '.opencodeConfigDirs // [] | .[]' "$decl")
for dir in "${opencode_dirs[@]}"; do
	mkdir -p "$dir"
	[[ -e $dir/opencode.jsonc || -e $dir/opencode.json ]] || printf '{}\n' >"$dir/opencode.jsonc"
done

ensure targets '(.targets // [])[].name' "$ss" target list

# Missing excludes go in one call per target; each call costs a second or
# more, and there are dozens of patterns.
say "checking target excludes"
if ! out=$("$ss" target list --json 2>/dev/null </dev/null) || [[ -z $out ]] || ! jq . >/dev/null 2>&1 <<<"$out"; then
	warn "could not list targets; skipped adding excludes"
else
	while IFS= read -r line; do
		mapfile -t missing < <(jq -r '.[]' <<<"$line")
		t=${missing[0]} args=()
		for p in "${missing[@]:1}"; do args+=(--add-exclude "$p"); done
		"$ss" target "$t" "${args[@]}" </dev/null || warn "could not add excludes to target $t; existing state kept"
	done < <(jq -c --argjson cur "$out" '.excludes // {} | to_entries[]
		| .key as $t
		| (.value - ([($cur.targets // [])[] | select(.name == $t) | .exclude // []] | add // []))
		| select(length > 0) | [$t] + .' "$decl")
fi
ensure skills '(. // [])[].name' "$ss" list
ensure plugins '(.packages // {}) | keys[]' "$ss" plugin list
ensure mcp '(.servers // [])[].name' "$ss" mcp check --no-dns
ensure hooks '(.source.entries // {}) | keys[]' "$ss" hooks list

if ((update)) || jq -e '.updateOnActivation == true' "$decl" >/dev/null; then
	say "updating managed plugins"
	"$ss" plugin update --all --global --json </dev/null || {
		warn "plugin update failed"
		status=1
	}
	say "updating standalone skills"
	"$ss" update --all --global --json </dev/null || {
		warn "skill update failed"
		status=1
	}
fi

if ((sync)); then
	# A declared hook owns its Agent entries: an identical hook another tool
	# wrote (Aide's RTK hook) is a conflict that blocks every hook write.
	# --replace takes over only that entry's duplicates.
	while IFS= read -r name; do
		"$ss" hooks sync "$name" --replace </dev/null || {
			warn "could not take over agent entries for hook $name"
			status=1
		}
	done < <(jq -r '.hooks // [] | .[].name' "$decl")
	# Remove stub skill directories written imperatively by `rex skill setup`
	# so `sync --all` can replace them with Skillshare symlinks.
	if jq -e '(.skills // []) | any(.name == "rex")' "$decl" >/dev/null; then
		while IFS= read -r dir; do
			if [[ -d $dir/rex && ! -L $dir/rex ]] && grep -q '^  rex-stub:' "$dir/rex/SKILL.md" 2>/dev/null; then
				rm -rf "$dir/rex"
			fi
		done < <({
			printf '%s\n' "$HOME/.agents/skills"
			jq -r '.targets // [] | .[].dirs // [] | .[] | if endswith("/skills") then . else . + "/skills" end' "$decl"
		})
	fi
	say "syncing resources to targets"
	"$ss" sync --all </dev/null || {
		warn "sync --all failed"
		status=1
	}
	# Plugin sync installs through each agent's own CLI.
	while IFS= read -r agent; do
		command -v "$agent" >/dev/null || warn "plugin sync needs \`$agent\` on PATH; its plugins stay pending"
	done < <(jq -r '.agents // [] | .[]' "$decl")
	say "syncing plugins; each agent CLI installs them, this can take several minutes"
	"$ss" sync plugins </dev/null || {
		warn "sync plugins failed"
		status=1
	}
fi

# Skillshare registers OpenCode plugins as a file URL of index.js. OpenCode V2
# skips that and loads only a directory, so the plugin's skills never appear.
# Repair after sync, and also when sync is skipped: a previous registration
# still needs the directory. Skillshare's file URL stays; it is the identity
# the next sync matches.
if ((${#opencode_dirs[@]})); then
	say "registering OpenCode plugin directories"
	"${PYTHON:-python3}" "$(dirname "$0")/opencode-plugins.py" "${opencode_dirs[@]}" || {
		warn "could not register OpenCode plugin directories"
		status=1
	}
fi
exit "$status"

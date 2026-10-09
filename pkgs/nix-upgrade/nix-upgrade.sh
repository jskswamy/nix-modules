#!/usr/bin/env bash
# pkgs/nix-upgrade/nix-upgrade.sh
#
# Harness-agnostic: every subcommand here is a plain shell invocation a
# human or any coding agent can run directly. No step requires model
# judgment. NIX_UPGRADE_INTROSPECT_NIX is set by the Nix wrapper
# (../nix-upgrade.nix) to the store path of introspect.nix.
set -euo pipefail

usage() {
	cat <<'USAGE'
usage: nix-upgrade discover [--json]
       nix-upgrade apply <name>
       nix-upgrade [--all | --check-only]
USAGE
}

repo_root() {
	git rev-parse --show-toplevel
}

current_system() {
	nix eval --impure --raw --expr 'builtins.currentSystem'
}

# shellcheck disable=SC2154  # exported by pkgs/nix-upgrade.nix
introspect_overlay_packages() {
	local root="$1" system="$2"
	nix eval --impure --json --expr \
		"import ${NIX_UPGRADE_INTROSPECT_NIX} { flakePath = \"${root}\"; system = \"${system}\"; }"
}

latest_github_release() {
	local owner="$1" repo="$2"
	gh release view --repo "${owner}/${repo}" --json tagName -q '.tagName' 2>/dev/null | sed 's/^v//' || true
}

discover_overlay_packages() {
	local root="$1" system="$2" entries entry name owner repo version latest up_to_date
	entries=$(introspect_overlay_packages "$root" "$system")
	jq -c '.[]' <<<"$entries" | while read -r entry; do
		name=$(jq -r '.name' <<<"$entry")
		owner=$(jq -r '.owner' <<<"$entry")
		repo=$(jq -r '.repo' <<<"$entry")
		version=$(jq -r '.version' <<<"$entry")
		[[ $owner == "null" || $repo == "null" ]] && continue
		latest=$(latest_github_release "$owner" "$repo")
		[[ -z $latest ]] && continue
		up_to_date=$([[ $version == "$latest" ]] && echo true || echo false)
		jq -n --arg name "$name" --arg current "$version" --arg latest "$latest" --argjson upToDate "$up_to_date" \
			'{name: $name, kind: "overlay", current: $current, latest: $latest, upToDate: $upToDate}'
	done
}

discover_flake_inputs() {
	local root="$1" meta name owner repo rev latest up_to_date
	meta=$(nix flake metadata "$root" --json)
	jq -r '.locks.nodes | to_entries[] | select(.value.locked.type == "github") | .key' <<<"$meta" |
		while read -r name; do
			[[ $name == "root" ]] && continue
			owner=$(jq -r --arg n "$name" '.locks.nodes[$n].locked.owner' <<<"$meta")
			repo=$(jq -r --arg n "$name" '.locks.nodes[$n].locked.repo' <<<"$meta")
			rev=$(jq -r --arg n "$name" '.locks.nodes[$n].locked.rev' <<<"$meta")
			latest=$(git ls-remote "https://github.com/${owner}/${repo}" HEAD 2>/dev/null | cut -f1 || true)
			[[ -z $latest ]] && continue
			up_to_date=$([[ $rev == "$latest" ]] && echo true || echo false)
			jq -n --arg name "$name" --arg current "${rev:0:8}" --arg latest "${latest:0:8}" --argjson upToDate "$up_to_date" \
				'{name: $name, kind: "flake-input", current: $current, latest: $latest, upToDate: $upToDate}'
		done
}

cmd_discover() {
	local json_only=false root system rows
	for arg in "$@"; do
		[[ $arg == "--json" ]] && json_only=true
	done
	root=$(repo_root)
	system=$(current_system)
	rows=$( (
		discover_overlay_packages "$root" "$system"
		discover_flake_inputs "$root"
	) | jq -s '.')
	if $json_only; then
		echo "$rows"
	else
		echo "$rows" | jq -r '["NAME","KIND","CURRENT","LATEST","UP-TO-DATE"], (.[] | [.name,.kind,.current,.latest,(.upToDate|tostring)]) | @tsv' | column -t
	fi
}

package_version() {
	local root="$1" system="$2" name="$3"
	nix eval --impure --raw --expr \
		"(builtins.getFlake \"path:${root}\").packages.${system}.${name}.version" 2>/dev/null || echo ""
}

package_platforms() {
	local root="$1" system="$2" name="$3"
	nix eval --impure --json --expr \
		"(builtins.getFlake \"path:${root}\").packages.${system}.${name}.meta.platforms or [\"${system}\"]"
}

cmd_apply_overlay() {
	local root="$1" name="$2" system="$3" old_version new_version platform success error
	old_version=$(package_version "$root" "$system" "$name")
	success=true
	error=""
	while read -r platform; do
		local build_flag=()
		[[ $platform == "$system" ]] && build_flag=(--build)
		if ! (cd "$root" && nix-update --flake "${build_flag[@]}" --system "$platform" "$name"); then
			success=false
			error="nix-update failed for ${platform}"
		fi
	done < <(package_platforms "$root" "$system" "$name" | jq -r '.[]')
	new_version=$(package_version "$root" "$system" "$name")
	[[ -z $new_version ]] && new_version="$old_version"
	if $success; then
		if ! nix build "${root}#packages.${system}.${name}" --no-link; then
			success=false
			error="build verification failed"
		fi
	fi
	jq -n --arg name "$name" --arg old "$old_version" --arg new "$new_version" \
		--argjson success "$success" --arg error "$error" \
		'{name: $name, oldVersion: $old, newVersion: $new, success: $success, error: (if $error == "" then null else $error end)}'
}

locked_rev() {
	local root="$1" name="$2"
	nix flake metadata "$root" --json 2>/dev/null | jq -r --arg n "$name" '.locks.nodes[$n].locked.rev' || echo ""
}

cmd_apply_flake_input() {
	local root="$1" name="$2" old_rev new_rev success error
	old_rev=$(locked_rev "$root" "$name")
	success=true
	error=""
	if ! nix flake lock "$root" --update-input "$name"; then
		success=false
		error="nix flake lock failed for ${name}"
	fi
	new_rev=$(locked_rev "$root" "$name")
	if $success && ! nix flake check "$root"; then
		success=false
		error="build verification failed"
	fi
	jq -n --arg name "$name" --arg old "${old_rev:0:8}" --arg new "${new_rev:0:8}" \
		--argjson success "$success" --arg error "$error" \
		'{name: $name, oldVersion: $old, newVersion: $new, success: $success, error: (if $error == "" then null else $error end)}'
}

cmd_apply() {
	local name="$1" root system is_package
	root=$(repo_root)
	system=$(current_system)
	if nix eval --impure --json --expr "(builtins.getFlake \"path:${root}\").packages.${system} or {}" |
		jq -e --arg n "$name" 'has($n)' >/dev/null 2>&1; then
		is_package=true
	else
		is_package=false
	fi
	if $is_package; then
		cmd_apply_overlay "$root" "$name" "$system"
	else
		cmd_apply_flake_input "$root" "$name"
	fi
}

cmd_all_or_check() {
	local mode="$1" table name
	table=$(cmd_discover --json)
	jq -r '.[] | select(.upToDate == false) | .name' <<<"$table" | while read -r name; do
		if [[ $mode == "--check-only" ]]; then
			echo "outdated: ${name}"
			continue
		fi
		if gum confirm "Upgrade ${name}?"; then
			cmd_apply "$name"
		fi
	done
}

main() {
	case "${1:-}" in
	discover)
		shift
		cmd_discover "$@"
		;;
	apply)
		shift
		[[ $# -eq 1 ]] || {
			usage
			exit 2
		}
		cmd_apply "$1"
		;;
	--all | --check-only)
		cmd_all_or_check "$1"
		;;
	-h | --help | "")
		usage
		;;
	*)
		usage
		exit 2
		;;
	esac
}

main "$@"

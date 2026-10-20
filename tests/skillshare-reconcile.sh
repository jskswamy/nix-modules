#!/usr/bin/env bash
# Runs modules/tools/skillshare/reconcile.sh against a fake skillshare that
# records its calls and answers list commands from a state directory, then
# asserts the reconcile contract: add only what is missing, always sync,
# warn (never delete) when an add fails.
# shellcheck disable=SC2016,SC2034,SC2329 # assertions are eval'd strings
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config"
export FAKE_LOG="$tmp/calls" FAKE_STATE="$tmp/state" FAKE_FAIL="$tmp/fail"
mkdir -p "$HOME" "$FAKE_STATE"
: >"$FAKE_FAIL"

fake="$tmp/skillshare"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
names() { jq -R . "$FAKE_STATE/$1" 2>/dev/null | jq -s .; }
fail() { grep -qx "$1" "$FAKE_FAIL"; }
cfg="$XDG_CONFIG_HOME/skillshare/config.yaml"
# FAKE_EMPTY=null|nokey prints that instead of an empty listing.
if [[ $* == *" --json" && ${FAKE_EMPTY:-} && ! -s $FAKE_STATE/$(case $1 in list) echo skill ;; hooks) echo hook ;; *) echo "$1" ;; esac) ]]; then
	case $FAKE_EMPTY in null) echo null ;; nokey) echo '{}' ;; esac
	exit 0
fi
case "$*" in
"init "*) mkdir -p "${cfg%/*}" && echo "targets: {}" >"$cfg" ;;
"target list --json")
	names filter >"$FAKE_STATE/.filters.json"
	names target | jq --slurpfile f "$FAKE_STATE/.filters.json" \
		'{targets: map(. as $t | {name: ., exclude: [$f[0][] | select(startswith($t + ":")) | ltrimstr($t + ":")]})}'
	;;
"list --json") names skill | jq 'map({name: .})' ;;
"plugin list --json")
	touch "$FAKE_STATE/binding"
	names plugin | jq --rawfile bindings "$FAKE_STATE/binding" '
		map(. as $name | {key: ., value: {
			source: (env.FAKE_PLUGIN_SOURCE // ("org/" + $name)), plugin: $name,
			sourceRef: (env.FAKE_SOURCE_REF // ""),
			bindings: ($bindings | split("\n") | map(select(startswith($name + ":")) | ltrimstr($name + ":")
				| {key: ., value: {disabled: (. == env.FAKE_DISABLED_TARGET)}}) | from_entries)
		}}) | {packages: from_entries}'
	;;
"mcp check --no-dns --json") names mcp | jq '{servers: map({name: .})}' ;;
"hooks list --json") names hook | jq 'map({key: ., value: {}}) | {source: {entries: from_entries}}' ;;
"target add "*) fail "$3" && exit 1; echo "$3" >>"$FAKE_STATE/target" ;;
"target "*" --add-exclude "*)
	fail "$2" && exit 1
	t=$2
	shift 2
	while (($#)); do echo "$t:$2" >>"$FAKE_STATE/filter" && shift 2; done
	;;
"install "*) fail "$2" && exit 1; basename "$2" >>"$FAKE_STATE/skill" ;;
"plugin add "*)
	fail "$3" && exit 1
	name=$(basename "$3") targets=()
	shift 3
	while (($#)); do
		case $1 in
		--plugin | --name) name=$2; shift 2 ;;
		--target) targets+=("$2"); shift 2 ;;
		--source-ref) shift 2 ;;
		*) shift ;;
		esac
	done
	for target in "${targets[@]}"; do fail "$name:$target" && exit 1; done
	grep -qx "$name" "$FAKE_STATE/plugin" 2>/dev/null || echo "$name" >>"$FAKE_STATE/plugin"
	for target in "${targets[@]}"; do echo "$name:$target" >>"$FAKE_STATE/binding"; done
	;;
"mcp add "*) fail "$3" && exit 1; echo "$3" >>"$FAKE_STATE/mcp" ;;
"hooks add "*) fail "$3" && exit 1; echo "$3" >>"$FAKE_STATE/hook" ;;
"sync --all" | "sync plugins") fail sync && exit 1; exit 0 ;;
"hooks sync "*" --replace") fail hooksync && exit 1; exit 0 ;;
*) echo "fake skillshare: unexpected: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$fake"

decl="$tmp/decl.json"
cat >"$decl" <<EOF
{
  "targets": [
    {"name": "claude", "args": ["target", "add", "claude", "$HOME/.claude/skills"], "dirs": ["$HOME/.claude/skills"]},
    {"name": "claude-extra", "args": ["target", "add", "claude-extra", "--agent", "claude", "--config-dir", "$HOME/.claude-extra"], "dirs": ["$HOME/.claude-extra"]}
  ],
  "agents": ["bash", "no-such-agent-cli"],
  "excludes": {"claude": ["foo", "bar"]},
  "skills": [{"name": "foo", "args": ["install", "org/foo", "--all", "-y"]}],
  "plugins": [{"name": "demo", "args": ["plugin", "add", "org/demo", "--json"]}],
  "mcp": [{"name": "time", "args": ["mcp", "add", "time", "--target", "claude", "--", "time-server"]}],
  "hooks": [{"name": "rtk", "args": ["hooks", "add", "rtk", "--file", "/dev/null"]}]
}
EOF

fails=0
check() {
	if eval "$2"; then echo "PASS  $1"; else
		echo "FAIL  $1"
		fails=1
	fi
}
run() {
	: >"$FAKE_LOG"
	set +e
	bash modules/tools/skillshare/reconcile.sh "$fake" "$decl" "$@" 2>"$tmp/err"
	rc=$?
	set -e
}
adds() { grep -cE '^(target add|target .* --add-exclude|install|plugin add|mcp add|hooks add) ' "$FAKE_LOG" || true; }
synced() { grep -qx 'sync --all' "$FAKE_LOG" && grep -qx 'sync plugins' "$FAKE_LOG"; }

run
check "first run initialises the mutable config" '[[ -f $XDG_CONFIG_HOME/skillshare/config.yaml && ! -L $XDG_CONFIG_HOME/skillshare/config.yaml ]]'
check "first run adds every missing entry" '[[ $(adds) == 7 ]]'
check "first run creates target directories" '[[ -d $HOME/.claude/skills && -d $HOME/.claude-extra ]]'
check "first run syncs resources then plugins" 'synced && [[ $(grep -n "sync" "$FAKE_LOG" | tail -1) == *"sync plugins" ]]'
check "first run succeeds" '[[ $rc == 0 ]]'
check "first run adds every exclude of a target in one call" 'grep -qx "target claude --add-exclude foo --add-exclude bar" "$FAKE_LOG"'
check "first run adds excludes after targets" '[[ $(grep -n "" "$FAKE_LOG" | grep -m1 -e "--add-exclude" | cut -d: -f1) -gt $(grep -n "^target add" "$FAKE_LOG" | tail -1 | cut -d: -f1) ]]'
check "declared hooks take over their agent entries before sync" '[[ $(grep -n -e "^hooks sync rtk --replace$" -e "^sync --all$" "$FAKE_LOG" | cut -d: -f2- | tr "\n" ,) == "hooks sync rtk --replace,sync --all," ]]'
check "missing agent CLIs are named before plugin sync" 'grep -q "no-such-agent-cli" "$tmp/err" && ! grep -q "skillshare: warning: .*bash" "$tmp/err"'

echo "user: edited" >"$XDG_CONFIG_HOME/skillshare/config.yaml"
run
check "second run adds nothing" '[[ $(adds) == 0 ]]'
check "second run does not re-init" '! grep -q "^init" "$FAKE_LOG"'
check "second run still syncs" 'synced'
check "second run keeps the mutable config" '[[ $(cat "$XDG_CONFIG_HOME/skillshare/config.yaml") == "user: edited" ]]'

sed -i.bak '/^claude:foo$/d' "$FAKE_STATE/filter"
run
check "a missing exclude is added alone" '[[ $(adds) == 1 ]] && grep -qx "target claude --add-exclude foo" "$FAKE_LOG"'

sed -i.bak '/^demo$/d' "$FAKE_STATE/plugin"
echo "org/demo" >"$FAKE_FAIL"
before=$(cat "$XDG_CONFIG_HOME/skillshare/config.yaml")
run
check "add failure warns" 'grep -q "warning" "$tmp/err"'
check "add failure leaves config untouched" '[[ $(cat "$XDG_CONFIG_HOME/skillshare/config.yaml") == "$before" ]]'
check "add failure still syncs and succeeds" 'synced && [[ $rc == 0 ]]'

echo "sync" >"$FAKE_FAIL"
run
check "sync failure attempts both syncs and fails" 'synced && [[ $rc != 0 ]]'

echo "hooksync" >"$FAKE_FAIL"
run
check "hook takeover failure warns, still syncs and fails" 'grep -q "warning: .*rtk" "$tmp/err" && synced && [[ $rc != 0 ]]'

: >"$FAKE_FAIL"
run --no-sync
check "--no-sync skips syncing" '! grep -q -e "^sync" -e "^hooks sync" "$FAKE_LOG" && [[ $rc == 0 ]]'

# Fresh installs: real 0.25.12 prints keyed empty listings
# ({"targets":[]}, [], {"packages":{}}, {"servers":[]}, {"source":{"entries":{}}}),
# but a null or keyless listing must not stop the first add either.
for shape in keyed null nokey; do
	rm -rf "$FAKE_STATE" "$XDG_CONFIG_HOME/skillshare" && mkdir -p "$FAKE_STATE"
	if [[ $shape == keyed ]]; then unset FAKE_EMPTY; else export FAKE_EMPTY=$shape; fi
	run
	check "$shape empty listing still adds every entry" '[[ $(adds) == 7 ]] && ! grep -q "could not list" "$tmp/err"'
done
unset FAKE_EMPTY

# Adding a new profile must bind an already-managed plugin without touching
# existing (even disabled) bindings or changing the user's source/ref.
jq '.plugins[0].args += ["--target", "claude", "--target", "codex"]' "$decl" >"$tmp/expanded.json"
mv "$tmp/expanded.json" "$decl"
echo demo >"$FAKE_STATE/plugin"
printf 'demo:claude\ndemo:pi\n' >"$FAKE_STATE/binding"
export FAKE_PLUGIN_SOURCE=org/custom FAKE_SOURCE_REF=stable FAKE_DISABLED_TARGET=claude
run --no-sync
check "existing plugin gains only the missing binding from its saved source" 'grep -qx "plugin add org/custom --plugin demo --name demo --source-ref stable --target codex --json" "$FAKE_LOG" && grep -qx "demo:codex" "$FAKE_STATE/binding"'
check "existing and undeclared plugin bindings are preserved" '[[ $(wc -l <"$FAKE_STATE/binding" | tr -d " ") == 3 ]] && grep -qx "demo:claude" "$FAKE_STATE/binding" && grep -qx "demo:pi" "$FAKE_STATE/binding"'
run
check "complete plugin bindings are not re-added" '! grep -q "^plugin add " "$FAKE_LOG" && synced'
sed -i.bak '/^demo:codex$/d' "$FAKE_STATE/binding"
echo "demo:codex" >"$FAKE_FAIL"
run
check "binding failure warns and still syncs without removing existing bindings" 'grep -q "warning.*demo" "$tmp/err" && synced && grep -qx "demo:claude" "$FAKE_STATE/binding" && ! grep -qx "demo:codex" "$FAKE_STATE/binding"'
: >"$FAKE_FAIL"
run
check "failed plugin bindings are retried next time" 'grep -qx "demo:codex" "$FAKE_STATE/binding"'

exit "$fails"

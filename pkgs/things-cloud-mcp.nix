# Things Cloud MCP - MCP server for Things 3 task management via Things Cloud
# Not available in nixpkgs, so we build from source
# https://github.com/wbopan/things-cloud-mcp
#
# TEMPORARY FORK PIN: upstream's isUntitledTask() hides any task with a
# blank title from every query, including tasks that have a real note
# (e.g. a link saved via share extension with no title ever typed in) —
# making them impossible to find and retitle. Fixed on our fork's main
# and submitted upstream as https://github.com/wbopan/things-cloud-mcp/pull/20.
# Revert to upstream owner/rev once that merges and cuts a release.
#
# 2026-08-25: bumped to fork main HEAD (was 0de5d57b, v1.3.2) to pick up
# "fix: harden Things Cloud sync and writes" (9d11137) — rewrites
# things-cloud-sdk/histories.go sync/write handling, suspected cause of
# stale reads (frozen serverIndex) seen after restoring this server.
#
# 2026-08-26: bumped again (was da535f0) for our own
# "fix: support Task7 kind and skip unknown items during rebuild"
# (2d5ba56) — Things 3.23 started writing repeating tasks as a new
# Task7 item kind, which aborted every state rebuild (every tool
# call) the moment the account had one repeating task. Also filed
# upstream: https://github.com/wbopan/things-cloud-mcp/pull/24.
_: prev: {
  things-cloud-mcp = prev.buildGoModule rec {
    pname = "things-cloud-mcp";
    version = "1.4.3-unstable-2026-08-26";

    src = prev.fetchFromGitHub {
      owner = "jskswamy";
      repo = "things-cloud-mcp";
      rev = "2d5ba562cded57955e0e61361207465b682715e5";
      hash = "sha256-W5K9Nkzjc7k2EpUIO7rYivjWAPDDovXrUedW+5aNY+A=";
    };

    vendorHash = "sha256-UI5nEO4GpruVg2CoOUmUKFKL7fbTg/2ZIqSlf/6YL2k=";

    # things-cloud-sdk/ is a separate Go module (its own go.mod), pulled in
    # via a local `replace` directive in go.mod — not a subpackage of the
    # main module. Restrict the build to the root package only, or
    # buildGoModule errors trying to build it as `things-cloud-mcp/things-cloud-sdk`.
    subPackages = ["."];

    # Upstream hardcodes `addr := ":" + port` in main.go (binds every
    # interface). There is no --host flag or env var to restrict this.
    # Patch it to loopback-only so credentials/traffic never leave the
    # machine, matching the design's security guarantee.
    postPatch = ''
      substituteInPlace main.go \
        --replace-fail 'addr := ":" + port' 'addr := "127.0.0.1:" + port'
    '';

    meta = with prev.lib; {
      description = "MCP server for Things Cloud task management";
      homepage = "https://github.com/wbopan/things-cloud-mcp";
      mainProgram = "things-cloud-mcp";
      platforms = platforms.darwin;
    };
  };
}

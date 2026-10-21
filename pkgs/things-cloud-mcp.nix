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
# 2026-10-21: bumped to fork main HEAD (b03d51d) — includes upstream
# maintainer's fix/task7-and-recurring-projection (d0f1dc1) which adds Task7
# support and occurrence projection for recurring to-dos, plus PR #33 (Task2/Tag2),
# PR #34 (Mail to Things Command queue items), and our PR #20 (untitled notes).
_: prev: {
  things-cloud-mcp = prev.buildGoModule rec {
    pname = "things-cloud-mcp";
    version = "1.4.4-unstable-2026-10-21";

    src = prev.fetchFromGitHub {
      owner = "jskswamy";
      repo = "things-cloud-mcp";
      rev = "b03d51daf6fcabbe620231ccec66bfe29f1b0d2d";
      hash = "sha256-KuDD97VISpniFFJPLZpICDDk7X6c3+CKGiSf/kc0nZM=";
    };

    vendorHash = "sha256-k2zliqA+7R4Vu/xzAo5kmhTFf/wf2QVw8ygUocZ1I4k=";

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

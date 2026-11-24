# Things Cloud MCP - MCP server for Things 3 task management via Things Cloud
# Not available in nixpkgs, so we build from source
# https://github.com/jskswamy/things-cloud-mcp
#
# This is a standalone Go project. It began as a fork of
# wbopan/things-cloud-mcp, which has since been rewritten as a TypeScript
# Cloudflare Worker and no longer ships a Go server, so there is no upstream
# to return to. Pin a release tag of the repository above.
#
# 1.5.0 carries the fixes the original project only made in its rewrite:
# valid identifiers for new items, positive sort indexes on edit, today in
# the system time zone, a resend after 409 OutdatedAncestor, recovery after
# an account reset, and a backoff when reads are throttled.
_: prev: {
  things-cloud-mcp = prev.buildGoModule rec {
    pname = "things-cloud-mcp";
    version = "1.5.0";

    src = prev.fetchFromGitHub {
      owner = "jskswamy";
      repo = "things-cloud-mcp";
      tag = "v${version}";
      hash = "sha256-wbWs0b9A95lBSWhkJ6iegKbM9iNGE5460p0cfWHywRY=";
    };

    vendorHash = "sha256-jnsDmi2wnOa6avPLm8Mc8ZIhncU/ABaxbO6AOH0PW3Q=";

    # things-cloud-sdk/ is a separate Go module (its own go.mod), pulled in
    # via a local `replace` directive in go.mod — not a subpackage of the
    # main module. Restrict the build to the root package only, or
    # buildGoModule errors trying to build it as `things-cloud-mcp/things-cloud-sdk`.
    subPackages = ["."];

    # main.go hardcodes `addr := ":" + port` (binds every
    # interface). There is no --host flag or env var to restrict this.
    # Patch it to loopback-only so credentials/traffic never leave the
    # machine, matching the design's security guarantee.
    postPatch = ''
      substituteInPlace main.go \
        --replace-fail 'addr := ":" + port' 'addr := "127.0.0.1:" + port'
    '';

    meta = with prev.lib; {
      description = "MCP server for Things Cloud task management";
      homepage = "https://github.com/jskswamy/things-cloud-mcp";
      mainProgram = "things-cloud-mcp";
      platforms = platforms.darwin;
    };
  };
}

# codebase-memory-mcp: C11 MCP server that indexes a codebase into a
# semantic graph (functions, classes, call chains, HTTP routes) for
# structural queries. Not available in nixpkgs; upstream ships its own
# flake too, but vendoring release binaries here keeps ownPkg's
# no-overlay-applied fallback working (see lib/default.nix) instead of
# threading a foreign flake input through this repo's own overlay.
#
# ponytail: the v0.11.0 `-ui` release asset is byte-identical to the
# non-UI one per platform (upstream release pipeline bug — --ui=true
# likely does nothing in this build). Packaged anyway since
# tools.codebase-memory-mcp.ui defaults to false; bump the pin once
# upstream actually ships a distinct UI build.
_final: prev: let
  version = "0.11.0";

  mkVariant = pname: sources: let
    src = sources.${prev.stdenv.hostPlatform.system} or (throw "codebase-memory-mcp overlay: no binary pinned for ${prev.stdenv.hostPlatform.system}");
  in
    prev.stdenv.mkDerivation {
      inherit pname version src;

      dontUnpack = true;
      dontFixup = prev.stdenv.hostPlatform.isDarwin;

      installPhase = ''
        install -Dm755 $src/codebase-memory-mcp $out/bin/codebase-memory-mcp
      '';

      meta = with prev.lib; {
        description = "Semantic code graph MCP server (tree-sitter + LSP) for AI coding agents";
        homepage = "https://github.com/DeusData/codebase-memory-mcp";
        license = licenses.mit;
        mainProgram = "codebase-memory-mcp";
        platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
      };
    };

  defaultSources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-darwin-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-084MgpeO01Htdp+BuMZqTGaCoge6Sk/K0wLSMThgWSE=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-darwin-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-kAmxuRdZyKjBt3ZsRbXkJpK5zXmFaZdj9HOPvpVkVOM=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-linux-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-FrNu5iGfO10bDh1c2h8UbMdK8TRISWd2iWqHhmpY/j0=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-linux-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-PstsadEMUNmZXVjAK1h1P0xd6ya3nBU1QuHFb/GsudY=";
    };
  };

  uiSources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-darwin-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-084MgpeO01Htdp+BuMZqTGaCoge6Sk/K0wLSMThgWSE=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-darwin-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-kAmxuRdZyKjBt3ZsRbXkJpK5zXmFaZdj9HOPvpVkVOM=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-linux-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-FrNu5iGfO10bDh1c2h8UbMdK8TRISWd2iWqHhmpY/j0=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-linux-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-PstsadEMUNmZXVjAK1h1P0xd6ya3nBU1QuHFb/GsudY=";
    };
  };
in {
  codebase-memory-mcp = mkVariant "codebase-memory-mcp" defaultSources;
  codebase-memory-mcp-ui = mkVariant "codebase-memory-mcp-ui" uiSources;
}

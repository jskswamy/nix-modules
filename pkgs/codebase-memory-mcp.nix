# codebase-memory-mcp: C11 MCP server that indexes a codebase into a
# semantic graph (functions, classes, call chains, HTTP routes) for
# structural queries. Not available in nixpkgs; upstream ships its own
# flake too, but vendoring release binaries here keeps ownPkg's
# no-overlay-applied fallback working (see lib/default.nix) instead of
# threading a foreign flake input through this repo's own overlay.
#
# ponytail: the v0.12.1 `-ui` release asset is byte-identical to the
# non-UI one per platform (upstream release pipeline bug — --ui=true
# likely does nothing in this build). Packaged anyway since
# tools.codebase-memory-mcp.ui defaults to false; bump the pin once
# upstream actually ships a distinct UI build.
_final: prev: let
  version = "0.12.1";

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
      hash = "sha256-+q0yIQvKWy9im/JtTpjhgrclX8w/fGMSRKan21aW87w=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-darwin-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-cad6KZJAQIyfz/JaCkH4h+H3pyMRr85JXvPgFbTaDJA=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-linux-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-JBRaiZZh7xJCHB9LMzyC/OPfdXrqy6fokKOx9L/sAag=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-linux-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-m+gt6lKHax/UtR31c4AerWmuCa8X2lgar1Obua1MoWU=";
    };
  };

  uiSources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-darwin-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-+q0yIQvKWy9im/JtTpjhgrclX8w/fGMSRKan21aW87w=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-darwin-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-cad6KZJAQIyfz/JaCkH4h+H3pyMRr85JXvPgFbTaDJA=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-linux-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-JBRaiZZh7xJCHB9LMzyC/OPfdXrqy6fokKOx9L/sAag=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-ui-linux-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-m+gt6lKHax/UtR31c4AerWmuCa8X2lgar1Obua1MoWU=";
    };
  };
in {
  codebase-memory-mcp = mkVariant "codebase-memory-mcp" defaultSources;
  codebase-memory-mcp-ui = mkVariant "codebase-memory-mcp-ui" uiSources;
}

# AgentGateway - MCP proxy, replaces 1mcp (see 2026-08-12-agentgateway-migration-handoff.md)
# Not available in nixpkgs (checked via `nix search nixpkgs agentgateway`, no results).
# Packaging the prebuilt release binary rather than building from source.
# ponytail: aarch64-darwin only, the sole platform that actually runs this
# (launchd.agents.agentgateway is Darwin-only). Add other platform hashes
# from https://github.com/agentgateway/agentgateway/releases when needed.
_final: prev: let
  agentgatewayVersion = "1.5.0";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/agentgateway/agentgateway/releases/download/v${agentgatewayVersion}/agentgateway-darwin-arm64";
      # executable = true flips fetchurl's outputHashMode to "recursive"
      # (NAR hash), not a flat file hash — this hash covers the NAR
      # serialization of the executable, not `sha256sum` of the raw bytes.
      hash = "sha256-bcCWsmr8yfPz7k47ycaj9iq2CeGnuwhkZYiex37iGsA=";
      executable = true;
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "agentgateway overlay: no binary pinned for ${prev.stdenv.hostPlatform.system}");
in {
  agentgateway = prev.stdenv.mkDerivation {
    pname = "agentgateway";
    version = agentgatewayVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src $out/bin/agentgateway
    '';

    meta = with prev.lib; {
      description = "Rust-based MCP/AI proxy (Linux Foundation)";
      homepage = "https://agentgateway.dev";
      mainProgram = "agentgateway";
      platforms = ["aarch64-darwin"];
    };
  };
}

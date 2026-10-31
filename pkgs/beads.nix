# Override beads to latest version using pre-built binaries
# This avoids needing a specific Go version to compile from source
_: prev: let
  beadsVersion = "1.3.2";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-EDEepqLGOxaLcJqATFv6ubze9QkfBfEsPlKi92Tjnig=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-AcIyg/HIewxPTNQG+jYlgdZ3M78q0+5cKZs9Q7CfUeU=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-zL7lc5CQFnT4cF4k/cuUh6qlub4PTR+nOUbrV2z9a7w=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-giRcd9TM5KMub82sOjQ0OzBK9IAYDzjLzIIQus4jYAI=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  beads = prev.stdenv.mkDerivation {
    pname = "beads";
    version = beadsVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/bd $out/bin/bd
    '';

    meta = with prev.lib; {
      description = "Lightweight memory system for AI coding agents with graph-based issue tracking";
      homepage = "https://github.com/gastownhall/beads";
      license = licenses.asl20;
      mainProgram = "bd";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

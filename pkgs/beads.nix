# Override beads to latest version using pre-built binaries
# This avoids needing a specific Go version to compile from source
_: prev: let
  beadsVersion = "1.3.4";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-YlqgQLi6Hm3NBxYJ3R5aKlmmgrefBkSmc4eSemwZFKM=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-+BT5yoXT+yneJCORV/EjfsoJjxAfRrMl3zORQgBJOGg=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-jHGQMoBjD3gJ9symB5uWOzTDFB+aF92wSTOmIvJHTXw=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-fPpSKw9dhYmB/7ixfQ2SogbZzvy+myI779+q+F0gU3A=";
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

# TALA - Advanced diagram layout engine for D2 (terrastruct, proprietary)
# Migrated off Homebrew: the tala formula lived in a third-party tap that
# nix-homebrew symlinks into /nix/store, which Homebrew 5.x (required for
# macOS 27) rejects with "requires formulae to be in a tap". Packaging the
# pre-built binary here sidesteps brew entirely. The tarball ships the
# d2plugin-tala binary that d2 discovers on PATH (set D2_LAYOUT=tala).
_final: prev: let
  talaVersion = "0.4.3";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/terrastruct/tala/releases/download/v${talaVersion}/tala-v${talaVersion}-macos-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-h+LPLAyEN8NBtYEXsz3I0zQaAR1kIsGvAtXU2SVkoUA=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/terrastruct/tala/releases/download/v${talaVersion}/tala-v${talaVersion}-macos-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-BFWcE0nsENJmY4/oevPe/msUPeE6ngl17JnjWo3DcaE=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/terrastruct/tala/releases/download/v${talaVersion}/tala-v${talaVersion}-linux-amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-Zq3X6HBQVktIupFMzwiAoKD1XyfbM59zEdgdBk4BWXY=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/terrastruct/tala/releases/download/v${talaVersion}/tala-v${talaVersion}-linux-arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-58Eq9TrFoh/pJcf5umkzOw8EjWXxBnq/O8lWNvRaiG4=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  tala = prev.stdenv.mkDerivation {
    pname = "tala";
    version = talaVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/tala-v${talaVersion}/bin/d2plugin-tala $out/bin/d2plugin-tala
      install -Dm644 $src/tala-v${talaVersion}/man/d2plugin-tala.1 $out/share/man/man1/d2plugin-tala.1
    '';

    meta = with prev.lib; {
      description = "Advanced diagram layout engine for D2";
      homepage = "https://github.com/terrastruct/TALA";
      license = licenses.unfree;
      mainProgram = "d2plugin-tala";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

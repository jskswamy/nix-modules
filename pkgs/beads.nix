# Override beads to latest version using pre-built binaries
# This avoids needing a specific Go version to compile from source
_: prev: let
  beadsVersion = "1.3.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-qsoepZ852VUNkdGfD6ag8SXKdz+nB0/1deSFIMSvutU=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-ZoBCrtSp3UzestuCZ+KWO72PojdJaeO/FRyJETadJB4=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-Ie9TD27mGQd3ctj5FsyDpUC0x2X5eaeNjffXqppQ19U=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-WCHyEIS+aHr52ItjH88EACMYnFIkxqBt/J+1OC7VWyE=";
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

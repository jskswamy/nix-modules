# Override beads to latest version using pre-built binaries
# This avoids needing a specific Go version to compile from source
_: prev: let
  beadsVersion = "1.1.2";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/steveyegge/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-8hawYfmcq1ZYFq09kKqc8/3I9vgv+CcFCWGCPbBsRbs=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/steveyegge/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-/XjjU3CtoJtKluV6/bUtECmiXUA4VSq9xormsffrt38=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/steveyegge/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-QUxIc1BRnBGIZ9sLsP5Dobx49x4krV+tLmed3G9h+7Q=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/steveyegge/beads/releases/download/v${beadsVersion}/beads_${beadsVersion}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-JGyantVQRvFNF3ygP7KA+GXYDYTT3CoH8e+fKi2qlzg=";
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
      homepage = "https://github.com/steveyegge/beads";
      license = licenses.asl20;
      mainProgram = "bd";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

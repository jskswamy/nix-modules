# Use upstream V2 binaries: nixpkgs still packages V1.
_final: prev: let
  version = "2.2.5";
  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      stripRoot = false;
      hash = "sha256-gjgkAGAdoibwX5NJgEJ1MnD8DgS7IWXLtZ54W+SjSMM=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64-baseline.zip";
      stripRoot = false;
      hash = "sha256-dVbc1i69vlcTdxefj4MzEXMSqD336OrBVPhPHCcmi4E=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-oS89/6bAJTn0FftPNCy1f4yzZ93vgnIYrE7U2I6y9+A=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-wPeb38pb23zRGCRTc3sFzDtuQcWvIBATg/NwqN1YFDE=";
    };
  };
in {
  opencode = prev.stdenvNoCC.mkDerivation {
    pname = "opencode";
    inherit version;
    src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;
    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isElf [prev.autoPatchelfHook];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src/opencode $out/bin/opencode
      runHook postInstall
    '';
    meta = with prev.lib; {
      description = "AI coding agent built for the terminal";
      homepage = "https://opencode.ai";
      license = licenses.mit;
      mainProgram = "opencode";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

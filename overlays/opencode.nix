# Use upstream V2 binaries: nixpkgs still packages V1.
_final: prev: let
  version = "2.2.6";
  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      stripRoot = false;
      hash = "sha256-4EJvIb1mN0NwfLoIQsvF+VY482+HAUKw9+/qW1cBLeg=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64-baseline.zip";
      stripRoot = false;
      hash = "sha256-pYr2PyXLY2MsSSdDRGs5t4rRHbIMeWrJPp2lXC2CQR8=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-fx7IhETLKGJn10uki7XkGOpOPIxX0GJNsulvUKw/dy0=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-ftsksKjrvuy8EFSOTg59Y8UB/gI7suwrX979N78iK+w=";
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

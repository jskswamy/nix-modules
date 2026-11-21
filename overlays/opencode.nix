# Use upstream V2 binaries: nixpkgs still packages V1.
_final: prev: let
  version = "2.3.2";
  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      stripRoot = false;
      hash = "sha256-HbF+mCmIuiq1skTuWBOsMUoL10W1lMD5y2egNQfD768=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64-baseline.zip";
      stripRoot = false;
      hash = "sha256-SN0a1mN/jdgdFpwZkbAarjVgljWAJlBTFOi7/FwWPpI=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-7Mk+Jc+p57uelmaZ/lP9RfwB4jRX9/BNOQlQVm2thm0=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64-musl.tar.gz";
      stripRoot = false;
      hash = "sha256-0M7m7XTlUa5A0cXHvkPlq99c0U1fj5Z0v8jYfgyVGzI=";
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

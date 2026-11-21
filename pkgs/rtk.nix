# Provide rtk (Rust Token Killer) from upstream GitHub release binaries
# instead of nixpkgs, keeping it fast to install without compiling from source.
_final: prev: let
  rtkVersion = "1.2.1";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-O8KpLx0+QE75nCAM3cwPSRfWxO1bEnp1GTipb1fU7Zo=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-EH4nIlPAqjbJyF+/ndGIvbWNhsa6moW0kSJCC69uTFw=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-X9dRUf7q4rgbGET8qYiWEMx3QINhZT7z+V1LnT4nj08=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-dfZFJXEb6TVlemsijZKcJL2dGrfWQOo3SouRPltbrAU=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  rtk = prev.stdenv.mkDerivation {
    pname = "rtk";
    version = rtkVersion;

    inherit src;

    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isElf [
      prev.autoPatchelfHook
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 rtk $out/bin/rtk
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "RTK (Rust Token Killer) - reduce LLM token consumption";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.mit;
      mainProgram = "rtk";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

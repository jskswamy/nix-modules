# Provide rtk (Rust Token Killer) from upstream GitHub release binaries
# instead of nixpkgs, keeping it fast to install without compiling from source.
_final: prev: let
  rtkVersion = "1.0.1";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-Sq4vYM/EnJ6BuMjFcCCqDLgk2mCMeLTwz1wJiOGegk4=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-x86_64-apple-darwin.tar.gz";
      hash = "sha256-S3FrL0XWd95ByZ932acRma0GC5jsL3jvcSiFMSs6ZXg=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-zWJ8QJGtkLXlrKg8pa9m7kuKqFN6c2Uz+pBUT0YfHCs=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-W5GcO8y3mbZ6YYZtDmF0EKT83xc+JhREDlneL6IANDY=";
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

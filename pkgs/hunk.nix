# Provide hunk (review-first terminal diff viewer) using pre-built binaries
_final: prev: let
  hunkVersion = "0.17.7";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-C8nzGI0WWar/W+Pab+0W551V8s28zMg+4S0jNIbALEM=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-RCin83+KbJdBvreuBfU6zuLDqhGT6YxDDngXvzkAvjA=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-G4VIA9VICt25XTa9Z856/dkaHZstai/1eGsp9jyjzg0=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-S4kN29aYUyvrp4/DxnxdQ0yO89LkMPOdUW/UCHd2L0k=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  hunk = prev.stdenv.mkDerivation {
    pname = "hunk";
    version = hunkVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/hunk $out/bin/hunk
    '';

    meta = with prev.lib; {
      description = "Review-first terminal diff viewer for agentic coders";
      homepage = "https://github.com/modem-dev/hunk";
      license = licenses.mit;
      mainProgram = "hunk";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

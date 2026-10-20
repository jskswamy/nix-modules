# Provide hunk (review-first terminal diff viewer) using pre-built binaries
_final: prev: let
  hunkVersion = "0.24.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-ahTOG37VkEbIosU2KIQwge3eR2rVVev+vSNl9HcV1wY=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-J4SjZoyH41AtEooXJQyuHvDP78DSQJYVsKTtSXaLvYE=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-cpeZ5J0CqC138SvMvmTALinZwgfJmuEpFcpiXr2UdzA=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-Z3Ca5krL2WXho+0n5vMONxVwffVLuNNwjrx8VN8pJuw=";
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

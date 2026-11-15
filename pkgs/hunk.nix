# Provide hunk (review-first terminal diff viewer) using pre-built binaries
_final: prev: let
  hunkVersion = "0.25.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-XT44z+t1fxNa0KTMP5kbc3HZ5k+dTX1hXl+cX5p5zSI=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-awGjnZL1IbUyjXXvXk3pH9eC8LzhTXaL4KDrZOOWDag=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-YlOdnWfpYI0NoB/eKlpE+oUMOGVPV0zTrR8SWY1ZqQ4=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-eZfqiRjwvso6et6mK60GQDgdKgv0Yx9DGkbDosogkCo=";
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

# Provide hunk (review-first terminal diff viewer) using pre-built binaries
_final: prev: let
  hunkVersion = "0.22.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-ZTXhXPFlhyECpWme5e+LcUE2TuXy8LOxcgzqGKkh6ys=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-darwin-x64.tar.gz";
      hash = "sha256-LBVWH/EfhcvWyb+fmDMBnHZryiezHMbroFQZl5Alz+E=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-arm64.tar.gz";
      hash = "sha256-Y4R6deq5Qw2L05ClXjI0C6xnmfm2CBJzl60F62uYSJI=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/modem-dev/hunk/releases/download/v${hunkVersion}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-qnA0DttNn9k2sfbStHGlJM9bz3DD9+uOOEy4ZyzntxI=";
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

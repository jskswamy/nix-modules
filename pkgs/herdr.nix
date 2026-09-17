# Provide herdr (terminal workspace manager for AI coding agents) from
# upstream's own release binaries instead of nixpkgs, which lags upstream's
# fast release cadence (nixpkgs had 0.7.5 while upstream was at 0.8.2).
# Upstream ships raw binaries (no archive) via https://herdr.dev/latest.json,
# the same manifest `herdr update` reads.
_final: prev: let
  herdrVersion = "0.9.1";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-macos-aarch64";
      hash = "sha256-X8en5636ylb6gKqJ3LAlaTNXJo2rgoW5zi0IojE8id4=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-macos-x86_64";
      hash = "sha256-BTvgY5k1/lSrXvvbRmUQVOT2p1OltDFTyIvWkSvOHpQ=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-linux-aarch64";
      hash = "sha256-9Mz03nRfLLmjmpg+m6NwPa1Q7CpY3qgwJs6rchu9jZ4=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-linux-x86_64";
      hash = "sha256-KgL+0WvrZR7wBuHUPwSPZSyk3FitBTzS1ERQVj1cVLc=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  herdr = prev.stdenv.mkDerivation {
    pname = "herdr";
    version = herdrVersion;

    inherit src;

    dontUnpack = true;
    # Skip fixup on Darwin: patching a downloaded, already-signed binary
    # (strip/install_name_tool) invalidates its signature and Gatekeeper
    # kills it on launch.
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src $out/bin/herdr
    '';

    meta = with prev.lib; {
      description = "Terminal workspace manager for AI coding agents";
      homepage = "https://herdr.dev";
      mainProgram = "herdr";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

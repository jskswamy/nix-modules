# Provide herdr (terminal workspace manager for AI coding agents) from
# upstream's own release binaries instead of nixpkgs, which lags upstream's
# fast release cadence (nixpkgs had 0.7.5 while upstream was at 0.8.2).
# Upstream ships raw binaries (no archive) via https://herdr.dev/latest.json,
# the same manifest `herdr update` reads.
_final: prev: let
  herdrVersion = "0.9.3";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-macos-aarch64";
      hash = "sha256-UXOj4K5C1dGrfr+l1eYyn3w9I/jho2d8fOMjHaKIQVc=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-macos-x86_64";
      hash = "sha256-22LVSP8+gysIepaxiUoI0mvjkF8YMDCc1VZ4PyFdQFQ=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-linux-aarch64";
      hash = "sha256-TeeqPiVniBLpKWDeZPfCqqG8ofD4CjxeVZg34jHh9cA=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/herdrdev/herdr/releases/download/v${herdrVersion}/herdr-linux-x86_64";
      hash = "sha256-GKjcZfHC+khYhDRDVt6hz9kRxvBs9G+njhk/QIf026c=";
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

# aide: sandboxed, reproducible entrypoint for coding agents (OS-native
# sandboxing via macOS Seatbelt / Linux Landlock+seccomp). Not available in
# nixpkgs; upstream ships its own flake too, but vendoring the release
# binary here keeps ownPkg's no-overlay-applied fallback working (see
# lib/default.nix) instead of threading a foreign flake input through this
# repo's own overlay.
_final: prev: let
  version = "3.0.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-Syxhrpi/84zuh01esPyrkDLnyccqJUYodnqSxFq6WUA=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-6ucBbkNgvjlkNaPPSOLA4GttHAoJ/6k0b0da1WixyK4=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-jZR4aC1vFMHhPrSX1ZCTwbKUoVoQ7zDc+9KBBs/eXIg=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-763JgVplJ7uwU125ar1XN8PFIgYwN0Ozh6zOGA2zc0k=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "aide overlay: no binary pinned for ${prev.stdenv.hostPlatform.system}");
in {
  aide = prev.stdenv.mkDerivation {
    pname = "aide";
    inherit version src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/aide $out/bin/aide
    '';

    meta = with prev.lib; {
      description = "Sandboxed, reproducible entrypoint for coding agents";
      homepage = "https://github.com/jskswamy/aide";
      mainProgram = "aide";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

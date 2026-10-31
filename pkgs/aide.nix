# aide: sandboxed, reproducible entrypoint for coding agents (OS-native
# sandboxing via macOS Seatbelt / Linux Landlock+seccomp). Not available in
# nixpkgs; upstream ships its own flake too, but vendoring the release
# binary here keeps ownPkg's no-overlay-applied fallback working (see
# lib/default.nix) instead of threading a foreign flake input through this
# repo's own overlay.
_final: prev: let
  version = "3.2.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-c9nGUbidLmi1Xa2P4NOF1YCcV4tBFFbw1/Sj0Wd68MY=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-BTFlm3UQTHEaFfXjr11C8LLxzcbGdbaihZqUDZmborM=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-amkmrkiZTUwLKwcAjbjFm88/JAo5ZLrAJkVU++2fbwc=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-JzTh6aWio5l9OnqviurD8pC4i/0n2MpXbuUJnmUNGUk=";
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

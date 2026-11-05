# aide: sandboxed, reproducible entrypoint for coding agents (OS-native
# sandboxing via macOS Seatbelt / Linux Landlock+seccomp). Not available in
# nixpkgs; upstream ships its own flake too, but vendoring the release
# binary here keeps ownPkg's no-overlay-applied fallback working (see
# lib/default.nix) instead of threading a foreign flake input through this
# repo's own overlay.
_final: prev: let
  version = "3.4.0";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-rfNavqcQEZO+JaFd4aLjBJU3M+uFnIehhwGzxDGe5Hc=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-FL/chskquCPl2Hn2M7u/1QE57a/at1hYCDXR+kOkwDM=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-E/pJRNliGvnlS23Rh60KR43lcFy4xKQyRuzY3y1pDj8=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/jskswamy/aide/releases/download/v${version}/aide_${version}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-JNojWxVsEXz5tOKdcbZnxzWtgBG5xT7/fpfUj7zQFoo=";
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

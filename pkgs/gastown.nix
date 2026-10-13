# Gastown - Multi-agent orchestration system for Claude Code
# Not available in nixpkgs. Upstream publishes prebuilt release binaries for
# every platform we target, so we use those instead of buildGoModule — this
# used to compile from source, and a nixpkgs bump (new Go toolchain) meant
# rebuilding it from scratch every time, even though the pinned version and
# vendored deps hadn't changed.
# https://github.com/gastownhall/gastown
_: prev: let
  version = "1.2.1";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/gastown/releases/download/v${version}/gastown_${version}_darwin_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-LT1xfz/+DUHkIGNGujtjCCXGmuCPfupsJtQvAh3QZHw=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/gastownhall/gastown/releases/download/v${version}/gastown_${version}_darwin_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-B1sKuIFcLpJwjh2mR6q5LOMBCSWZenC9/jlOW4BHgvo=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/gastown/releases/download/v${version}/gastown_${version}_linux_amd64.tar.gz";
      stripRoot = false;
      hash = "sha256-UHdDad9GKgmVTnDGn4jEDhuyq7e1LhpwwXDOkRM59dk=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/gastownhall/gastown/releases/download/v${version}/gastown_${version}_linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-eXRikX32b5rpOXerhJuxMNR+VO3eaCvzWTwLILWx7kY=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  gastown = prev.stdenv.mkDerivation {
    pname = "gastown";
    inherit version src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/gt $out/bin/gt
    '';

    meta = with prev.lib; {
      description = "Multi-agent orchestration system for Claude Code with persistent work tracking";
      homepage = "https://github.com/gastownhall/gastown";
      license = licenses.asl20;
      mainProgram = "gt";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

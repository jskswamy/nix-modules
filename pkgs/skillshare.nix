# Provide skillshare (skill, plugin and MCP manager) using pre-built binaries
_final: prev: let
  version = "0.30.8";

  base = "https://github.com/runkids/skillshare/releases/download/v${version}";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "${base}/skillshare_${version}_darwin_arm64.tar.gz";
      hash = "sha256-c/CwtxFM9Czv2nlRB6BiUru54QdR1q3bF0zYuaWpecc=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "${base}/skillshare_${version}_darwin_amd64.tar.gz";
      hash = "sha256-+U7Vq8siufVeusUj+k9Oy8u3cNHWpKJLNXdzEy/jMyY=";
    };
    aarch64-linux = prev.fetchurl {
      url = "${base}/skillshare_${version}_linux_arm64.tar.gz";
      hash = "sha256-bTW+806KNKQRGlM9T7/jrVaoz2dnDftEqu8u49LUVKM=";
    };
    x86_64-linux = prev.fetchurl {
      url = "${base}/skillshare_${version}_linux_amd64.tar.gz";
      hash = "sha256-W9mdBncXHWGQCfSUZKq8s/rdhrfoe4XrZrQEdrnP/l4=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  skillshare = prev.stdenv.mkDerivation {
    pname = "skillshare";
    inherit version src;

    sourceRoot = ".";
    # The release binary carries the Go linker's ad-hoc signature, which
    # arm64 macOS requires; fixup's strip would invalidate it. Like this
    # repo's other prebuilt Darwin binaries, it needs no patching.
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 skillshare $out/bin/skillshare
    '';

    meta = with prev.lib; {
      description = "Skill, plugin and MCP manager for AI coding agents";
      homepage = "https://github.com/runkids/skillshare";
      license = licenses.mit;
      mainProgram = "skillshare";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

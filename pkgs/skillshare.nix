# Provide skillshare (skill, plugin and MCP manager) using pre-built binaries
_final: prev: let
  version = "0.26.0";

  base = "https://github.com/runkids/skillshare/releases/download/v${version}";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "${base}/skillshare_${version}_darwin_arm64.tar.gz";
      hash = "sha256-Sf7TcrnmN7hzrnKqOz+xqjLsQFUxOI0zYrE+wZtNTkI=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "${base}/skillshare_${version}_darwin_amd64.tar.gz";
      hash = "sha256-1we8OPmPjWLsUwindNzY5uC3a7ksTBWWdYgxZ7vE9nc=";
    };
    aarch64-linux = prev.fetchurl {
      url = "${base}/skillshare_${version}_linux_arm64.tar.gz";
      hash = "sha256-eD/qanuPTIwhbpy+hv/QbKjWZJ/M1mFMTY7G4p1WTeo=";
    };
    x86_64-linux = prev.fetchurl {
      url = "${base}/skillshare_${version}_linux_amd64.tar.gz";
      hash = "sha256-XChRX1FcuJsTKOtSYPqKgqtHemvpCNduSzHcN8/Xifc=";
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

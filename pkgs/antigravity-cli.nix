# Provide antigravity-cli (Google's Go-based TUI agent client) from Google's
# official pre-built binaries instead of nixpkgs, which lags upstream's
# release cadence.
_final: prev: let
  version = "1.5.14";
  buildId = "6591305019686912";
  wholeVersion = "${version}-${buildId}";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/darwin-arm/cli_mac_arm64.tar.gz";
      hash = "sha256-hfa7JclGEDGxgycEKCpqhv4Y7BtOUxbKRt2ATt0P2yY=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/darwin-x64/cli_mac_x64.tar.gz";
      hash = "sha256-Dvdt2J+T+9ndxz4+Meq7mscSRqr5ScfygN2v5m4+2PU=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-x64/cli_linux_x64.tar.gz";
      hash = "sha256-vlPwGfgpIkVE1hI0cJFlF6ZDzOSVUF/KswQSWLv9yCc=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-arm/cli_linux_arm64.tar.gz";
      hash = "sha256-1iMt3eNu72ijNSyJnDDrHPtC5ZxPh4SI62UN9OQXxZA=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  antigravity-cli = prev.stdenvNoCC.mkDerivation {
    pname = "antigravity-cli";
    inherit version;

    inherit src;

    sourceRoot = ".";

    nativeBuildInputs = prev.lib.optionals prev.stdenvNoCC.hostPlatform.isElf [
      prev.autoPatchelfHook
    ];

    dontConfigure = true;
    dontBuild = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      runHook preInstall

      install -Dm755 antigravity $out/bin/agy
      ln -s agy $out/bin/antigravity

      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Google's Go-based terminal user interface (TUI) agent client";
      homepage = "https://antigravity.google";
      mainProgram = "agy";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

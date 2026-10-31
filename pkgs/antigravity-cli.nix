# Provide antigravity-cli (Google's Go-based TUI agent client) from Google's
# official pre-built binaries instead of nixpkgs, which lags upstream's
# release cadence.
_final: prev: let
  version = "1.4.12";
  buildId = "4768735748292608";
  wholeVersion = "${version}-${buildId}";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/darwin-arm/cli_mac_arm64.tar.gz";
      hash = "sha256-TJibXM8OOcmaHObfgkEKu2KNTYPg0xg1J3At90TZxYk=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/darwin-x64/cli_mac_x64.tar.gz";
      hash = "sha256-Yk0BNp31hB9kVVdB3QnTq0ptF0aZpN7YlqUYDIHywt4=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-x64/cli_linux_x64.tar.gz";
      hash = "sha256-M2jRkj/IafIeyPzoMlKoyWyJKDqsk5OViskfv3o5SeQ=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-arm/cli_linux_arm64.tar.gz";
      hash = "sha256-MN1h6+HwqIKQV+ot4p2tCMcQ3Zcs5MApSfUeYyE1qGs=";
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

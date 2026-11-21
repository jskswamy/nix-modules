# Provide pkl from upstream GitHub release binaries instead of nixpkgs,
# avoiding the 1.2 GB JVM closure and Java deprecation warnings.
_: prev: let
  pklVersion = "0.33.1";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-macos-aarch64";
      hash = "sha256-b5Pd9lJKV3G9S2694RAQxt/ujjqJBv/rqo9S+KC6Frc=";
    };
    # No x86_64-darwin: upstream stopped publishing pkl-macos-amd64 in 0.33.0.
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-aarch64";
      hash = "sha256-SnUgltqxPXQy4fCk8SGYM9+V4eNs4LjUJLDtss1UNvk=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-amd64";
      hash = "sha256-rLypu08xE50J4pXQPJ+yX3ft9adK9OdytWsy3G3BfEQ=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  pkl = prev.stdenv.mkDerivation {
    pname = "pkl";
    version = pklVersion;

    inherit src;

    dontUnpack = true;
    dontBuild = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/pkl
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Configuration-as-code language with rich validation and tooling";
      homepage = "https://pkl-lang.org";
      license = licenses.asl20;
      mainProgram = "pkl";
      platforms = ["aarch64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

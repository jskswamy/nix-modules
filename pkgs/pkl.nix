# Provide pkl from upstream GitHub release binaries instead of nixpkgs,
# avoiding the 1.2 GB JVM closure and Java deprecation warnings.
_: prev: let
  pklVersion = "0.33.0";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-macos-aarch64";
      hash = "sha256-45wVffDwCjXTS0YnCnaHhO3K9Qmq+/dDhJsntMg++Ds=";
    };
    # No x86_64-darwin: upstream stopped publishing pkl-macos-amd64 in 0.33.0.
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-aarch64";
      hash = "sha256-7c6jYUAuyrDzqT+GsaiWxB0AqSQfSWL3AnglSwj70m0=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-amd64";
      hash = "sha256-uabd6ms4K31NtM9453qjhY4Min4Ck50rophXS10fzGk=";
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

# Provide pkl from upstream GitHub release binaries instead of nixpkgs,
# avoiding the 1.2 GB JVM closure and Java deprecation warnings.
_: prev: let
  pklVersion = "0.32.2";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-macos-aarch64";
      hash = "sha256-RmlS8LMMk9+jY5Ols2lRWZF85CkePJNqGKCiQM++mOk=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-macos-amd64";
      hash = "sha256-PEyRSnUhDT8yknQLSo1Ef5+DLoG2ByC+xXIh6IRxfu4=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-aarch64";
      hash = "sha256-5gdE4X1N3AJXo1JgmYtfmDh7XWpehoMXzM++vo2WKuM=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/apple/pkl/releases/download/${pklVersion}/pkl-linux-amd64";
      hash = "sha256-h0x1SEx5rdd/sjRupKsuiHXuo1+3B4lL9UV6LfXQPe8=";
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
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

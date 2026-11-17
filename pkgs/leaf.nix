# Provide leaf (terminal Markdown previewer) using pre-built release binaries
# from upstream GitHub releases.
# https://github.com/RivoLink/leaf
_final: prev: let
  leafVersion = "1.29.3";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/RivoLink/leaf/releases/download/${leafVersion}/leaf-macos-arm64";
      hash = "sha256-bfffpwqXMVz/ArIMvsPt1PQOohiNAu4ClIISv/Uq4a8=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/RivoLink/leaf/releases/download/${leafVersion}/leaf-macos-x86_64";
      hash = "sha256-CZ3qwWBBvMQXTXtRmPXM0bhQX3LvWXr8vJwV+uasIOc=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/RivoLink/leaf/releases/download/${leafVersion}/leaf-linux-arm64";
      hash = "sha256-8HqHvkxsy6vShkvGHB1yqiSdgyzxsqAb7ZgFKbGe8SU=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/RivoLink/leaf/releases/download/${leafVersion}/leaf-linux-x86_64";
      hash = "sha256-QDfL5pokggkhrVbyxDWVxSVj7Ff/zoDpuc9T0uLEDPc=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  leaf = prev.stdenv.mkDerivation {
    pname = "leaf";
    version = leafVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isElf [
      prev.autoPatchelfHook
    ];

    installPhase = ''
      install -Dm755 $src $out/bin/leaf
    '';

    meta = with prev.lib; {
      description = "Terminal Markdown previewer with a GUI-like experience";
      homepage = "https://github.com/RivoLink/leaf";
      license = licenses.mit;
      mainProgram = "leaf";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

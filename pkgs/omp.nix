# Provide omp (oh-my-pi coding agent) from upstream GitHub release
# binaries instead of the flake's bun/crane source build. Consumers keep
# inputs.omp.homeManagerModules.default and set programs.omp.package to
# this overlay package so the module's config activation stays, without
# pulling the ~700 bun-pkg derivations into the system closure.
_final: prev: let
  version = "18.20.2";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
      hash = "sha256-4t4JdM5YG/zyBE6nlccS+iQP34ME9720s9gbFU0rV/w=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
      hash = "sha256-g2/qV7Hfz1PCYFOu89V7bR+D7ANKf4sl14kCLFrbw2U=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-80z6VzEe1npF8BuxohUZytTXSHXRgTFvAPoM1qSryqo=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      hash = "sha256-f4CeUWOMKs5wEkSSPV7GJIW7r9dNt12nQqzjDIepHr8=";
    };
  };
in {
  omp = prev.stdenvNoCC.mkDerivation {
    pname = "omp";
    inherit version;

    src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isElf [
      prev.autoPatchelfHook
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/omp
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "OMP coding agent (oh-my-pi)";
      homepage = "https://github.com/can1357/oh-my-pi";
      license = licenses.mit;
      mainProgram = "omp";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

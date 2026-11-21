# Provide omp (oh-my-pi coding agent) from upstream GitHub release
# binaries instead of the flake's bun/crane source build. Consumers keep
# inputs.omp.homeManagerModules.default and set programs.omp.package to
# this overlay package so the module's config activation stays, without
# pulling the ~700 bun-pkg derivations into the system closure.
_final: prev: let
  version = "19.0.1";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
      hash = "sha256-L+Qgu9APgYmYFuUcvuuVk6+lnZNo1iydPnhTXVQOMvY=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
      hash = "sha256-jWJQLu3ox6QzEXmENNCjGhwCSjq8Vr7cTaIAzM+U/qE=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-bO7wRDCFG7EFDG/aOvRnQS60ShHfCm/4Eh/mAQE8VBU=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      hash = "sha256-I37eD0mU1h9SOALEz1YtTki650wYit15LQbQUbkHzs8=";
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

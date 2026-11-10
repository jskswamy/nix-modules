# Provide omp (oh-my-pi coding agent) from upstream GitHub release
# binaries instead of the flake's bun/crane source build. Consumers keep
# inputs.omp.homeManagerModules.default and set programs.omp.package to
# this overlay package so the module's config activation stays, without
# pulling the ~700 bun-pkg derivations into the system closure.
_final: prev: let
  version = "18.18.6";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-arm64";
      hash = "sha256-7S5j60OIjrdssUCbJFsdtFV8lN+tUtxUXJqsoB686C0=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-x64";
      hash = "sha256-g2/qV7Hfz1PCYFOu89V7bR+D7ANKf4sl14kCLFrbw2U=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
      hash = "sha256-qAWbld5eq6Cz+29xgoQtZh/q4pyykxzb66KYbbR1Hss=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
      hash = "sha256-qp1pOA997QmLzT2AI6Z+3Mj8PMBSk2Cpje3twhz6EBs=";
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

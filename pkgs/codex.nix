# Provide codex (OpenAI's coding agent CLI) from upstream GitHub release
# binaries instead of nixpkgs, keeping it at latest release without
# requiring full rust compilation.
_final: prev: let
  codexVersion = "0.163.0";

  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-sDRPwuQfFeAHEUflhpAIBHuP9L8sSoiXl107rj8QOzQ=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-apple-darwin.tar.gz";
      hash = "sha256-DBgtYZTacAOUNnjch4ZrVLPe5xntr40JLzBK/7xrV9E=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-WCZGxr8FYesN5UD3/IW5EhsAkagmvG6Wgwt/FyISIYI=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-nY7PLRnT4YSHeYOQLWyF3kiziI3LcsOCqKDJdYRZJ/s=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  codex = prev.stdenv.mkDerivation {
    pname = "codex";
    version = codexVersion;

    inherit src;

    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;
    # Skip fixup on Darwin: stripping or modifying Mach-O headers invalidates
    # code signatures and causes macOS Gatekeeper/SIP kills.
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isElf [
      prev.autoPatchelfHook
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r * $out/

      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "OpenAI Codex CLI coding agent";
      homepage = "https://github.com/openai/codex";
      mainProgram = "codex";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

# Override entire to latest version using pre-built binaries
_final: prev: let
  entireVersion = "0.13.1";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://github.com/entireio/cli/releases/download/v${entireVersion}/entire_darwin_arm64.tar.gz";
      hash = "sha256-ounjdk2yXy6aaswPx02BZlq1Yo29eHOFgC7ZY1XR+eQ=";
      stripRoot = false;
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://github.com/entireio/cli/releases/download/v${entireVersion}/entire_darwin_amd64.tar.gz";
      hash = "sha256-xQq0Vlhz9K8wRJ/g21YyCR/53XPXzJohV0dgY0GxTIk=";
      stripRoot = false;
    };
    x86_64-linux = prev.fetchzip {
      url = "https://github.com/entireio/cli/releases/download/v${entireVersion}/entire_linux_amd64.tar.gz";
      hash = "sha256-8VOSr0s2cvgx7SDJGOiHU3zUI2yQXXnqgXvgi04ZOM8=";
      stripRoot = false;
    };
    aarch64-linux = prev.fetchzip {
      url = "https://github.com/entireio/cli/releases/download/v${entireVersion}/entire_linux_arm64.tar.gz";
      hash = "sha256-qgmKAJUU51sLyFynJQ4s8hOveIu3U39U1Ezxw0rOCGg=";
      stripRoot = false;
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  entire = prev.stdenv.mkDerivation {
    pname = "entire";
    version = entireVersion;

    inherit src;

    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/entire $out/bin/entire
      install -Dm644 $src/completions/entire.bash $out/share/bash-completion/completions/entire
      install -Dm644 $src/completions/entire.fish $out/share/fish/vendor_completions.d/entire.fish
      install -Dm644 $src/completions/entire.zsh $out/share/zsh/site-functions/_entire
    '';

    meta = with prev.lib; {
      description = "CLI tool that captures AI agent sessions alongside git commits";
      homepage = "https://github.com/entireio/cli";
      license = licenses.unfree;
      mainProgram = "entire";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

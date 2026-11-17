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
      install -Dm755 $src $out/bin/.leaf-wrapped

      cat > $out/bin/leaf <<EOF
      #!/bin/sh
      if [ -z "\''${LEAF_THEME:-}" ]; then
        if [ -x /usr/bin/defaults ] && [ "\$(/usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null)" != "Dark" ]; then
          if [ -f "\''${XDG_CONFIG_HOME:-\$HOME/.config}/leaf/themes/merino-light.toml" ]; then
            export LEAF_THEME="merino-light"
          else
            export LEAF_THEME="arctic"
          fi
        elif [ -f "\''${XDG_CONFIG_HOME:-\$HOME/.config}/leaf/themes/merino-dark.toml" ]; then
          export LEAF_THEME="merino-dark"
        fi
      fi
      exec "$out/bin/.leaf-wrapped" "\$@"
      EOF
      chmod 0755 $out/bin/leaf

      install -d $out/share/bash-completion/completions
      install -d $out/share/fish/vendor_completions.d
      install -d $out/share/zsh/site-functions
      $out/bin/.leaf-wrapped --auto-complete bash:dump > $out/share/bash-completion/completions/leaf.bash
      $out/bin/.leaf-wrapped --auto-complete fish:dump > $out/share/fish/vendor_completions.d/leaf.fish
      $out/bin/.leaf-wrapped --auto-complete zsh:dump > $out/share/zsh/site-functions/_leaf
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

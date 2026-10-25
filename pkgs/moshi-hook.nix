# Provide moshi-hook (daemon + CLI bridging AI coding agents to the Moshi
# mobile app, getmoshi.app) from upstream's own prebuilt binaries. Not in
# nixpkgs; the only other source is a Homebrew tap (rjyo/homebrew-moshi)
# whose install goes through Homebrew's Xcode-version preflight check,
# which is broken on pre-release macOS (Homebrew/brew#21216) even though
# this formula only unpacks a prebuilt binary and never compiles anything.
# Fetching the same binary directly via Nix skips that check entirely.
_final: prev: let
  moshiHookVersion = "0.4.37";

  sources = {
    aarch64-darwin = prev.fetchzip {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/moshi-hook_Darwin_arm64.tar.gz";
      stripRoot = false; # flat tarball, no wrapping directory
      hash = "sha256-I42/zfC8kDNcMImgpwR9HY7ynnL23E291rCcj9C4Sjs=";
    };
    x86_64-darwin = prev.fetchzip {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/moshi-hook_Darwin_x86_64.tar.gz";
      stripRoot = false;
      hash = "sha256-eynLAvcBYweWfxzWz+lGV4vwbt9x6rkD1IGJ44aNLjk=";
    };
    aarch64-linux = prev.fetchzip {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/moshi-hook_Linux_arm64.tar.gz";
      stripRoot = false;
      hash = "sha256-1oOzbz5QaiN2JZrM5GHzpv6W1GjVjTfULoFTkBvJeNA=";
    };
    x86_64-linux = prev.fetchzip {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/moshi-hook_Linux_x86_64.tar.gz";
      stripRoot = false;
      hash = "sha256-1yYoTodU8v6O9xsD0OwlbduykHw8wwMpxJGxTmFG17Y=";
    };
  };

  src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
in {
  moshi-hook = prev.stdenv.mkDerivation {
    pname = "moshi-hook";
    version = moshiHookVersion;

    inherit src;

    dontUnpack = true;
    # Skip fixup on Darwin: patching a downloaded, already-signed binary
    # (strip/install_name_tool) invalidates its signature and Gatekeeper
    # kills it on launch.
    dontFixup = prev.stdenv.hostPlatform.isDarwin;

    installPhase = ''
      install -Dm755 $src/moshi-hook $out/bin/moshi-hook
      ln -s $out/bin/moshi-hook $out/bin/moshi
    '';

    meta = with prev.lib; {
      description = "Portable daemon + CLI that bridges AI coding agents to the Moshi mobile app";
      homepage = "https://getmoshi.app";
      mainProgram = "moshi-hook";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

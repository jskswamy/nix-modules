# Use upstream Oh My Posh binaries so we stay ahead of nixpkgs and get
# recent agent statusline features (such as Claude's .PromptCache fields,
# added in v31.5.0).
_final: prev: let
  version = "33.4.1";
  sources = {
    aarch64-darwin = prev.fetchurl {
      url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-darwin-arm64";
      hash = "sha256-P4Zn2RjfIusul10Nw5xxCBt8722EOjPAcMQF8Dn7qBA=";
    };
    x86_64-darwin = prev.fetchurl {
      url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-darwin-amd64";
      hash = "sha256-tgkMyrJUSHC2t2cuubr5w/GAcwROhPpAWvlo2cKKWLQ=";
    };
    x86_64-linux = prev.fetchurl {
      url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-linux-amd64";
      hash = "sha256-SPD2Gx8QbsKW8CTrquZ1xM1vKhhaQTL5rfzU2386Op0=";
    };
    aarch64-linux = prev.fetchurl {
      url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-linux-arm64";
      hash = "sha256-MgAZNttPUdfuTVMSgj0fty7ajsH+bOLvyrqITsM9YSk=";
    };
  };
in {
  oh-my-posh = prev.stdenvNoCC.mkDerivation {
    pname = "oh-my-posh";
    inherit version;
    src = sources.${prev.stdenv.hostPlatform.system} or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    dontUnpack = true;
    dontFixup = prev.stdenv.hostPlatform.isDarwin;
    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/oh-my-posh
      runHook postInstall
    '';
    meta = with prev.lib; {
      description = "Prompt theme engine for any shell";
      homepage = "https://ohmyposh.dev";
      license = licenses.mit;
      mainProgram = "oh-my-posh";
      platforms = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
    };
  };
}

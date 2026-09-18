# ccstatusline - Customizable status line formatter for Claude Code
# https://github.com/sirmalloc/ccstatusline
# The npm tarball contains a pre-built Bun bundle (no node_modules needed)
_: prev: {
  ccstatusline = prev.stdenv.mkDerivation rec {
    pname = "ccstatusline";
    version = "2.2.30";

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/ccstatusline/-/ccstatusline-${version}.tgz";
      hash = "sha256-NWR5zB/3Nbdmvrom7ploLN7xQ8YDsPTx/X5qVugn12k=";
    };

    nativeBuildInputs = [prev.makeWrapper];

    installPhase = ''
      mkdir -p $out/lib/ccstatusline $out/bin
      cp dist/ccstatusline.js $out/lib/ccstatusline/ccstatusline.js
      makeWrapper ${prev.nodejs_24}/bin/node $out/bin/ccstatusline \
        --add-flags "$out/lib/ccstatusline/ccstatusline.js"
    '';

    meta = with prev.lib; {
      description = "Customizable status line formatter for Claude Code CLI";
      homepage = "https://github.com/sirmalloc/ccstatusline";
      license = licenses.mit;
      mainProgram = "ccstatusline";
    };
  };
}

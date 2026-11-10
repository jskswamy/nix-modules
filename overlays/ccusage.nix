# nixpkgs ccusage 20.0.37 fails on Darwin: zstd-sys's build.rs probes
# libzstd via pkg-config and panics when it is missing. Keep the nixpkgs
# package; only add the libraries the crate expects.
_final: prev: {
  ccusage = prev.ccusage.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.pkg-config];
    buildInputs = (old.buildInputs or []) ++ [prev.zstd];
  });
}

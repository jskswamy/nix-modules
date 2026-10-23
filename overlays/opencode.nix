self: super: {
  opencode = super.opencode.overrideAttrs (old: {
    version = "2.0.31";
    src = super.fetchurl {
      url = "https://github.com/anomalyco/opencode/archive/refs/tags/v2.0.31.tar.gz";
      sha256 = "0072paw3gf33rhmlbdvvj4c8azd1rqrd13dysrza7qp5i58hrfva";
    };
  });
}

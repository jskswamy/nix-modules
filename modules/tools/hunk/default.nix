{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/hunk/config";
  cfg = config.tools.hunk;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.hunk.enable = mkToolEnable lib "hunk";

  config = lib.mkIf cfg.enable {
    # hunk — diff review TUI wrapped by herdr-hunk-diff
    home.file.".config/hunk/config.toml".source =
      src.file "config.toml";
  };
}

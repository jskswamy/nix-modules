# herdr-lazy bootstrap and sync — see
# docs/superpowers/specs/2026-09-01-herdr-plugin-management-design.md
{
  config,
  pkgs,
  lib,
  ...
}: {
  home.activation.herdrLazySync = lib.hm.dag.entryAfter ["linkGeneration"] ''
    HERDR="${pkgs.herdr}/bin/herdr"
    if ! $DRY_RUN_CMD "$HERDR" plugin list --json 2>/dev/null \
      | ${pkgs.jq}/bin/jq -e '.result.plugins[] | select(.plugin_id == "herdr-lazy")' \
      > /dev/null 2>&1; then
      $DRY_RUN_CMD "$HERDR" plugin install natori-hrj/herdr-lazy -y 2>/dev/null || true
    fi
    $DRY_RUN_CMD "$HERDR" plugin action invoke sync --plugin herdr-lazy 2>/dev/null || true
  '';

  # herdr's client auto-spawns "herdr server" as a child of whatever
  # terminal ran it first, so closing that terminal (e.g. Ghostty) took
  # the persistent server down with it. Running it as its own launchd
  # agent keeps it alive independent of any terminal session; clients
  # just connect to the existing socket instead of spawning their own.
  home.activation.herdrServerLogDir = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryBefore ["setupLaunchAgents"] ''
      $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.local/share/herdr
    ''
  );

  launchd.agents.herdr-server = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = ["${pkgs.herdr}/bin/herdr" "server"];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/.local/share/herdr/server.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/herdr/server.log";
    };
  };
}

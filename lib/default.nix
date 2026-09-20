# Helpers shared by every tool module.
{
  # Resolve a tool's own config files to home-manager `source` values.
  #
  # Takes the module's local config directory (a relative path, which Nix
  # resolves to a /nix/store path) and that same directory's path relative
  # to the repository root. `config.nixModules.sourceRoot` picks between
  # them:
  #
  #   null (default) -> the /nix/store path. Hermetic; no checkout
  #                     required. This is what a disposable consumer
  #                     (e.g. cloudlab) wants.
  #
  #   set            -> an out-of-store symlink into a local checkout, so
  #                     editing the file takes effect immediately with no
  #                     rebuild. This is what a daily-driver config wants.
  #
  # Returns `dir` for the directory itself and `file` for a path beneath it.
  mkSource = config: localDir: relDir: let
    root = config.nixModules.sourceRoot;
    out = sub:
      if root != null
      then config.lib.file.mkOutOfStoreSymlink "${root}/${relDir}${sub}"
      else localDir + sub;
  in {
    dir = out "";
    file = sub: out "/${sub}";
  };

  # The `enable` option every tool module declares.
  #
  # Importing a tool module is what asks for that tool, so this defaults
  # to true. The option exists so a tool that arrived as part of a group
  # can be dropped again — `tools.hunk.enable = false` when you took the
  # `git-tools` group but do not want hunk.
  mkToolEnable = lib: name:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to apply the ${name} configuration.";
    };

  # A package this repo defines. Uses the consumer's own `pkgs` when they
  # applied `overlays.default` (the common case, and free), and otherwise
  # applies the overlay locally so that importing a tool module is enough
  # on its own.
  ownPkg = pkgs: name:
    pkgs.${name} or (pkgs.extend (import ../pkgs/overlay.nix)).${name};
}

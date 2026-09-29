# Options every group module depends on. Imported by path so the module
# system deduplicates it when several groups are used together.
{
  config,
  lib,
  ...
}: let
  workspaceRoot = config.nixModules.workspaceRoot;
  home = config.home.homeDirectory;
  normalizedWorkspaceRoot =
    if lib.hasPrefix "/" workspaceRoot
    then workspaceRoot
    else if workspaceRoot == "~"
    then home
    else if lib.hasPrefix "~/" workspaceRoot
    then "${home}/${builtins.substring 2 (builtins.stringLength workspaceRoot) workspaceRoot}"
    else if workspaceRoot == "$HOME"
    then home
    else if lib.hasPrefix "$HOME/" workspaceRoot
    then "${home}/${builtins.substring 6 (builtins.stringLength workspaceRoot) workspaceRoot}"
    else "${home}/${workspaceRoot}";
in {
  options.nixModules = {
    sourceRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/alice/nix-modules";
      description = ''
        Absolute path to a local checkout of this repository.

        When null (the default), config files are read from this flake's
        immutable /nix/store path — hermetic, and no checkout is needed.

        When set, config files are symlinked out of store from that path
        instead, so edits take effect immediately without a rebuild. The
        path is not verified at evaluation time; a wrong value produces
        dangling symlinks rather than an error.
      '';
    };

    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "source";
      example = "src";
      description = ''
        Workspace directory used by source-tree helpers such as godir.

        Relative paths are resolved under home.homeDirectory. The shorthands
        ~/ and $HOME/ are also resolved under home.homeDirectory. Absolute
        paths are used as-is.
      '';
    };
  };

  config.home.sessionVariables.GIT_WORKSPACE = lib.mkDefault normalizedWorkspaceRoot;
}

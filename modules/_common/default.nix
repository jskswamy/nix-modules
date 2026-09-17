# Options every group module depends on. Imported by path so the module
# system deduplicates it when several groups are used together.
{lib, ...}: {
  options.nixModules.sourceRoot = lib.mkOption {
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
}

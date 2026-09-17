# Helpers shared by every group module.
{
  # Resolve one of this flake's own config files to a home-manager
  # `source` value.
  #
  # `config.nixModules.sourceRoot` decides which of the two modes applies:
  #
  #   null (default) -> "${root}/${rel}", an immutable /nix/store path.
  #                     Hermetic; no checkout required. This is what a
  #                     disposable consumer (e.g. cloudlab) wants.
  #
  #   set            -> an out-of-store symlink into a local checkout, so
  #                     editing the file takes effect immediately with no
  #                     rebuild. This is what a daily-driver config wants.
  #
  # `rel` is always relative to the repository root, so the same string
  # works for both modes.
  mkSource = config: root: rel:
    if config.nixModules.sourceRoot != null
    then config.lib.file.mkOutOfStoreSymlink "${config.nixModules.sourceRoot}/${rel}"
    else "${root}/${rel}";
}

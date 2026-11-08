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

  # Assertions for an app's shared prefix keys (terminal.keys): every
  # action must be one the app maps, no key may serve two actions, and no
  # key may take over one the app's hand-written config already binds.
  # `reserved` is that list of hand-written keys, in the same syntax.
  prefixKeyAssertions = lib: {
    option,
    keys,
    actions,
    reserved,
  }: let
    unknown = lib.subtractLists (builtins.attrNames actions) (builtins.attrNames keys);
    bound = lib.concatLists (builtins.attrValues keys);
    dupes = lib.unique (lib.filter (k: lib.count (x: x == k) bound > 1) bound);
    clashes = lib.unique (lib.intersectLists bound reserved);
    show = ks: lib.concatMapStringsSep ", " (k: "\"${k}\"") ks;
  in [
    {
      assertion = unknown == [];
      message = "${option}: unknown action(s) ${show unknown}. Known actions: ${lib.concatStringsSep ", " (builtins.attrNames actions)}.";
    }
    {
      assertion = dupes == [];
      message = "${option}: key(s) ${show dupes} are given to more than one action.";
    }
    {
      assertion = clashes == [];
      message = "${option}: key(s) ${show clashes} are already bound in the app's hand-written config; pick another key or remove that binding.";
    }
  ];

  # Every capture of `regex` in `text`, taking each match's last group.
  allMatches = lib: regex: text:
    map lib.last (lib.filter builtins.isList (builtins.split regex text));

  # A package this repo defines. Always taken from this repo's overlay,
  # never from the consumer's `pkgs.${name}`: a name like `aide` also
  # exists in nixpkgs (the unrelated AIDE intrusion detector), and
  # preferring `pkgs.${name}` silently installs that one wherever the
  # consumer has not applied `overlays.default`.
  ownPkg = pkgs: name: (pkgs.extend (import ../pkgs/overlay.nix)).${name};
}

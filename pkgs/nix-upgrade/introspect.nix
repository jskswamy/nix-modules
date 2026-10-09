# Introspects a flake's packages.<system> outputs to find each overlay
# package's GitHub owner/repo, by regexing the URL out of its fetcher
# (fetchFromGitHub's .url, or fetchzip/fetchurl's .url/.urls — nix-modules'
# own packages are all the latter). No table is hardcoded: packages whose
# src isn't a github.com URL (patches, non-GitHub sources) come back with
# owner/repo = null and nix-upgrade's discover subcommand skips them.
{
  flakePath,
  system,
}: let
  flake = builtins.getFlake "path:${flakePath}";
  pkgs = flake.packages.${system} or {};

  githubUrlRegex = "https://github\\.com/([^/]+)/([^/]+)/.*";

  urlOf = pkg:
    if !(pkg ? src)
    then null
    else if pkg.src ? url
    then pkg.src.url
    else if pkg.src ? urls && pkg.src.urls != []
    then builtins.head pkg.src.urls
    else null;

  ownerRepoOf = pkg: let
    url = urlOf pkg;
    matchEval = builtins.tryEval (
      if url == null
      then null
      else builtins.match githubUrlRegex url
    );
    m =
      if matchEval.success
      then matchEval.value
      else null;
  in
    if m == null
    then {
      owner = null;
      repo = null;
    }
    else {
      owner = builtins.elemAt m 0;
      repo = builtins.elemAt m 1;
    };

  entryOf = name: let
    pkg = pkgs.${name};
    versionEval = builtins.tryEval (pkg.version or null);
    version =
      if versionEval.success
      then versionEval.value
      else null;
    ownerRepo = ownerRepoOf pkg;
  in {
    inherit name version;
    inherit (ownerRepo) owner repo;
  };
in
  map entryOf (builtins.attrNames pkgs)

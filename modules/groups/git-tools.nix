# Git and the tools built around it.
#
# A group is only a bundle: it imports its tools and nothing else. Take the
# group for all of them, or import the individual tools you want. Either
# way, drop any one of them again with `tools.<name>.enable = false`.
{
  imports = [
    ../tools/git
    ../tools/delta
    ../tools/lazygit
    ../tools/gpg
    ../tools/tig
    ../tools/hunk
  ];
}

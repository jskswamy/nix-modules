# General command-line tools used by shell/editor integrations.
#
# A group is only a bundle: it imports its tools and nothing else. Take the
# group for all of them, or import the individual tools you want. Either
# way, drop any one of them again with `tools.<name>.enable = false`.
{
  imports = [
    ../tools/eza
    ../tools/bat
    ../tools/fd
    ../tools/ripgrep
    ../tools/fzf
    ../tools/zoxide
    ../tools/jump
    ../tools/any-nix-shell
  ];
}

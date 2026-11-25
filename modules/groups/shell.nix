# Interactive shell: fish (the daily driver), zsh, prompt (starship / oh-my-posh), direnv.
#
# A group is only a bundle: it imports its tools and nothing else. Take the
# group for all of them, or import the individual tools you want. Either
# way, drop any one of them again with `tools.<name>.enable = false`, or
# pick the active prompt engine with `shell.prompt`.
{
  imports = [
    ../tools/fish
    ../tools/zsh
    ../tools/starship
    ../tools/oh-my-posh
    ../tools/direnv
  ];
}

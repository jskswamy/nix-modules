# Tooling for AI coding agents.
#
# A group is only a bundle: it imports its tools and nothing else. Take the
# group for all of them, or import the individual tools you want. Either
# way, drop any one of them again with `tools.<name>.enable = false`.
{
  imports = [
    ../tools/herdr
    ../tools/ccstatusline
    ../tools/beads
    ../tools/fabric
    ../tools/pet
    ../tools/aide
  ];
}

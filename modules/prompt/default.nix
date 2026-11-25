# The active interactive prompt engine shared across shell tools.
#
# Each prompt tool module (`tools.starship`, `tools.oh-my-posh`) reads
# `config.shell.prompt` to default its own `enable` flag, so switching
# between prompt engines is a single-line change in the consumer flake.
{lib, ...}: {
  options.shell.prompt = lib.mkOption {
    type = lib.types.enum ["starship" "oh-my-posh"];
    default = "starship";
    example = "oh-my-posh";
    description = ''
      Active PS1 prompt engine for interactive shells.

      Tool modules in the `shell` group default their own `enable` flags
      from this option so only one prompt engine is active at a time.
    '';
  };
}

# The one cross-cutting value shared by every themeable tool.
#
# Each tool module reads `config.theme.variant` and maps it to its own
# settings — Ghostty's capitalized built-in theme names, Alacritty's
# colorscheme file, nvim's colorscheme call, herdr's dark_name/light_name.
# Every tool still owns *how* it maps the variant; it just stops
# hardcoding *which* variant. Switching themes stays a one-line change.
{lib, ...}: {
  options.theme.variant = lib.mkOption {
    type = lib.types.str;
    default = "gruvbox";
    example = "catppuccin";
    description = ''
      Base colour-scheme name, lowercase, without a light/dark suffix.

      Tools that ship light and dark pairs derive both from this name, so
      they follow the terminal's own light/dark switch rather than being
      pinned to one side.
    '';
  };
}

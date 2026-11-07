# Merino, Rex terminal's default theme pair, so other terminals match it.
# Copied from Rex's themes.json; it is GitHub Primer's Default palette with
# softer yellows (3, 11) and a lighter cursor text.
# `ansi` is the 16 terminal colours, 0-7 normal then 8-15 bright.
{
  dark = {
    background = "#0d1117";
    foreground = "#e6edf3";
    cursor = "#2f81f7";
    cursorText = "#eff8ff";
    selectionBackground = "#e6edf3";
    selectionForeground = "#0d1117";
    ansi = [
      "#484f58" "#ff7b72" "#3fb950" "#d29922" "#58a6ff" "#bc8cff" "#39c5cf" "#b1bac4"
      "#6e7681" "#ffa198" "#56d364" "#e3b341" "#79c0ff" "#d2a8ff" "#56d4dd" "#ffffff"
    ];
  };
  light = {
    background = "#ffffff";
    foreground = "#1f2328";
    cursor = "#0969da";
    cursorText = "#b6d8ff";
    selectionBackground = "#1f2328";
    selectionForeground = "#ffffff";
    ansi = [
      "#24292f" "#cf222e" "#116329" "#9d5c00" "#0969da" "#8250df" "#1b7c83" "#6e7781"
      "#57606a" "#a40e26" "#1a7f37" "#c47a00" "#218bff" "#a475f9" "#3192aa" "#8c959f"
    ];
  };
}

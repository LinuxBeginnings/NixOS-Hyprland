{ pkgs, ... }:
{
  home.packages = [ pkgs.micro ];

  # Catppuccin Mocha theme for micro
  home.file.".config/micro/colorschemes/catppuccin-mocha.micro".text = ''
    color-link default "#cdd6f4,#1e1e2e"
    color-link comment "#9399b2"
    color-link selection "#cdd6f4,#45475a"
    color-link hlsearch "#94e2d5"

    color-link identifier "#89b4fa"
    color-link identifier.class "#89b4fa"
    color-link identifier.var "#89b4fa"

    color-link constant "#fab387"
    color-link constant.number "#fab387"
    color-link constant.string "#a6e3a1"

    color-link symbol "#f5c2e7"
    color-link symbol.brackets "#f2cdcd"
    color-link symbol.tag "#89b4fa"

    color-link type "#89b4fa"
    color-link type.keyword "#f9e2af"

    color-link special "#f5c2e7"
    color-link statement "#cba6f7"
    color-link preproc "#f5c2e7"

    color-link underlined "#89dceb"
    color-link error "bold #f38ba8"
    color-link todo "bold #f9e2af"

    color-link diff-added "#a6e3a1"
    color-link diff-modified "#f9e2af"
    color-link diff-deleted "#f38ba8"

    color-link gutter-error "#f38ba8"
    color-link gutter-warning "#f9e2af"

    color-link scrollbar "#9399b2"
    color-link statusline "#cdd6f4,#45475a"
    color-link tabbar "#cdd6f4,#181825"
    color-link indent-char "#45475a"
    color-link line-number "#45475a"
    color-link current-line-number "#b4befe"

    color-link cursor-line "#313244,#cdd6f4"
    color-link color-column "#313244"
    color-link type.extended "default"
  '';

  # Visual, usability, and per-language options
  home.file.".config/micro/settings.json".text = builtins.toJSON {
    colorscheme = "catppuccin-mocha";
    number = true;
    cursorline = true;
    hlsearch = true;
    incsearch = true;
    matchbrace = true;
    scrollbar = true;
    colorcolumn = 100;

    softwrap = true;
    tabsize = 4;
    tabstospaces = true;
    autoindent = true;
    rmtrailingws = true;
    savecursor = true;

    ftoptions = {
      json = {
        tabsize = 2;
        tabstospaces = true;
      };
      yaml = {
        tabsize = 2;
        tabstospaces = true;
      };
      html = {
        tabsize = 2;
        tabstospaces = true;
      };
      css = {
        tabsize = 2;
        tabstospaces = true;
      };
      javascript = {
        tabsize = 2;
        tabstospaces = true;
      };
      nix = {
        tabsize = 2;
        tabstospaces = true;
      };
      c = {
        tabsize = 4;
        tabstospaces = true;
      };
      sh = {
        tabsize = 2;
        tabstospaces = true;
      };
    };
  };
}

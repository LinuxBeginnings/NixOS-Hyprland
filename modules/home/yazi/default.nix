{...}: {
  home.file.".config/yazi" = {
    source = ./yazi-src;
    recursive = true;
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    shellWrapperName = "yy";
  };
}

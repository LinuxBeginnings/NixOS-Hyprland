{ ... }:
{
  imports = [
    ./terminals/tmux.nix
    #./terminals/ghostty.nix
    ./editors/nixvim.nix
    ./editors/micro.nix
    ./editors/nano.nix
    ./cli/bat.nix
    ./cli/btop.nix
    ./cli/bottom.nix
    ./cli/eza.nix
    ./cli/fzf.nix
    ./cli/git.nix
    ./cli/htop.nix
    ./cli/tealdeer.nix
    ./yazi
    ./overview.nix
    #experimenting with getting dark to work
    # If set here it will break KoolDots theming
    # ./gtk.nix 
  ];
}

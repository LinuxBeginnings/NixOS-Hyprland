{pkgs, ...}: {
  # Ensure nano is installed for the user
  home.packages = [pkgs.nano];

  # Manage ~/.nanorc with a Catppuccin-like dark UI and sensible defaults
  home.file.".nanorc".text = ''
    # Syntax highlighting files from NixOS path
    include /run/current-system/sw/share/nano/*.nanorc

    # Navigation
    set linenumbers
    unset jumpyscrolling
    set mouse
    set constantshow

    # Editing Assistance
    set softwrap
    set tabsize 4
    set tabstospaces
    set autoindent
    set backup
    set whitespace "»·"
    set matchbrackets "(<[{)>]}"

    # Search and Replace
    unset casesensitive

    # File Management
    set locking
    set multibuffer

    # Interface (Catppuccin-like dark)
    set titlecolor white,brightblack
    set statuscolor white,brightblack
    set errorcolor white,brightblack
    set selectedcolor white,brightblack
    set numbercolor brightblack
    set keycolor blue
    set functioncolor magenta
    set promptcolor white,brightblack

    # Key bindings
    bind ^S savefile main
  '';
}

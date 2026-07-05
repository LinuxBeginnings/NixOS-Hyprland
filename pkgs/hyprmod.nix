{ lib, python3, gtk4, libadwaita, pkg-config, gobject-introspection, libcanberra-gtk3, wrapGAppsHook4, hyprmodSrc, hyprlandBindings }:
python3.pkgs.buildPythonApplication rec {
  pname = "hyprmod";
  version = "0.4.0";
  pyproject = true;

  src = hyprmodSrc;

  nativeBuildInputs = with python3.pkgs; [
    pkg-config
    gobject-introspection
    hatchling
  ] ++ [
    wrapGAppsHook4
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3
    hyprlandBindings.hyprland-config
    hyprlandBindings.hyprland-monitors
    hyprlandBindings.hyprland-schema
    hyprlandBindings.hyprland-socket
    hyprlandBindings.hyprland-state
  ];

  buildInputs = [
    gtk4
    libadwaita
    libcanberra-gtk3
  ];

  # GObject introspection requires these environment variables at build time
  postUnpack = ''
    # GTK4 and libadwaita typelibs for build phase
    export GI_TYPELIB_PATH="${gtk4}/lib/girepository-1.0:${libadwaita}/lib/girepository-1.0:$GI_TYPELIB_PATH"
  '';

  # Create desktop file for application launcher integration
  postInstall = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/hyprmod.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Hyprmod
Comment=Hyprland configuration manager
Exec=$out/bin/hyprmod
Icon=org.gnome.Settings
Categories=Utility;Settings;
Terminal=false
EOF
  '';

  # Hyprmod doesn't have tests in the main package currently
  doCheck = false;
  dontCheckRuntimeDeps = true;

  meta = with lib; {
    description = "A native GTK4/libadwaita settings app for Hyprland";
    homepage = "https://github.com/BlueManCZ/hyprmod";
    license = licenses.gpl3Plus;
    mainProgram = "hyprmod";
    platforms = platforms.linux;
    maintainers = [ maintainers.dwilliams ];
  };
}

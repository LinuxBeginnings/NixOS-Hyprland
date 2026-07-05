{ lib, python3, gtk4, libadwaita, pkg-config, gobject-introspection, libcanberra-gtk3, hyprmodSrc }:
python3.pkgs.buildPythonApplication rec {
  pname = "hyprmod";
  version = "0.4.0";
  pyproject = true;

  src = hyprmodSrc;

  nativeBuildInputs = [
    pkg-config
    gobject-introspection
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3
    # Hyprland-related Python packages; these may need to be added as overlays
    # if they are not in nixpkgs. For now, they are listed as placeholders:
    # hyprland-config
    # hyprland-schema
    # hyprland-state
    # hyprland-monitors
    # hyprland-socket
  ];

  buildInputs = [
    gtk4
    libadwaita
    libcanberra-gtk3
  ];

  # GObject introspection requires these environment variables at build time
  postUnpack = ''
    # GTK and GObject introspection expect these
    export GI_TYPELIB_PATH="${gtk4}/lib/girepository-1.0:${libadwaita}/lib/girepository-1.0:$GI_TYPELIB_PATH"
  '';

  # Ensure the app can find GTK libraries at runtime
  postInstall = ''
    wrapProgram $out/bin/hyprmod \
      --prefix GI_TYPELIB_PATH : "${gtk4}/lib/girepository-1.0:${libadwaita}/lib/girepository-1.0"
  '';

  # Hyprmod doesn't have tests in the main package currently
  doCheck = false;

  meta = with lib; {
    description = "A native GTK4/libadwaita settings app for Hyprland";
    homepage = "https://github.com/BlueManCZ/hyprmod";
    license = licenses.gpl3Plus;
    mainProgram = "hyprmod";
    platforms = platforms.linux;
    maintainers = [ maintainers.dwilliams ];
  };
}

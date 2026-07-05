{ python3Packages, fetchPypi, lib }:

let
  mkHyprlandBinding = { pname, version, hash }:
    python3Packages.buildPythonPackage {
      inherit pname version;
      pyproject = true;
      
      src = fetchPypi {
        inherit pname version hash;
      };
      
      nativeBuildInputs = with python3Packages; [
        setuptools
        wheel
      ];
      
      doCheck = false;
      
      meta = with lib; {
        description = "Hyprland Python binding: ${pname}";
        homepage = "https://github.com/BlueManCZ/${pname}";
        license = licenses.mit;
      };
    };
in
{
  # Known working versions (confirmed to have sdist on PyPI)
  hyprland-config = mkHyprlandBinding {
    pname = "hyprland-config";
    version = "0.6.0";
    hash = lib.fakeHash;  # Build will show correct hash
  };
  
  hyprland-monitors = mkHyprlandBinding {
    pname = "hyprland-monitors";
    version = "0.6.0";
    hash = lib.fakeHash;
  };
  
  hyprland-schema = mkHyprlandBinding {
    pname = "hyprland-schema";
    version = "0.6.0";
    hash = lib.fakeHash;
  };
  
  hyprland-socket = mkHyprlandBinding {
    pname = "hyprland-socket";
    version = "0.12.0";
    hash = lib.fakeHash;
  };
  
  hyprland-state = mkHyprlandBinding {
    pname = "hyprland-state";
    version = "0.4.0";
    hash = lib.fakeHash;
  };
}

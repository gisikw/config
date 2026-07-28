{ config, pkgs, ... }:

# peck: push-to-toggle dictation (see peck.py). Parakeet runs locally via
# MLX; the model (~600MB) is fetched from huggingface on first launch.
#
# macOS will prompt for Microphone and Accessibility on first use — and
# again whenever the python environment's store path changes, since TCC
# can't identify an unsigned binary across updates.

let
  # nixpkgs builds mlx without its Metal backend (no Metal shader compiler
  # in the build sandbox), and parakeet-mlx's streaming path hard-requires
  # Metal kernels — so mlx comes from the official PyPI wheels instead.
  # Upstream splits the native backend into an mlx-metal wheel that shares
  # the mlx/ directory; both are merged here so @loader_path resolves.
  mlx-metal-wheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/dc/59/65d32520175379df33f107749193aa94ea9db069167a36a1a100ff689f62/mlx_metal-0.32.0-py3-none-macosx_26_0_arm64.whl";
    hash = "sha256-OvdqSY2EgE9mEZgASZ+dFD19/7CHig3Q18KEblhWX9c=";
  };

  mlx = pkgs.python3Packages.buildPythonPackage {
    pname = "mlx";
    version = "0.32.0";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/4c/a8/7bc999ce5d09dfac8961dcda4ed47e173fca2857492f34599b237380f20d/mlx-0.32.0-cp313-cp313-macosx_26_0_arm64.whl";
      hash = "sha256-QZKi0CAUoTpqEDC/E9+05P4F7D/6R2eO432ikRHiXLE=";
    };
    pythonRemoveDeps = [ "mlx-metal" ]; # provided by the merge below
    nativeBuildInputs = [ pkgs.unzip ];
    postInstall = ''
      unzip -o ${mlx-metal-wheel} -d $out/${pkgs.python3.sitePackages}
    '';
  };

  parakeet-mlx = pkgs.python3Packages.buildPythonPackage rec {
    pname = "parakeet-mlx";
    version = "0.5.2";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "parakeet_mlx";
      inherit version;
      hash = "sha256-bGujxNQuvwFd3lFeWoOFilFq3T9bLGvUp75cS6i9TQI=";
    };

    build-system = [ pkgs.python3Packages.setuptools ];

    # nixpkgs is at dacite 1.9.1; upstream pins >=1.9.2 for no visible reason.
    pythonRelaxDeps = [ "dacite" ];

    dependencies = with pkgs.python3Packages; [
      dacite
      huggingface-hub
      librosa
      numpy
      typer
    ] ++ [ mlx ];

    # The sdist ships no tests.
    doCheck = false;
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    parakeet-mlx
    ps.rumps
    ps.sounddevice
    ps.pyobjc-framework-Quartz
  ]);

  peck = pkgs.writeShellScriptBin "peck" ''
    exec ${pythonEnv}/bin/python ${./peck.py} "$@"
  '';
in
{
  home.packages = [ peck ];

  launchd.agents.peck = {
    enable = true;
    config = {
      ProgramArguments = [ "${peck}/bin/peck" ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        PECK_KEY_CODE = "115"; # Home, matching the old OpenWhispr binding
        PECK_KEY_LABEL = "Home";
        PECK_MOD_FLAGS = "0";
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/peck.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/peck.log";
    };
  };
}

{
  pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
  },
}:
pkgs.mkShell rec {
  ANDROID_SDK_ROOT = "/home/tau2c/Android/Sdk";
  buildInputs = with pkgs; [
    flutter
    android-studio
    android-tools
    jdk17
    cmake
    ninja

    pkg-config

    rustup
    cargo-expand
    # rustc
    # cargo
    vscode-extensions.rust-lang.rust-analyzer

    # zlib
    # openssl
    gtk3
    
    sqlite
    # libsecret

    nixfmt-rfc-style

    sqlite-web

    python312
    poetry

    nodejs
  ];

  shellHook = ''
    export PATH="$HOME/.cargo/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:build/linux/x64/debug/bundle/lib:$LD_LIBRARY_PATH"
    poetry config virtualenvs.in-project true
    poetry install
  '';
}

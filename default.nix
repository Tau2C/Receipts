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
    # cargo-expand

    sqlite
    sqlite-web
    sqlx-cli
    dotenv-cli

    strictdoc

    openscad

    bruno
  ];

  shellHook = ''
    export PATH="$HOME/.cargo/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:build/linux/x64/debug/bundle/lib:$LD_LIBRARY_PATH"
    export DATABASE_URL="sqlite:////home/tau2c/Projects/receipts/receipts/receipts.db"
  '';
}

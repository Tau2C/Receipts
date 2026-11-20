{
  pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
    overlays = [
      (import (fetchTarball {
        url = "https://github.com/oxalica/rust-overlay/archive/c85ccd343087c57da6021cafa1647142ad03e32e.tar.gz";
        sha256 = "sha256:0irpfh3g1gbhw9mcvlh38nvy1kfxbad0rgdm92ny8mvddh8f6wxw";
      }))
    ];
  },
}:
with pkgs;
mkShell {
  ANDROID_SDK_ROOT = "/home/tau2c/Android/Sdk";
  packages = [
    (rust-bin.stable.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
        "rustfmt"
      ];
    })

    jdk17
    cmake
    ninja
    android-tools
    android-studio
    flutter
    flutter_rust_bridge_codegen
    cargo-expand

    gh
  ];
  # shellHook = ''
  #   export PATH=$ANDROID_SDK_ROOT/platform-tools:$PATH
  #   export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:~/.cargo/bin:build/linux/x64/debug/bundle/lib
  # '';
}

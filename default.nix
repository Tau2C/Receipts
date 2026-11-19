{
  pkgs ? import <nixpkgs> {
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
  packages = [
    (rust-bin.stable.latest.default.override {
      extensions = [
        "rust-src"
        "rust-analyzer"
        "rustfmt"
      ];
    })
    flutter
    flutter_rust_bridge_codegen
    gh
  ];
}


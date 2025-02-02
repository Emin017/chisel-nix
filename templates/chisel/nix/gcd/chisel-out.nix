{ lib
, stdenv
, fetchMillDeps
, publishMillModule
, git
}:
let
  chisel =
    publishMillModule {
      name = "chisel";
      version = "9999";
      outputHash =
        if stdenv.hostPlatform.isDarwin then
          "sha256-wXDmafSEoJxg1mv6uleKtRDCuFuTdEt+FmiH6NO7anc="
        else
          "sha256-vmuJyLQrgAe2ffMNxzKKUygk4WGoxHjq0cR1o+wZ0u8=";
      publishPhase = "mill -i unipublish.publishLocal";
      nativeBuildInputs = [ git ];
    };

  self = stdenv.mkDerivation {
    name = "chisel-out";

    src = with lib.fileset;
      toSource {
        root = ./../..;
        fileset = unions [
          ./../../build.mill
          ./../../common.mill
          ./../../gcd
          ./../../elaborator
        ];
      };
    # We need to find why the chisel publishLocal outputHash is different on different platforms
    installPhase = ''
      mkdir -p $out/chisel

      cp -r ${chisel}/ $out/chisel/
    '';

    buildInputs = [ chisel ];
  };
in
self

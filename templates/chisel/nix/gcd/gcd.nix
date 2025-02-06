# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2024 Jiuyang Liu <liu@jiuyang.me>

{ lib
, stdenv
, fetchMillDeps
, publishMillModule
, makeWrapper
, jdk21
, git

  # chisel deps
, mill
, espresso
, circt-full
, jextract-21
, add-determinism

, target
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
          "sha256-fuPwXvcCne3bMGkgDHVQjKJfw23cq0PK6t4EuDkhsNM=";
      publishPhase = ''
        mill -i show unipublish.scalaCompilerClasspath
        mill -i unipublish.publishLocal
      '';
      nativeBuildInputs = [ git ];
    };

  self = stdenv.mkDerivation rec {
    name = "gcd";

    mainClass = "org.chipsalliance.gcd.elaborator.${target}Main";

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

    passthru = {
      millDeps = fetchMillDeps {
        inherit name;
        src = with lib.fileset;
          toSource {
            root = ./../..;
            fileset = unions [ ./../../build.mill ./../../common.mill ];
          };
        millDepModules = [ chisel ];
        millDepsHash =
          if stdenv.hostPlatform.isDarwin then
            "sha256-wS/f8e7DxQGtAypfK3SVI81N0BqTxaPCUKrm2AdUEXE="
          else
            "sha256-9AvcYRLklhFFVq6b2S1zjM60yZpW0ql27kBq6dHcBQ0=";
        preparePhase = ''
          mill -i __.prepareOffline
          mill -i __.scalaCompilerClasspath
        '';
      };

      editable = self.overrideAttrs (_: {
        shellHook = ''
          setupSubmodulesEditable
          mill mill.bsp.BSP/install 0
        '';
      });

      inherit target;
      inherit env;
    };

    shellHook = ''
      setupSubmodules
    '';

    nativeBuildInputs = [
      mill
      circt-full
      jextract-21
      add-determinism
      espresso
      git

      makeWrapper
      passthru.millDeps.setupHook
    ];

    env = {
      CIRCT_INSTALL_PATH = circt-full;
      JEXTRACT_INSTALL_PATH = jextract-21;
    };

    outputs = [ "out" "elaborator" ];

    meta.mainProgram = "elaborator";

    buildPhase = ''
      mill -i '__.assembly'
    '';

    installPhase = ''
      mkdir -p $out/share/java

      add-determinism -j $NIX_BUILD_CORES out/elaborator/assembly.dest/out.jar

      mv out/elaborator/assembly.dest/out.jar $out/share/java/elaborator.jar

      mkdir -p $elaborator/bin
      makeWrapper ${jdk21}/bin/java $elaborator/bin/elaborator \
        --add-flags "--enable-preview -Djava.library.path=${circt-full}/lib -cp $out/share/java/elaborator.jar ${mainClass}"
    '';
  };
in
self

{ pkgs
, stdenv
, mill
, add-determinism
, fetchMillDeps
, ...
}:
{ name
, version
, publishPhase
, ...
}@args:
let
  dependencies = pkgs.callPackage ./_sources/generated.nix { };
in
stdenv.mkDerivation rec {
  pname = name;
  src = dependencies.${name}.src;

  inherit version;

  passthru = {
    millDeps = fetchMillDeps {
      inherit name src;
      millDepsHash = "sha256-CToEgj/NP/nlBKUIf78pPHYvycI9sUtTds3+VMhqk+s=";
      preparePhase = ''
        mill -i unipublish.prepareOffline
        mill -i unipublish.scalaCompilerClasspath
        # mill -i mill.scalalib.ZincWorkerModule/scalalibClasspath
      '';
      publish = false;
    };
  };


  nativeBuildInputs = [
    mill
    passthru.millDeps.setupHook
  ] ++ (args.nativeBuildInputs or [ ]);

  impureEnvVars = [ "JAVA_OPTS" ];

  buildPhase = ''
    runHook preBuild

    copyMillCache

    echo "-Duser.home=$TMPDIR -Divy.home=$TMPDIR/ivy $JAVA_OPTS" | tr ' ' '\n' > mill-java-opts
    export MILL_JVM_OPTS_PATH=$PWD/mill-java-opts

    # Use "https://repo1.maven.org/maven2/" only to keep dependencies integrity
    # export COURSIER_REPOSITORIES="ivy2Local|central"

    ${publishPhase}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/.ivy2
    mv $TMPDIR/ivy/local $out/.ivy2/local

    export SOURCE_DATE_EPOCH=1669810380
    find $out -type f -name '*.jar' -exec '${add-determinism}/bin/add-determinism' -j "$NIX_BUILD_CORES" '{}' ';'

    # find the docs/*.jar file and remove them, cause they are not reproducible for now
    # find $out -type f -name 'chisel_2.13-javadoc.jar' -exec rm -f {} \;

    runHook postInstall
  '';
}

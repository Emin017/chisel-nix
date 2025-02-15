# Chisel Nix

## Getting started

Here we provide nix templates for setting up a Chisel project.

```bash
mkdir my-shining-new-chip
cd my-shining-new-chip
git init
nix flake init -t github:chipsalliance/chisel-nix#chisel
```

Use the above commands to setup a chisel project skeleton.
It will provide you the below code structure:

* elaborator/: source code to the chisel elaborator
* gcd/: source code for the [GCD](https://en.wikipedia.org/wiki/Greatest_common_divisor) example
* gcdemu/: source code for the DPI library
* configs/: default configurations for GCD and the testbench, which can be generated by elaborator
* nix/: nix build script for the whole lowering process
* build.mill & common.mill: Scala build script
* flake.nix: the root for nix to search scripts

## Usage

Our packaging strategy is using the `overlay.nix` to "overlay" the nixpkgs.
Every thing that developers want to add or modify should go into the `overlay.nix` file.

This skeleton provides a simple [GCD](https://en.wikipedia.org/wiki/Greatest_common_divisor) example.
It's build script is in `nix/gcd` folder, providing the below attributes:

* {gcd,tb,formal}-compiled: JVM bytecode for the GCD/GCDTestbench and elaborator
* {gcd,tb,formal}-compiled.elaborator: A bash wrapper for running the elaborator with JDK
* [{tb,formal}-]elaborate: Unlowered MLIR bytecode output from firrtl elaborated by elaborator
* [{tb,formal}-]mlirbc: MLIR bytecode lowered by circt framework
* [{tb,formal}-]rtl: SystemVerilog generated from the lowered MLIR bytecode
* tb-dpi-lib: DPI library written in Rust for both Verilator and VCS
* verilated[-trace]: C++ simulation executable and libaray generated by Verilator with/without `fst` waveform trace
* vcs[-trace]: C simulation executable compiled by VCS with/without `fsdb` waveform trace and `urgReport` (coverage report) would be generated under `gcd-sim-result/result/`
* jg-fpv: Formal Property Verification report generated by JasperGold

To get the corresponding output, developers can use:

```bash
nix build '.#gcd.<attr>'
```

For instance, if developers wish to obtain the final lowered SystemVerilog, they can execute:

```bash
nix build '.#gcd.rtl'
```

The build result will be a symlink to nix store placed under the `./result`.

To have same environment as the build script for developing purpose, developer can use:

```bash
nix develop '.#gcd.<attr>'
```

For example, to modify the GCD sources, developer might run:

```bash
nix develop '.#gcd.gcd-compiled'
```

The above command will provide a new bash shell with `mill`, `circt`, `chisel`... dependencies set up.

Certain attributes support direct execution via Nix, allowing arguments to be passed using `--`:

```bash
nix run '.#gcd.<attr>'
```

For example, we use elaborator to generate configs for the design. To generate the config for GCDTestbench, developer can run:

```bash
nix run '.#gcd.gcd-compiled.elaborator' -- config --width 16 --useAsyncReset false
```

A JSON file named `GCDMain.json` will be generated in the working directory.

As another example, we can run a VCS simulation with waveform trace by:

```bash
nix run '.#gcd.vcs-trace' --impure -- +dump-start=0 +dump-end=10000 +wave-path=trace +fsdb+sva_success
```

The DPI lib can automatically match the arguments and does not interact with VCS. In this case, the first three parameters will be passed to the DPI lib to control waveform generation, and the last parameter will be passed to the VCS to dump the results of all sva statements.

* Note that in order to use VCS for simulation, you need to set the environment variables `VC_STATIC_HOME` and `SNPSLMD_LICENSE_FILE` and add the`--impure` flag.

To run the formal property verification. Then you can run:

```bash
nix build '.#gcd.jg-fpv' --impure
```

and the report will be generated in the result/

* Note that in order to use jasper gold for formal verification, you need to set the environment variables `JASPER_HOME` and `CDS_LIC_FILE` and add the`--impure` flag.

## References

### Format the source code

To format the Nix code, developers can run:

```bash
nix fmt
```

To format the Rust code, developers can run following command in `gcdemu/`:

```bash
nix develop -c cargo fmt
```

To format the Scala code, developers can run:

```bash
nix develop -c bash -c 'mill -i gcd.reformat && mill -i elaborator.reformat'
```

### Bump dependencies

To bump nixpkgs, run:

```bash
nix flake update 
```

To bump Chisel and other dependencies fetched by nvfetcher, run:

```bash
cd nix/pkgs/dependencies
nix run '.#nvfetcher'
```

To bump mill dependencies, run:

```bash
nix build '.#gcd.gcd-compiled.millDeps' --rebuild
```

and Then update `millDepsHash` in `nix/pkgs/dependencies/default.nix` and `nix/gcd/gcd.nix`

### Use the fetchMillDeps function

Fetch project dependencies for later offline usage.

The `fetchMillDeps` function accept three args: `name`, `src`, `millDepsHash`:

* name: name of the mill dependencies derivation, suggest using `<module>-mill-deps` as suffix.
* src: path to a directory that contains at least `build.mill` file for mill to obtain dependencies.
* millDepsHash: same functionality as the `sha256`, `hash` attr in stdenv.mkDerivation. To obtain new hash for new dependencies, replace the old hash with empty string, and let nix figure the new hash.

This derivation will read `$JAVA_OPTS` environment varialble, to set http proxy, you can export:

```bash
export JAVA_OPTS="-Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=1234"
```

The returning derivation have `setupHook` attribute to automatically setup dependencies path for mill.
Add the attribute into `nativeBuildInputs`, and let nix run the hook.

Example:

```nix
stdenv.mkDerivation rec {
    # ...
    passthru = {
      millDeps = fetchMillDeps {
        inherit name;
        src = with lib.fileset;
          toSource {
            root = ./../..;
            fileset = unions [ ./../../build.mill ./../../common.mill ];
          };
        buildInputs = with mill-dependencies; [ chisel.setupHook ];
        millDepsHash = "sha256-NybS2AXRQtXkgHd5nH4Ltq3sxZr5aZ4VepiT79o1AWo=";
      };
    };
    # ...
    nativeBuildInputs = [
        # ...
        millDeps.setupHook
    ];
}
```

## License

The build system is released under the Apache-2.0 license, including all Nix and mill build system, All rights reserved by Jiuyang Liu <liu@Jiuyang.me>

# Overlays

chisel-nix also provides some overlays file that contains common use nix script to help reduce copy-pasting.

## `mill-flows`

The `mill-flows` overlay provide a set of tools to control dependencies in a Mill based project.
Users can add "chisel-nix" to the Nix Flake input to use this overlay.

* An example `mill-flows` import example

```nix
{
  description = "Basic Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    chisel-nix.url = "github:chipsalliance/chisel-nix";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, chisel-nix, flake-utils }@inputs:
    flake-utils.lib.eachDefaultSystem (system: {
      legacyPackages = import nixpkgs {
        overlays = [ chisel-nix.overlays.mill-flows ];
        inherit system;
      };
    }) // { inherit inputs; };
}
```

After importing the `mill-flows` overlay to nixpkgs, users wil have following build script:

### `fetchMillDeps`

The `fetchMillDeps` function will run `mill -i __.prepareOffline` to fetch all the ivy dependencies from internet,
and provide a `setupHook` attribute to help reuse all the dependencies in other derivations.

* Type

```nix
{ name :: String; src :: Path; millDepsHash :: String; ... } -> Derivation
```

> This function accept additional attibutes to override the attibute set to be passed to
> `stdenv.mkDerivation` function.

* Example

```nix
{ fetchFromGitHub, fetchMillDeps }:
let
  chiselSrc = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "chisel";
    rev = "8a1f1b66e5e87dff6c8356fae346eb46512756cf";
    hash = "sha256-pB8kzqUmvHTG2FqRRjqig1FK9pGYrgBDOOekCqkwrsE=";
  };
in
fetchMillDeps {
  name = "chisel";
  src = chiselSrc;
  millDepsHash = "sha256-NBHUq5MaGiiaDA5mjeP0xcU5jNe9wWordL01a6khy7I=";
};
```

In the above example, `fetchMillDeps` function will resolve all ivy dependencies in chisel project,
return a path to the local coursier repository, and calculate file hash from the returning path.
Users can use the `.setupHook` function in other derivation's `buildInputs` to have coursier repository
automatically setup in build environment.

```nix
# ...
stdenv.mkDerivation {
    # ...

    buildInputs = [
      chisel.setupHook
      # ...
    ];

    buildPhase = ''
      # ...
      # No need to download dependency again
      mill -i obj.assembly
    '';
}
```

### `publishMillJar`

The `publishMillJar` function will run `mill -i $target.publishLocal` to pack up the given module.

* Type

```nix
{ name :: String; src :: Path; publishTargets :: [String]; ... } -> Derivation
```

> This function accept additional attibutes to override the attibute set to be passed to
> `stdenv.mkDerivation` function.

* Example

```nix
{ fetchMillDeps
, publishMillJar
, fetchFromGitHub
, git
}:
let
  chiselSrc = fetchFromGitHub {
    owner = "chipsalliance";
    repo = "chisel";
    rev = "8a1f1b66e5e87dff6c8356fae346eb46512756cf";
    hash = "sha256-pB8kzqUmvHTG2FqRRjqig1FK9pGYrgBDOOekCqkwrsE=";
  };
  chiselDeps = fetchMillDeps {
    name = "chisel";
    src = chiselSrc;
    millDepsHash = "sha256-NBHUq5MaGiiaDA5mjeP0xcU5jNe9wWordL01a6khy7I=";
  };
in
publishMillJar {
  name = "chisel";
  src = chiselSrc;

  publishTargets = [
    "unipublish"
  ];

  buildInputs = [
    chiselDeps.setupHook
  ];

  nativeBuildInputs = [
    # chisel requires git to generate version
    git
  ];

  passthru = {
    inherit chiselDeps;
  };
}
```

The above declaration will run `mill -i unipublish.publishLocal` command and store the ivy repository
to output directory. And it also provide a `setupHook` attribute, so users can have the ivy repository
automatically installed in other derivation build environment.

> [!note]
>
> Worth notice that, if user pass other ivy repository to the `publishMillJar` builder,
> the old and new ivy repository will be merged and output JAR will be stored together.
> These will cause the output size increse and larger than expected for those top-level project.

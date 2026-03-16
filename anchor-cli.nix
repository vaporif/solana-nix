{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  openssl,
  perl,
  udev,
  makeWrapper,
  writeShellScriptBin,
  symlinkJoin,
  rust-bin,
  crane,
  solana-platform-tools,
  solana-rust,
  anchorVersion ? "0.32.1",
}: let
  versions = {
    "0.32.1" = {
      src = {
        owner = "solana-foundation";
        repo = "anchor";
        tag = "v0.32.1";
        hash = "sha256-oyCe8STDciRtdhOWgJrT+k50HhUWL2LSG8m4Ewnu2dc=";
        fetchSubmodules = true;
      };
      rustStable = "1.86.0";
      rustIdl = rust-bin.stable."1.89.0".minimal.override {
        extensions = ["rust-src"];
      };
      patches = [./patches/anchor-cli/0.32.1.patch];
    };
    "0.31.1" = {
      src = {
        owner = "coral-xyz";
        repo = "anchor";
        tag = "v0.31.1";
        hash = "sha256-c+UybdZCFL40TNvxn0PHR1ch7VPhhJFDSIScetRpS3o=";
        fetchSubmodules = false;
      };
      rustStable = "1.85.0";
      rustIdl = rust-bin.nightly.latest.default;
      patches = [./patches/anchor-cli/0.31.1.patch];
    };
    "0.31.0" = {
      src = {
        owner = "coral-xyz";
        repo = "anchor";
        tag = "v0.31.0";
        hash = "sha256-CaBVdp7RPVmzzEiVazjpDLJxEkIgy1BHCwdH2mYLbGM=";
        fetchSubmodules = false;
      };
      rustStable = "1.85.0";
      rustIdl = rust-bin.nightly.latest.default;
      patches = [./patches/anchor-cli/0.31.0.patch];
    };
    "0.30.1" = {
      src = {
        owner = "coral-xyz";
        repo = "anchor";
        tag = "v0.30.1";
        hash = "sha256-3fLYTJDVCJdi6o0Zd+hb9jcPDKm4M4NzpZ8EUVW/GVw=";
        fetchSubmodules = false;
      };
      rustStable = "1.78.0";
      rustIdl = rust-bin.nightly."2025-04-15".default;
      patches = [./patches/anchor-cli/0.30.1.patch];
    };
  };

  versionConfig = versions.${anchorVersion}
    or (throw "Unsupported Anchor version: ${anchorVersion}");

  rustStable = rust-bin.stable.${versionConfig.rustStable}.minimal.override {
    extensions = ["rust-src"];
  };

  craneLib = crane.overrideToolchain rustStable;

  originalSrc = fetchFromGitHub versionConfig.src;

  src =
    if versionConfig.patches == []
    then originalSrc
    else
      stdenv.mkDerivation {
        name = "anchor-cli-patched-${anchorVersion}";
        src = originalSrc;
        phases = ["unpackPhase" "patchPhase" "installPhase"];
        patches = versionConfig.patches;
        installPhase = ''
          mkdir -p $out
          cp -r ./* $out/
        '';
      };

  cargoShim = writeShellScriptBin "cargo" ''
    if [[ "''${1:-}" == +* ]]; then
      shift
      exec ''${_NIX_IDL_TOOLCHAIN}/bin/cargo "$@"
    fi
    exec ''${_NIX_STABLE_TOOLCHAIN}/bin/cargo "$@"
  '';

  commonArgs = {
    pname = "anchor-cli";
    version = anchorVersion;
    inherit src;
    strictDeps = true;

    cargoExtraArgs = "--bin=anchor";

    nativeBuildInputs = [perl pkg-config makeWrapper];
    buildInputs = [openssl] ++ lib.optionals stdenv.isLinux [udev];

    OPENSSL_NO_VENDOR = 1;
    doCheck = false;

    meta = {
      description = "Solana Anchor Framework CLI";
      homepage = "https://github.com/${versionConfig.src.owner}/${versionConfig.src.repo}";
      license = lib.licenses.asl20;
      mainProgram = "anchor";
    };
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  anchor-unwrapped = craneLib.buildPackage (commonArgs
    // {
      inherit cargoArtifacts;
    });
in
  symlinkJoin {
    name = "anchor-cli-${anchorVersion}";
    paths = [anchor-unwrapped];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/anchor \
        --prefix PATH : "${cargoShim}/bin" \
        --set _NIX_IDL_TOOLCHAIN "${versionConfig.rustIdl}" \
        --set _NIX_STABLE_TOOLCHAIN "${solana-rust}" \
        --set SBF_SDK_PATH "${solana-platform-tools.sbfSdk}"
    '';

    passthru.otherVersions = builtins.attrNames versions;
  }

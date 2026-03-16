{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libgcc,
  zlib,
}: let
  version = "v1.52";

  archives = {
    x86_64-darwin = {
      name = "platform-tools-osx-x86_64.tar.bz2";
      hash = "sha256-HdTysfe1MWwvGJjzfHXtSV7aoIMzM0kVP+lV5Wg3kdE=";
    };
    aarch64-darwin = {
      name = "platform-tools-osx-aarch64.tar.bz2";
      hash = "sha256-Fyffsx6DPOd30B5wy0s869JrN2vwnYBSfwJFfUz2/QA=";
    };
    x86_64-linux = {
      name = "platform-tools-linux-x86_64.tar.bz2";
      hash = "sha256-izhh6T2vCF7BK2XE+sN02b7EWHo94Whx2msIqwwdkH4=";
    };
    aarch64-linux = {
      name = "platform-tools-linux-aarch64.tar.bz2";
      hash = "sha256-sfhbLsR+9tUPZoPjUUv0apUmlQMVUXjN+0i9aUszH5g=";
    };
  };

  archive = archives.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  platformTools = stdenv.mkDerivation {
    pname = "solana-platform-tools";
    inherit version;
    src = fetchurl {
      url = "https://github.com/anza-xyz/platform-tools/releases/download/${version}/${archive.name}";
      inherit (archive) hash;
    };
    nativeBuildInputs = lib.optionals stdenv.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.isLinux [libgcc.lib zlib];
    unpackPhase = ''
      mkdir -p $out
      tar -xjf $src -C $out
      find $out -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    '';
    dontBuild = true;
    dontInstall = true;
  };

  sbfSdk = stdenv.mkDerivation {
    pname = "solana-sbf-sdk";
    version = "3.1.6";
    src = fetchurl {
      url = "https://github.com/anza-xyz/agave/releases/download/v3.1.6/sbf-sdk.tar.bz2";
      hash = "sha256-4iV6NhfisZuLlwwhIi4OIbxj8Nzx+EFcG5cmK36fFAc=";
    };
    unpackPhase = ''
      mkdir -p $out/dependencies
      tar -xjf $src -C $out
      ln -s ${platformTools} $out/dependencies/platform-tools
      [ -f "$out/sbf-sdk/env.sh" ] && ln -s $out/sbf-sdk/env.sh $out/env.sh || true
    '';
    dontBuild = true;
    dontInstall = true;
  };
in {
  inherit platformTools sbfSdk;
}

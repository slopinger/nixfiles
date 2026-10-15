{ inputs, stdenv }:
inputs.slop-landing.packages.${stdenv.hostPlatform.system}.slopd

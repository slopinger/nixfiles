{ inputs, stdenv }:
inputs.slop-landing.packages.${stdenv.hostPlatform.system}.site

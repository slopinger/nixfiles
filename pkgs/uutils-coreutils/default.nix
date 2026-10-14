# Rust coreutils as `uu-*` (like Arch's uutils-coreutils); GNU coreutils stay the default.
{ prev }:

prev.uutils-coreutils.override { prefix = "uu-"; }

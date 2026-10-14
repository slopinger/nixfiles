# Static files of https://freifick.net (the `site/` directory of slop-landing).
{ lib, stdenvNoCC, inputs }:

stdenvNoCC.mkDerivation {
  pname = "slop-landing";
  version = "0-unstable-${inputs.slop-landing.lastModifiedDate or "0"}";
  src = "${inputs.slop-landing}/site";

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  meta = {
    description = "freifick.net landing page";
    homepage = "https://git.freifick.net/slop/slop-landing";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}

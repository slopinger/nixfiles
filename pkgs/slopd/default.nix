# slopd: guestbook + visitor counter API behind freifick.net/api/* (Python stdlib + SQLite).
{ lib, stdenvNoCC, python3, inputs }:

stdenvNoCC.mkDerivation {
  pname = "slopd";
  version = "0-unstable-${inputs.slop-landing.lastModifiedDate or "0"}";
  src = "${inputs.slop-landing}/backend";

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 slopd.py $out/lib/slopd/slopd.py
    mkdir -p $out/bin
    cat > $out/bin/slopd <<EOS
    #!${stdenvNoCC.shell}
    exec ${lib.getExe python3} -I $out/lib/slopd/slopd.py "\$@"
    EOS
    chmod +x $out/bin/slopd
    runHook postInstall
  '';

  passthru.python = python3;

  meta = {
    description = "Guestbook and visitor counter backend for freifick.net";
    homepage = "https://git.freifick.net/slop/slop-landing";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "slopd";
  };
}

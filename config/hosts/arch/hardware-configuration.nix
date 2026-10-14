{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Intel Xeon E5-2695 v2 (KVM, nested virtualisation available)
  boot.kernelModules = [ "kvm-intel" ];
}

{ lib, pkgs, ... }: {

  freifick.machine-type.headless = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

  services.openssh.enable = lib.mkDefault true;
}

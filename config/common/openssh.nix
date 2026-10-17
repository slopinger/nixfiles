{ lib, ... }: {
  services.openssh = {
    enable = lib.mkDefault true;
    # Keep the host keys (and fingerprints) of the Arch install: same paths.
    hostKeys = [
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
      { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
      { type = "rsa"; bits = 3072; path = "/etc/ssh/ssh_host_rsa_key"; }
      # OpenSSH 10.6 post-quantum hybrid host key (Arch generated it with `ssh-keygen -A`)
      { type = "mldsa44-ed25519"; path = "/etc/ssh/ssh_host_mldsa44_ed25519_key"; }
    ];
    # /etc/ssh/sshd_config.d/10-hardening.conf
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}

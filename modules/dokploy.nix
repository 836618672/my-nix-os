{ pkgs, ... }:
{
  # NixOS manages Docker; Dokploy manages its own Swarm services and data.
  virtualisation.docker.enable = true;
  environment.systemPackages = [ pkgs.openssl ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 443 ];

  # Docker-published ports bypass the host INPUT firewall. Keep the initial
  # admin UI off the physical network; localhost SSH forwarding still works.
  systemd.services.docker.postStart = ''
    ${pkgs.iptables}/bin/iptables -C DOCKER-USER -i wlp3s0 -p tcp -m conntrack --ctorigdstport 3000 -j DROP 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -I DOCKER-USER 1 -i wlp3s0 -p tcp -m conntrack --ctorigdstport 3000 -j DROP
  '';
}

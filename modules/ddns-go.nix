{ pkgs, ... }:
{
  systemd.services.ddns-go = {
    description = "DDNS-Go dynamic DNS updater";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.ddns-go}/bin/ddns-go -l 127.0.0.1:9876 -c /var/lib/ddns-go/config.yaml";
      Restart = "on-failure";
      RestartSec = 10;
      DynamicUser = true;
      StateDirectory = "ddns-go";
      StateDirectoryMode = "0700";
      UMask = "0077";
      NoNewPrivileges = true;
    };
  };
}

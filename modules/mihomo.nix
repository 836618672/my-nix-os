{ config, lib, pkgs, username, ... }:
let
  userHome = config.users.users.${username}.home;
  clientDir = "${userHome}/.config/clashtui";
  coreDir = "/var/lib/mihomo";

  # Public defaults only. Subscription URLs and proxy credentials stay on the host.
  baseConfig = ''
    mixed-port: 7890
    allow-lan: false
    bind-address: 127.0.0.1
    mode: rule
    log-level: info
    ipv6: true
    external-controller: 127.0.0.1:9090
    secret: ""
    find-process-mode: off
    profile:
      store-selected: true
    tun:
      enable: true
    dns:
      enable: false
  '';
  baseFile = pkgs.writeText "clashtui-basic.yaml" baseConfig;
  initialFile = pkgs.writeText "mihomo-initial.yaml" (baseConfig + ''
    proxies: []
    rules:
      - MATCH,DIRECT
  '');
  clientFile = pkgs.writeText "clashtui-config.yaml" ''
    basic:
      clash_config_dir: ${coreDir}
      clash_bin_path: ${lib.getExe pkgs.mihomo}
      clash_config_path: ${coreDir}/config.yaml
      timeout: 60
    service:
      clash_srv_name: mihomo
      is_user: false
    extra:
      edit_cmd: 'vim %s'
      open_dir_cmd: ""
  '';
in
{
  environment.systemPackages = [ pkgs.mihomo pkgs.clashtui ];

  users.groups.mihomo = { };
  users.users.mihomo = {
    isSystemUser = true;
    group = "mihomo";
  };
  users.users.${username}.extraGroups = [ "mihomo" ];
  networking.firewall = {
    trustedInterfaces = [ "Meta" ];
    checkReversePath = "loose";
  };

  services.mihomo = {
    enable = true;
    # A runtime string, not a Nix path that would copy secrets into the store.
    configFile = "${coreDir}/config.yaml";
    webui = pkgs.metacubexd;
    tunMode = true;
  };

  # Keep the upstream NixOS service hardening, but share mutable config with
  # ClashTUI. Loading a startup credential snapshot would prevent this workflow.
  systemd.services.mihomo.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "mihomo";
    Group = "mihomo";
    StateDirectoryMode = "2770";
    UMask = lib.mkForce "0007";
    LoadCredential = lib.mkForce [ ];
    ExecStart = lib.mkForce
      "${lib.getExe pkgs.mihomo} -d ${coreDir} -f ${coreDir}/config.yaml -ext-ui ${pkgs.metacubexd}";
    Restart = "on-failure";
    RestartSec = "5s";
  };

  # C copies only if absent: rebuilds preserve local subscriptions and settings.
  systemd.tmpfiles.rules = [
    "d ${coreDir} 2770 mihomo mihomo -"
    "C ${coreDir}/config.yaml 0660 mihomo mihomo - ${initialFile}"
    "d ${userHome}/.config 0700 ${username} users -"
    "d ${clientDir} 0700 ${username} mihomo -"
    "d ${clientDir}/profiles 0700 ${username} mihomo -"
    "d ${clientDir}/templates 0700 ${username} mihomo -"
    "C ${clientDir}/config.yaml 0600 ${username} mihomo - ${clientFile}"
    "C ${clientDir}/basic_clash_config.yaml 0600 ${username} mihomo - ${baseFile}"
  ];

  systemd.services.mihomo-subscription-update = {
    description = "Update subscriptions with upstream ClashTUI";
    wants = [ "network-online.target" "mihomo.service" ];
    after = [ "network-online.target" "mihomo.service" ];
    path = [ pkgs.bash pkgs.coreutils pkgs.systemd ];
    environment.HOME = userHome;
    serviceConfig = {
      Type = "oneshot";
      User = username;
      Group = "mihomo";
      UMask = "0007";
      ExecStart = "${lib.getExe pkgs.clashtui} -c ${clientDir} -u";
      TimeoutStartSec = "15min";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
  systemd.timers.mihomo-subscription-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,06,12,18:00:00";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };
  };
}

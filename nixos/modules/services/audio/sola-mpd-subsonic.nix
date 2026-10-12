{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sola-mpd-subsonic;
in
{
  options.services.sola-mpd-subsonic = {
    enable = lib.mkEnableOption "the Sola MPD Subsonic plugin server";
    package = lib.mkPackageOption pkgs "sola-mpd-subsonic" { };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Listening address for the plugin API. The API has no authentication;
        do not expose it to an untrusted network without an authenticated proxy.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "HTTP listening port.";
    };

    openFirewall = lib.mkEnableOption "opening the plugin HTTP port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.sola-mpd-subsonic = {
      description = "Sola MPD Subsonic plugin server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        HOST = cfg.listenAddress;
        PORT = toString cfg.port;
      };
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        DynamicUser = true;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };
}

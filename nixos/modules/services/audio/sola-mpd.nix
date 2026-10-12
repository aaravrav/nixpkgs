{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sola-mpd;
in
{
  options.services.sola-mpd = {
    enable = lib.mkEnableOption "the Sola MPD web application and MCP server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sola-mpd.override { desktopSupport = false; };
      defaultText = lib.literalExpression "pkgs.sola-mpd.override { desktopSupport = false; }";
      description = ''
        Package providing sola-mpd-server. For advanced search, override the
        package's lainbowEndpoint with an endpoint reachable by the server.
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address on which to serve the web application and the /mcp endpoint.
        Neither endpoint authenticates clients. Use an authenticated reverse
        proxy before exposing this service to an untrusted network.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP listening port.";
    };

    openFirewall = lib.mkEnableOption "opening the HTTP port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;

    systemd.services.sola-mpd = {
      description = "Sola MPD web application and MCP server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        HOST = cfg.listenAddress;
        PORT = toString cfg.port;
      };
      serviceConfig = {
        ExecStart = lib.getExe' cfg.package "sola-mpd-server";
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "sola-mpd";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/sola-mpd";
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

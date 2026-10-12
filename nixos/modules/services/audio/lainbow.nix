{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.lainbow;
  localAddress =
    address:
    if
      builtins.elem address [
        ""
        "0.0.0.0"
      ]
    then
      "127.0.0.1"
    else if address == "::" then
      "::1"
    else
      address;
  urlHost = address: if lib.hasInfix ":" address then "[${address}]" else address;
  needsDatabases = cfg.api.enable || cfg.worker.enable;
  localDatabases = cfg.localDatabases && needsDatabases;
  databaseUnits = lib.optionals localDatabases [
    "postgresql.service"
    "rabbitmq.service"
    "qdrant.service"
  ];
  mkServerOptions = name: port: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the Lainbow ${name}.";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Listening address. Lainbow does not authenticate HTTP clients;
        use an authenticated reverse proxy for access from untrusted networks.
      '';
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = port;
      description = "HTTP port for the ${name}.";
    };
  };
  mkService = role: command: {
    description = "Lainbow ${role}";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ] ++ lib.optionals (role != "inference") databaseUnits;
    requires = lib.optionals (role != "inference") databaseUnits;
    environment = {
      DATABASE_SERVER_ENDPOINT = "127.0.0.1";
      INFERENCE_API_URL = "http://${urlHost (localAddress cfg.inference.listenAddress)}:${toString cfg.inference.port}";
      MODELS_ROOT_DIR = cfg.modelsDirectory;
      HF_HOME = cfg.modelsDirectory;
      HF_HUB_OFFLINE = "1";
      TRANSFORMERS_OFFLINE = "1";
      HF_HUB_DISABLE_TELEMETRY = "1";
      HF_MODULES_CACHE = "/var/cache/lainbow/modules";
      XDG_CACHE_HOME = "/var/cache/lainbow";
      NUMBA_CACHE_DIR = "/var/cache/lainbow/numba";
      TORCH_HOME = "/var/cache/lainbow/torch";
    }
    // lib.optionalAttrs (cfg.musicDirectory != null) {
      MUSIC_NAS_ROOT_DIR = cfg.musicDirectory;
    }
    // lib.optionalAttrs localDatabases {
      DATABASE_SERVER_ENDPOINT = localAddress config.services.qdrant.settings.service.host;
      POSTGRES_URL = "postgresql+psycopg://lainbow@/lainbow?host=/run/postgresql";
      CELERY_BACKEND_URL = "db+postgresql://lainbow@/lainbow?host=/run/postgresql";
      RABBITMQ_URL = "amqp://guest:guest@${urlHost (localAddress config.services.rabbitmq.listenAddress)}:${toString config.services.rabbitmq.port}/";
      QDRANT_PORT_HTTP = toString (config.services.qdrant.settings.service.http_port or 6333);
    }
    // cfg.settings;
    serviceConfig = {
      ExecStart = command;
      Restart = "on-failure";
      User = "lainbow";
      Group = "lainbow";
      StateDirectory = "lainbow";
      StateDirectoryMode = "0750";
      WorkingDirectory = "/var/lib/lainbow";
      CacheDirectory = "lainbow";
      CacheDirectoryMode = "0750";
      UMask = "0027";
      NoNewPrivileges = true;
      PrivateTmp = true;
      # API and inference use the host's GPU when the package supports it.
      PrivateDevices = role == "worker";
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadOnlyPaths =
        lib.optional (role != "worker") cfg.modelsDirectory
        ++ lib.optional (role == "worker" && cfg.musicDirectory != null) cfg.musicDirectory;
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
    }
    // lib.optionalAttrs (cfg.environmentFile != null) {
      EnvironmentFile = cfg.environmentFile;
    };
  };
in
{
  options.services.lainbow = {
    enable = lib.mkEnableOption "Lainbow's native API, inference server and batch worker";
    package = lib.mkPackageOption pkgs "lainbow" { };

    musicDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/srv/music";
      description = ''
        Music library, readable by the lainbow user. Required for the batch worker.
        Relative music paths must match MPD's library paths.
      '';
    };

    modelsDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lainbow/models";
      description = ''
        Directory containing manually provisioned upstream models and Hugging Face
        caches, readable by the lainbow user. Models and tokenizers are never
        downloaded automatically. The API requires MuQ-MuLan before it can start.
      '';
    };

    localDatabases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Configure native PostgreSQL, RabbitMQ and Qdrant services on this host.
        PostgreSQL uses peer authentication; RabbitMQ uses its loopback-only guest
        account. Disable this to use externally managed databases and supply their
        connection settings through settings or environmentFile.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example.INFERENCE_MODEL_MANAGER_MODE = "multi";
      description = ''
        Additional upstream environment variables. Do not put passwords here:
        values are public in the Nix store. Use environmentFile for secrets.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/lainbow";
      description = "Environment file containing database credentials or other secrets.";
    };

    api = mkServerOptions "web API" 8000;
    inference = mkServerOptions "inference server" 8001;
    worker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run the batch worker.";
      };
      concurrency = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Number of concurrent Celery worker processes.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.worker.enable || cfg.musicDirectory != null;
        message = "services.lainbow.musicDirectory must be set when the batch worker is enabled.";
      }
    ];

    users.users.lainbow = {
      isSystemUser = true;
      group = "lainbow";
    };
    users.groups.lainbow = { };

    systemd.tmpfiles.rules = lib.optionals (cfg.modelsDirectory == "/var/lib/lainbow/models") [
      "d /var/lib/lainbow 0750 lainbow lainbow -"
      "d /var/lib/lainbow/models 0750 lainbow lainbow -"
    ];

    services = lib.mkIf localDatabases {
      postgresql = {
        enable = true;
        ensureDatabases = [ "lainbow" ];
        ensureUsers = [
          {
            name = "lainbow";
            ensureDBOwnership = true;
          }
        ];
      };
      rabbitmq.enable = true;
      qdrant.enable = true;
    };

    systemd.services = {
      lainbow-api = lib.mkIf cfg.api.enable (
        mkService "api" "${lib.getExe' cfg.package "lainbow-api"} --host ${lib.escapeShellArg cfg.api.listenAddress} --port ${toString cfg.api.port}"
      );
      lainbow-inference = lib.mkIf cfg.inference.enable (
        mkService "inference" "${lib.getExe' cfg.package "lainbow-inference"} --host ${lib.escapeShellArg cfg.inference.listenAddress} --port ${toString cfg.inference.port}"
      );
      lainbow-worker = lib.mkIf cfg.worker.enable (
        mkService "worker" "${lib.getExe' cfg.package "lainbow-worker"} --concurrency ${toString cfg.worker.concurrency} --queues cpu_queue --loglevel INFO"
      );
    };
  };
}

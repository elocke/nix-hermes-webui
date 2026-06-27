{ config, lib, pkgs, ... }:

let
  cfg = config.services.hermes-webui;
  effectiveUser  = if cfg.useHermesUser then "hermes" else cfg.user;
  effectiveGroup = if cfg.useHermesUser then "hermes" else cfg.group;
in
{
  options.services.hermes-webui = {
    enable = lib.mkEnableOption "hermes-webui — browser UI for Hermes Agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hermes-webui;
      defaultText = lib.literalExpression "pkgs.hermes-webui";
      description = "The hermes-webui package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "hermes-webui";
      description = ''
        User account under which hermes-webui runs. Created automatically
        when `useHermesUser` is false. Ignored when `useHermesUser = true`.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "hermes-webui";
      description = "Group under which hermes-webui runs.";
    };

    useHermesUser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run as the existing `hermes` system user (from the hermes-agent
        module). Required when hermes-webui needs to read
        /var/lib/hermes/.hermes and /var/lib/hermes/workspace owned by
        that user. When true, `user` and `group` are ignored and no new
        user is created.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address. Set to 0.0.0.0 to expose on LAN.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "TCP port to listen on.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hermes-webui";
      description = ''
        Directory for hermes-webui's own state (sessions, settings,
        projects). Exported as HERMES_WEBUI_STATE_DIR.
      '';
    };

    agentDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the Hermes Agent workspace (read by the file-browser
        panel). Exported as HERMES_WEBUI_AGENT_DIR when non-null;
        otherwise the app auto-discovers.
      '';
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the service unit.";
    };

    extraReadWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''[ "/var/lib/hermes" ]'';
      description = ''
        Additional paths appended to systemd's ReadWritePaths. Useful when
        hermes-webui spawns hermes-agent subprocesses (chat / kanban /
        spawn-agent panels do `import run_agent`), and those write outside
        the default stateDir — for example to /var/lib/hermes/.hermes/logs,
        /var/lib/hermes/.hermes/sessions, or /var/lib/hermes/workspace.
        Under ProtectSystem=strict, those writes hit EROFS without the
        whitelist. Typical co-located deployment:

          services.hermes-webui = {
            useHermesUser = true;
            extraReadWritePaths = [ "/var/lib/hermes" ];
          };
      '';
    };

    extraReadOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = lib.literalExpression ''[ "/srv/extra-skills" ]'';
      description = ''
        Additional paths appended to systemd's ReadOnlyPaths. The agent
        directory (`agentDir`) is already added automatically.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (!cfg.useHermesUser) {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.stateDir;
        createHome = false;
        description = "hermes-webui service user";
      };
    };

    users.groups = lib.mkIf (!cfg.useHermesUser) {
      ${cfg.group} = { };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${effectiveUser} ${effectiveGroup} - -"
    ];

    systemd.services.hermes-webui = {
      description = "hermes-webui — browser UI for Hermes Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ]
        ++ lib.optional (config.systemd.services ? hermes-agent) "hermes-agent.service";
      wants = [ "network-online.target" ];

      environment = {
        HERMES_WEBUI_HOST = cfg.host;
        HERMES_WEBUI_PORT = toString cfg.port;
        HERMES_WEBUI_STATE_DIR = toString cfg.stateDir;
        PYTHONDONTWRITEBYTECODE = "1";
        PYTHONUNBUFFERED = "1";
      } // lib.optionalAttrs (cfg.agentDir != null) {
        HERMES_WEBUI_AGENT_DIR = toString cfg.agentDir;
      } // cfg.extraEnv;

      serviceConfig = {
        Type = "simple";
        User = effectiveUser;
        Group = effectiveGroup;
        WorkingDirectory = toString cfg.stateDir;
        ExecStart = "${cfg.package}/bin/hermes-webui";
        Restart = "on-failure";
        RestartSec = 5;

        # Light hardening — keep ProtectHome=false because the hermes user's
        # state lives under /var/lib/hermes (not /home), but tmpfiles + an
        # explicit ReadWritePaths is still useful.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ (toString cfg.stateDir) ] ++ cfg.extraReadWritePaths;
        ReadOnlyPaths =
          (lib.optional (cfg.agentDir != null) (toString cfg.agentDir))
          ++ cfg.extraReadOnlyPaths;
        ProtectHome = false;
      };
    };
  };
}

{ config, pkgs, lib, options, ... }: let
  cfg = config.roos.btrbk;

  commonOpts = with lib; with types; {
    options.snapshot_dir = mkOption {
      description = "Where to create snapshots relative to the volume directory. Must exist.";
      type = nullOr str;
      default = null;
    };
    options.group = mkOption {
      description =
        "Add the current section to user-defined groups. Useful for filters";
      type = nullOr str;
      default = null;
    };
    options.timestamp_format = mkOption {
      description = "Timestamp format used as postfix for new subvolume names.";
      type = nullOr (enum [ "short" "long" "long-iso" ]);
      default = null;
    };
    options.snapshot_preserve = mkOption {
      description = "Schedule-based retention policy for snapshots. Defaults to no.";
      type = nullOr str;
      default = null;
    };
    options.snapshot_preserve_min = mkOption {
      description = "Time-based retention policy for snapshots. Defaults to all.";
      type = nullOr str;
      default = null;
    };
    options.target_preserve = mkOption {
      description = "Schedule-based retention policy for backups. Defaults to no.";
      type = nullOr str;
      default = null;
    };
    options.target_preserve_min = mkOption {
      description = "Time-based retention policy for backups. Defaults to all";
      type = nullOr str;
      default = null;
    };
    options.ssh_identity = mkOption {
      description = "Path to the private key to use when connecting via SSH.";
      type = nullOr path;
      default = null;
    };
    options.ssh_user = mkOption {
      description = "Remote username for connecting via SSH.";
      type = nullOr str;
      default = null;
    };

    # System options
    options.backend = mkOption {
      description = "Remote username for connecting via SSH.";
      type = nullOr (enum ["btrfs-progs" "btrfs-progs-btrbk" "btrfs-progs-sudo"]);
      default = null;
    };

    # List is incomplete to be expanded as needed...
  };

  volumeOpts = { name, ... }: with lib; recursiveUpdate commonOpts {
    options.volume_directory = mkOption {
      description = ''
        Directory of a btrfs volume containing the source subvolume(s) to be
        backup up. MUST be an absolute path and a btrfs volume (or subvolume).
      '';
      type = types.str;
      default = name;
    };
    options.subvolumes = mkOption {
      default = {};
      type = with types; let
        f = arg: if isList arg then genAttrs arg (_: {}) else arg;
      in coercedTo (listOf str) f (attrsOf (submodule subvolumeOpts));
    };
    options.targets = mkOption {
      default = {};
      type = with types; let
        f = arg: if isList arg then genAttrs arg (_: {}) else arg;
      in coercedTo (listOf str) f (attrsOf (submodule targetOpts));
    };
  };

  subvolumeOpts = { name, ... }: with lib; recursiveUpdate commonOpts {
    options.subvolume_name = mkOption {
      description =
        "Subvolume to be backup up, relative to the volume directory.";
      type = types.str;
      default = name;
    };
    options.snapshot_name = mkOption {
      description =
        "Base name of the created snapshot (and backup). Defaults to name";
      type = with types; nullOr str;
      default = null;
    };
    options.targets = mkOption {
      default = {};
      type = with types; let
        f = arg: if isList arg then genAttrs arg (_: {}) else arg;
      in coercedTo (listOf str) f (attrsOf (submodule targetOpts));
    };
  };

  targetOpts = { name, ... }: with lib; recursiveUpdate commonOpts {
    options.target = mkOption {
      description =
        "Where to create the backup subvolumes can be a directory or URL.";
      type = types.str;
      default = name;
    };
  };

  toConfLines = opts@{ volumes ? {}, subvolumes ? {}, targets ? {}, ... }: with lib; let
    subConfLines = subopts: map (s: "\t${s}") (toConfLines subopts);
    subopts = filterAttrs (_: v: v != null)
      (removeAttrs opts ["volumes" "subvolumes" "targets"]);
    elideEmpty = fn: args: optionals (args != {}) (fn args);

    mkTargetConf = opts@{ target, ... }:
      toList "target ${target}"
      ++ subConfLines (removeAttrs opts ["target"]);

    mkSubvolConf = opts@{ subvolume_name, ... }:
      toList "subvolume ${subvolume_name}"
      ++ subConfLines (removeAttrs opts ["subvolume_name"]);

    mkVolumeConf = opts@{ volume_directory, ... }: [
      "" # Empty line for readability.
      "volume ${volume_directory}"
    ] ++ subConfLines (removeAttrs opts ["volume_directory"]);
  in
    (mapAttrsToList (n: v: "${n} ${v}") subopts)
    ++ concatMap (elideEmpty mkTargetConf) (attrValues targets)
    ++ concatMap (elideEmpty mkSubvolConf) (attrValues subvolumes)
    ++ concatMap (elideEmpty mkVolumeConf) (attrValues volumes)
    ;
in {
  options.roos.btrbk = with lib; {
    enable = mkEnableOption ''
      Enable btrbk module for periodic snapshot and backups of btrfs subvolumes.
    '';

    config = mkOption {
      description =
        "Configuration options for btrbk. See btrbk.conf(5) for details.";
      type = types.submodule (recursiveUpdate commonOpts {
        options.volumes = mkOption {
          default = {};
          type = with types; attrsOf (submodule volumeOpts);
        };
      });
    };

    snapshots-interval = mkOption {
      type = types.str;
      default = "hourly";
      description = ''
        How often to trigger snapshot backups. See systemd.time(7) for more
        information about the format.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.symlinkJoin {
        name = "btrbk-with-config";
        paths = [ pkgs.btrbk ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for bin in ${pkgs.btrbk}/bin/*; do
            rm $out/bin/"$(basename "$bin")"
            makeWrapper $bin $out/bin/"$(basename "$bin")" \
              --add-flags "--config ${cfg.configFile}"
          done
        '';
      };
      defaultText = literalDocBook ''
        A package wrapping all btrbk binaries and adding the --config param.
      '';
    };

    configFile = mkOption {
      type = types.path;
      default = pkgs.writeText "btrbk.conf"
        (lib.concatStringsSep "\n" (toConfLines cfg.config));
      defaultText = literalExpression "configFile";
      description = "Overridable btrbk.conf. By default, that generated by nixos.";
    };

    niceness = lib.mkOption {
      description = ''
        Niceness for local instances of btrbk.
        Also applies to remote ones connecting via ssh when positive.
      '';
      type = lib.types.ints.between (-20) 19;
      default = 15;
    };

    ioSchedulingClass = lib.mkOption {
      description = ''
        IO scheduling class for btrbk (see ionice(1) for a quick description).
        Applies to local instances, and remote ones connecting by ssh if set to
        idle.
      '';
      type = lib.types.enum [ "idle" "best-effort" "realtime" ];
      default = "best-effort";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.services.btrbk-snapshot = {
      description = "Create periodic snapshots using btrbk";
      path = [ pkgs.sudo ];
      serviceConfig.ExecStart =
        "${cfg.package}/bin/btrbk snapshot -c ${cfg.configFile} -v -S";
    };

    systemd.timers.btrbk-snapshot = {
      description = "Timer for periodic snapshots using btrbk";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = cfg.snapshots-interval;
      timerConfig.Unit = "btrbk-snapshot.service";
    };
  };
}

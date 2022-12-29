{ config, options, pkgs, lib, ... }: with lib; let
  escapeUnitName = name:
    lib.concatMapStrings (s: if lib.isList s then "-" else s)
      (builtins.split "[^a-zA-Z0-9_.\\-]+" name);

  reactimatedOpts = { name, config, ... }: {
    options.path = mkOption {
      description = ''
        Path relative to the home directory where to write the script output.
      '';
      type = types.str;
      default = name;
    };
    options.script = mkOption {
      description = ''
        Script to run to regenerate the contents of the file in path.
        Everything printed to stdout will be included in the file.
      '';
      type = with types; nullOr str;
      default = null;
    };
    options.unitOnly = mkOption {
      description = ''
        When true, no file will be generated.

        The corresponding unit will still be generated. This is useful to bind
        other units to the unit triggered when the dependencies are modified.
      '';
      type = types.bool;
      default = false;
    };
    options.dependencies = mkOption {
      description = "Paths to be monitored for changes.";
      type = with types; listOf str;
      default = [];
    };
    options.unitName = mkOption {
      description = "Name of the systemd unit activated when the path changes.";
      type = types.str;
      default = "path-${escapeUnitName config.path}";
      readOnly = true;
    };
    options.assertions = options.assertions;

    config = {
      assertions = [{
        assertion = config.unitOnly -> config.script == null;
        message = "A script cannot be specified when unitOnly is true.";
      } {
        assertion = !config.unitOnly -> config.script != null;
        message = "A script must be specified when unitOnly is false.";
      } {
        assertion = config.dependencies != [];
        message = "The list of dependencies cannot be empty.";
      }];
    };
  };

  cfg = config.home.reactimated.files;

  serviceUnit = cfg: nameValuePair "${cfg.unitName}" {
    Unit = {
      Description = "Regenerate file ${cfg.path}";
      After = "home-manager-${config.home.username}.service";
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        if cfg.unitOnly
        then "${pkgs.coreutils}/bin/true"
        else pkgs.writeShellScript "script" ''
          export PATH=${with pkgs; lib.makeBinPath [ coreutils ]}:$PATH
          TARGET="$HOME/${cfg.path}"
          mkdir -p "$(dirname "$TARGET")"

          script() {
          ${cfg.script}
          }

          script > "$TARGET"
        ''
      );
    };
    Install.WantedBy = [ "default.target" ];
  };

  absolutizePath = p:
    if hasPrefix "/" p
    then p
    else "${config.home.homeDirectory}/${removePrefix "~/" p}";

  pathUnit = cfg: nameValuePair "${cfg.unitName}" {
    Path.PathModified = map absolutizePath cfg.dependencies;
    Install.WantedBy = [ "default.target" ];
  };

in {
  options.home.reactimated.files = mkOption {
    description = ''
      Regenerate files whenever a file inside the home directory changes.

      Mind that no effort is made to detect whether a dependency loop exists
      in the file generation.
    '';
    default = {};
    type = with types; attrsOf (submodule reactimatedOpts);
  };

  config = mkIf (cfg != {}) {
    systemd.user.services = listToAttrs (map serviceUnit (attrValues cfg));
    systemd.user.paths = listToAttrs (map pathUnit (attrValues cfg));
  };
}

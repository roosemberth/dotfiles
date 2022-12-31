{ config, pkgs, lib, ... }: with lib; let
  actionOpts = { name, config, ... }: {
    options.cmd = mkOption {
      description = "A command to run to execute action ${name}";
      type = with types; uniq str;
    };
    options.script = mkOption {
      description = "A single-command script executing action ${name}";
      type = with types; uniq path;
      default = let
        safeName = replaceChars ["/" " " ":"] ["-" "-" "-"] name;
      in pkgs.writeScript "action:${safeName}" "${config.cmd}";
    };
  };
in {
  options.roos.actions = mkOption {
    description = "Register a command providing a given action.";
    type = with types; let
      fromType = attrsOf str;
      convertFn = actCmdKv: mapAttrs (_: cmd: { inherit cmd; }) actCmdKv;
      finalType = attrsOf (submodule actionOpts);
    in coercedTo fromType convertFn finalType;
  };
  options.roos.actions-package = mkOption {
    description = "A binary that can be used to dispatch actions at runtime.";
    type = types.package;
    readOnly = true;
    default = with pkgs; let
      actionsList = attrNames config.roos.actions;
      compEscapedList = map (s: replaceStrings [":"] ["\\\\:"] s) actionsList;
      completion-file = writeTextDir "share/zsh/site-functions/_action" ''
        #compdef action
        _values action ${concatStringsSep " " compEscapedList}
      '';
      action-bin = writeScriptBin "action" ''
        ${concatMapStringsSep "\n" (action: ''
          if [ "v$1" == "v${action}" ]; then
            exec ${config.roos.actions."${action}".script}
          fi
        '') actionsList}

        cat <<-EOF >&2
        	$(basename "$0"): Run predefined action scripts.

        	This script is useful for automation to trigger actions without
        	understanding their implementation details.

        	Available actions:
        	${concatMapStringsSep "\n" (s: "- ${s}") actionsList}

          The action "$1" was not understood.
        EOF
      '';
    in pkgs.symlinkJoin {
      name = "actions";
      paths = [ action-bin completion-file ];
    };
  };
}

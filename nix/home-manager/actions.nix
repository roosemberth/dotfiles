{ pkgs, lib, ... }: with lib; let
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
}

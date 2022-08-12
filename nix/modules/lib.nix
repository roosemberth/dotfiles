{ lib, ... }: with lib; let
  exprOpts = defOp: { name, ... }: {
    options.name = mkOption { type = types.str; default = name; };
    options.value = mkOption { type = types.str; };
    options.operator = mkOption {
      type = types.enum [ "==" "!=" "=" "+=" "-=" ":=" ];
      default = defOp;
    };
  };

  ruleOpts = { config, ... }: {
    options.match = mkOption {
      description = "Attrset with expressions to match an event.";
      default = {};
      type = with types; let
        asValue = (s: { value = s; });
      in attrsOf (coercedTo str asValue (submodule (exprOpts "==")));
    };
    options.make = mkOption {
      description = "Attrset with expressions to apply an action.";
      default = {};
      type = with types; let
        asValue = s: { value = s; };
      in attrsOf (coercedTo str asValue (submodule (exprOpts "=")));
    };
    options.ruleStr = mkOption {
      default = concatMapStringsSep ", "
        (v: "${v.name}${v.operator}\"${v.value}\"")
        (attrValues config.match ++ attrValues config.make);
    };
  };

  renderRule =
    cfg: (evalModules { modules = [ ruleOpts cfg ]; }).config.ruleStr;
in {
  lib.udev = { inherit renderRule; };
}

{ lib, ... }: with lib; let
  exprOpts = defOp: { name, ... }: {
    options.name = mkOption { type = types.str; default = name; };
    options.value = mkOption { type = types.str; };
    options.operator = mkOption {
      type = types.enum [ "==" "!=" "=" "+=" "-=" ":=" ];
      default = defOp;
    };
  };

  coercedExpr = defOp: with types; let
    asValue = (s: { value = s; });
    subtype = submodule (exprOpts defOp);
  in attrsOf (coercedTo str asValue subtype);

  ruleOpts = { config, ... }: {
    options.match = mkOption {
      description = "Attrset with expressions to match an event.";
      default = {};
      type = coercedExpr "==";
    };
    options.make = mkOption {
      description = "Attrset with expressions to apply an action.";
      default = {};
      type = coercedExpr "=";
    };
    options.add = mkOption {
      description = "Attrset with expressions to apply an action.";
      default = {};
      type = coercedExpr "+=";
    };
    options.ruleStr = mkOption {
      default = concatMapStringsSep ","
        (v: "${v.name}${v.operator}\"${v.value}\"")
        (  attrValues config.match
        ++ attrValues config.make
        ++ attrValues config.add
        );
    };
  };

  renderRule =
    cfg: (evalModules { modules = [ ruleOpts cfg ]; }).config.ruleStr;
in {
  lib.udev = { inherit renderRule; };
}

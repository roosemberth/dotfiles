{ }:
let
  zoneFile = domain: ./zones + "/${builtins.hashString "sha256" "zone-${domain}"}";
in {
  acme.email = "roosemberth+acme@posteo.ch";
  bind-zones."orbstheorem.ch" = zoneFile "orbstheorem.ch";

  allDnsZones = [{
    name = "zkx.ch";
    master = true;
    file = zoneFile "zkx.ch";
  } {
    name = "dyn.zkx.ch";
    master = true;
    file = "/run/named/dyn.zkx.ch";
    extraConfig = ''
    allow-update { 127.0.0.1; };
    '';
  }];
}

# Pad to avoid leaking information:
################################################################################
################################################################################

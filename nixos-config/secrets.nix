{ lib }:

let
  listFilesInDir = dir: lib.mapAttrsToList (p: _: dir + "/" + p)
    (lib.filterAttrs (path: type: type == "regular") (builtins.readDir dir));
in
{
  machines = {
    Lappie = {
      # `dropbearkey -t rsa -f secrets/machines/lappie/ssh-keys/initramfs`
      hostInitrdRSAKey = secrets/machines/lappie/ssh-keys/initramfs;
    };
    Triglav = {
      hostInitrdRSAKey = secrets/machines/triglav/ssh-keys/initramfs;
    };
  };
  #adminPubKeys = map builtins.readFile (listFilesInDir secrets/admins/ssh-keys);
  adminPubKeys = [ (builtins.readFile secrets/admins/ssh-keys/roosemberth.pub) ];
  users = {
    roosemberth = {
      sshPubKey = [ (builtins.readFile secrets/admins/ssh-keys/roosemberth.pub) ];
    };
  };
}

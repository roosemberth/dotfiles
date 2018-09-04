{ lib }:

let
  listFilesInDir = dir: lib.mapAttrsToList (p: _: dir + "/" + p)
    (lib.filterAttrs (path: type: type == "regular") (builtins.readDir dir));
  readSecretPath = path: lib.strings.fileContents (builtins.toString ./secrets + "/" + path);
  wireguardSecrets = hostname: {
      private = readSecretPath "machines/${hostname}/wireguard-keys/private";
      public = readSecretPath "machines/${hostname}/wireguard-keys/public";
    };
in
{
  machines = {
    Azulejo = {
      hostInitrdRSAKey = secrets/machines/azulejo/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "azulejo";
    };
    Dellingr = {
      hostInitrdRSAKey = secrets/machines/dellingr/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "dellingr";
    };
    Heimdaalr = {
      hostInitrdRSAKey = secrets/machines/heimdaalr/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "heimdaalr";
    };
    Heisenberg = {
      hostInitrdRSAKey = secrets/machines/heisenberg/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "heisenberg";
    };
    Hellendaal = {
      hostInitrdRSAKey = secrets/machines/hellendaal/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "hellendaal";
    };
    Lappie = {
      # `dropbearkey -t rsa -f secrets/machines/lappie/ssh-keys/initramfs`
      hostInitrdRSAKey = secrets/machines/lappie/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "lappie";
    };
    Triglav = {
      hostInitrdRSAKey = secrets/machines/triglav/ssh-keys/initramfs;
      wireguardKeys = wireguardSecrets "triglav";
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

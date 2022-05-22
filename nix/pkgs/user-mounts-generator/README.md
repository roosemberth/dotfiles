# user-mounts-generator

Generates a set of systemd mount units based on a layout tree of btrfs
subvolumes.

The subvolumes in the layout tree will be mounted at the specified subpath
under the "destination path" of the tree.

## Layout tree

A layout tree is a directory tree containing btrfs subvolumes at it leaves.
The only btrfs subvolume can be at the leaves and their names MUST start
with '@'.
Moreover, only leave names are allowed to start with '@'.

The directory structure indicates where to mount each of the subvolumes:
Each subvolume will be mounted under their path relative to the layour tree
root, with the '@' removed.

Example layout tree:

```text
./@ws
./@Media
./@nocow
./.local/var/@cache
./.local/var/lib/@vms
./.local/var/lib/@SteamLibrary
./ws/@2-Platforms
./ws/@5-VMs
```

## Unit generation

A `systemd.mount(5)` units will be generated for each leaf.
Each leaf will be mounted at the destination path of the layout tree
at the subpath specified by its path under the layout tree.

Both the path to each layout tree and its destination are specified in the
configuration file.

Extra options for the mount units may be specified in the configuration file.

Mind that the layout tree needs to be inside the default subvolume of the
device.
The tree_prefix parameter (usually the mount point of the default subvolume)
is necessary to generate the correct mount option.

## Configuration file

`user-mounts-generator` will look for its configuration file in
`/etc/user-mounts.yaml` or the file indicated in the
`USER_MOUNTS_GENERATOR_CONFIG` environment variable.

The configuration file specifies where to find the layout trees and
their destination.

The configuration allows to specify extra mount options
to be applied to all mount units in each tree.

Example configuration file:

```yaml
- layout_tree: /mnt/root-btrfs/subvolumes/per-user/@roosemberth
  tree_prefix: /mnt/root-btrfs
  destination: /home/roosemberth
  device_path: /dev/mapper/Mimir
  extra_opts:
    - user_subvol_rm_allowed
```

Mind that the mount options will not be in anyway checked, but simply passed
down to the mount unit.

Given the following layout tree, this will generate the following mount unit:

```text
./@ws
./ws/@5-VMs
```

```ini
[Unit]
Before=local-fs.target
Documentation=See user-mounts-generator.
After=blockdev@dev-mapper-Mimir

[Mount]
What=/dev/mapper/Mimir
Type=btrfs
Options=subvol=/subvolumes/per-user/@roosemberth/@ws,user_subvol_rm_allowed,compress=zlib,relatime
Where=/home/roosemberth/ws

[Install]
WantedBy=multi-user.target
```

```ini
[Unit]
Documentation=See user-mounts-generator.
Before=local-fs.target
After=blockdev@dev-mapper-Mimir

[Mount]
Where=/home/roosemberth/ws/5-VMs
Options=subvol=/subvolumes/per-user/@roosemberth/ws/@5-VMs,user_subvol_rm_allowed,compress=zlib,relatime
What=/dev/mapper/Mimir
Type=btrfs

[Install]
WantedBy=multi-user.target
```

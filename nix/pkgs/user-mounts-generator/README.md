# layout-tree-generator

Generates a set of systemd '.mount' units based on _layout trees_ of btrfs
subvolumes.

Each of the subvolumes in a _layout tree_ will be mounted at the
corresponding subpath under the "destination path" of the tree.

## Layout tree

A _layout tree_ is a directory tree containing btrfs subvolumes at its leaves.
Only btrfs subvolumes can be at the leaves and their names MUST start
with '@'.
Moreover, only the leaves can have their name start with '@'.

The directory structure indicates where to mount each of the subvolumes:
Each subvolume will be mounted under the "destination path" at a location
which corresponds to the location of the subvolume within the layout tree,
with the '@' removed.

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

`layout-tree-generator` will look for its configuration file in
`/etc/layout-trees.yaml` or the file indicated in the
`LAYOUT_TREES_GENERATOR_CONFIG` environment variable.

The configuration file specifies where to find the layout trees and
the "destination path" of each of them.

Additional mount options may be specified in the configuration file,
these options will be added to all mount units generated for this tree.

Example configuration file:

```yaml
- layout_tree: /mnt/root-btrfs/subvolumes/per-user/@roosemberth
  tree_prefix: /mnt/root-btrfs
  destination: /home/roosemberth
  device_path: /dev/mapper/Mimir
  extra_opts:
    - user_subvol_rm_allowed
```

Mind that the mount options will not be verified in anyway, but simply passed
down to the mount unit.

Given the following layout tree, this will generate the following mount unit:

```text
./@ws
./ws/@5-VMs
```

```ini
[Unit]
Before=local-fs.target
After=blockdev@dev-mapper-Mimir.target

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
Before=local-fs.target
After=blockdev@dev-mapper-Mimir.target

[Mount]
Where=/home/roosemberth/ws/5-VMs
Options=subvol=/subvolumes/per-user/@roosemberth/ws/@5-VMs,user_subvol_rm_allowed,compress=zlib,relatime
What=/dev/mapper/Mimir
Type=btrfs

[Install]
WantedBy=multi-user.target
```

# dotfiles

This is my collection of user/application/system settings & configurations.
It was founded on the bases of my old dotfiles repository and [ayekat's dotfiles
repository](https://github.com/ayekat/dotfiles).
Over the years both have diverged and I have decided to break implicit
compatibility across them.
However they both share a very similar ideology.
A key difference is that this repository does not (_or at least tries not to_)
assume any FHS locations.
This plays really well with [NixOS](https://nixos.org) at expense of complexity.
Hence some application configurations must be rendered before they can be used
(see [application configurations](#application-configurations)).
If you're interested on something more standard, go check ayekat's repository.

Application configurations are usually under the `etc` directory.

## NixOS

I use [NixOS](https://nixos.org) to manage system and user configurations.
Some application configuration is also managed using my own [_Home Manager_
][Home manager]-inspired module system, but I try to
keep application configuration files as portable as possible (see
[the dedicated section](#application-configurations)).

Since I often use a very similar configuration across different devices, I try
to split the configuration at different levels:

### Machine configurations (`nix/machines`):

Top-level configuration.nix for a given system.

I try to keep them organized by hostname.

### Modules

_NixOS modules_-inspired module system containing system-wide configurations.

These modules are very similar to NixOS modules (and may be used as staging
before being upstreamed). Note however that an additional argument (`secrets`)
is available in the module call scope (see [secrets](#secrets)).

Importing `nix/modules` will recursively source any `*.nix` file under it
(except for `default.nix` or `util.nix`).

### User modules

[Home Manager][Home manager]-based module system with
configuration profiles.

Each module may provide features to an user configuration profile.
Each user may be assigned to zero or one configuration profiles.
Configuration profiles entail configuration features for users member of such
profile.

The following configuration profiles are available:

- Reduced profile:
  Provides minimalistic configurations, such as environment variables, small
  programs or small configuration files with no dependencies. Ideal for servers.

- Simple profile:
  Provides configurations for more complex systems, such as email management,
  audio services (such as MPD); in particular, features that do not need a
  graphical session.

- Graphical profile:
  Provides configurations for full-blown graphical sessions, such as window
  manager configurations, [steam _(videogame distribution platform)_][Steam]
  integration, and other features which may use graphical services.
  These configuration features are blacklisted for the root user.

Note that a user membership to the Graphical profile, entails membership to
the Simple profile. Likewise, membership to the Simple profile implies
membership to the Reduced profile.

Users with no membership to any profile will not be affected by the user module
system.

User modules are applied system-wide and configuration features are applied
to users as per their configuration profiles membership.

#### User profiles

A `user-profiles` module is provided to add per-user configuration features.
User-specific configurations are under `modules/user-profiles/<username>.nix`.
User-specific configurations may or may not use the user module system to
provide features.

### Secrets

Secrets such as user password hashes, SSH keypairs, user email accounts and
opaque configurations.

Files under `nix/secrets` are encrypted to my GPG key using [git-crypt
](https://github.com/AGWA/git-crypt).
The top-level of the secrets system is provided in `nix/secrets.nix`.
I intend to keep this file as transparent as possible so that anybody can
make themselves an idea of the secrets structure.

I try to keep as less secrets as possible.

## Application configurations

Because I mainly use NixOS to manage my systems, I tend to use NixOS or
[Home Manager](Home manager) modules to configure applications.

Those that I manually configure, I try to keep as distribution-agnostic and
portable as possible.
This also means that I don't usually assume paths or even [FHS][fhs].
Because of this, some configuration files must be rendered before (e.g. when
such include secrets).
If this is the case, instructions are provided in the respective configuration
directory.

Configurations of key applications (such as nvim or zsh) are kept verbatim,
but they should gracefully handle running in a hostile (or poorly configured)
environment.

### XDG/FHS

I try to keep the top-level user home directory as clean as possible by
honouring the [XDG base directory specification](xdg), adapted to recreate
the [Linux file system hierarchy][fhs] (FHS) under `~/.local`.

In detail, this means that the following environment variables are set:

| Variable          | Location             |
| ----------------- | -------------------- |
| `XDG_CACHE_HOME`  | `~/.local/var/cache` |
| `XDG_CONFIG_HOME` | `~/.local/etc`       |
| `XDG_DATA_HOME`   | `~/.local/var/lib`   |
| `XDG_RUNTIME_DIR` | `~/.local/run`       |
| `XDG_LIB_HOME`    | `~/.local/lib`       |
| `XDG_LOG_HOME`    | `~/.local/var/log`   |

> ### Notes
> * `XDG_LIB_HOME` and `XDG_LOG_HOME` are non-standard, but they are
>   nevertheless necessary for representing the FHS locally.
> * `~/.local/run` **must** be a symbolic link to `/run/user/<uid>`.

Furthermore, impure user-specific executables may be placed in `~/.local/bin`.
By impure, I mean mostly commodity scripts that may or may not exist and for
which no guarantees (such as dependency management) are provided.

## Arbitrary policies I try to follow

- Application history generally goes into `XDG_DATA_HOME` (see f1147a9 for the
  reasoning). The only things that go into `XDG_LOG_HOME` are "real" logs, i.e.
  data that is no longer read and used by the application itself. The only
  things that go into `XDG_CACHE_HOME` are files that are non-essential and can
  quickly be regenerated by the application, if needed (which is both not the
  case for history files).

- Applications whose configuration is mixed up with other data (or generally not
  supposed to be manually edited) is put into `XDG_DATA_HOME`.

- I like systemd and try to use its reasonable features as much as possible.
  That said, I trust systemd very little and try to defer as much logic to nix
  when it comes to dependency management; and try to encourage my programs to
  handle a misbehaving systemd.

[Home manager]: https://github.com/rycee/home-manager/
[Steam]: https://en.wikipedia.org/wiki/Steam_(service)
[fhs]: https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html
[xdg]: https://specifications.freedesktop.org/basedir-spec/latest/index.html

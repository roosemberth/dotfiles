# dotfiles

This is my collection of user/application/system settings & configurations.
It started as a collection of configuration files and shells scripts shared
among friends at uni and now lives as my personal project to put in code all
aspects of software I use in my personal computers.
This is possible thanks to Nix and NixOS.

## NixOS

At its heart, this repository is essentially a set of Nix expressions.
I use [NixOS][] and [Home manager][] to manage system and user configurations
on several devices. On top of this, I've built my own experiments and tools.

[NixOS]: https://nixos.org
[Home manager]: https://nix-community.github.io/home-manager/

### Organisation

> This section can be safely skipped.

I use [Nix flakes][], an "upcoming" feature of Nix allowing me to borrow nix
expressions from other people and publish my own in a way that promotes reuse
and sharing. However, due to both technical requirements and curiosity, I've
diverged a bit in structure from most flakes you'll find online.

[Nix flakes]: https://nixos.wiki/wiki/Flakes

I maintain systems on different NixOS distributions: As a rule of thumb, servers
and other services where I choose reliability and low maintenance cost over
flexibility use the latest stable release, whereas devices I interact with more
often are on NixOS unstable.

To aleviate the complexity of evaluating the borrowed code with each version to
then build system derivations, I've introduced the concept of 'distributions'.
A distribution is a projection of borrowed code on some NixOS version.

Finally, every host is evaluated through `./nix/eval-flake-system.nix`.
This file is responsible for typing all borrowed code together with the NixOS
(`nix/modules/`) and Home manager modules (`nix/home-manager/`) where I have
created my own little abstractions.

### Machine configurations (`nix/machines`):

Top-level configuration.nix for a given system.

I try to keep them organized by hostname.

### Modules

_NixOS modules_-inspired module system containing system-wide configurations.

These modules are very similar to NixOS modules (and may be used as staging
before being upstreamed).

Importing `nix/modules` will recursively source any `*.nix` file under it
(except for `default.nix` or `util.nix`).

### Home manager modules

[Home Manager][Home manager]-based module system with configuration profiles.

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

I used to encrypt nix expressions using [git-crypt][].
Because of this it was not possible to evaluate or build without access to my
private PGP key.
I've since moved to using [sops-nix][] to secure secrets pertaining to hosts and
services.

[git-crypt]: https://github.com/AGWA/git-crypt
[sops-nix]: https://github.com/Mic92/sops-nix

## Application configurations

Because I mainly use NixOS to manage my systems, I tend to use NixOS or
[Home Manager][Home manager] modules to configure applications.

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
honouring the [XDG base directory specification][xdg], adapted to recreate
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

# Mopidy configuration

This configuration uses _render variables_.

_Render variables_ are expressions of the form `@varName@`, which shall be
substituted with some value before using this configuration.

The following _render variables_ are used:

- `musicDirectory`: Directory under which the music is located when the
  configuration is in use.

The following _render variables_ from the [_mopidy-spotify configuration_] are
used:

- `mopidyClientId`
- `mopidyClientSecret`
- `spotifyUserName`
- `spotifyPassword`

The following _render variables_ from the [XDG Base Directory Specification]
are used:

- `cacheHome`
- `configHome`
- `dataHome`

[XDG Base Directory Specification]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
[_mopidy-spotify configuration_]: https://github.com/mopidy/mopidy-spotify#configuration

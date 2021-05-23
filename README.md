# Protonsh

Simple shell tool to ease operations inside [Proton] prefixes.

# Usage

The script currently takes no arguments. When run, it will:

 1. ask the user on which Proton prefix he wants to operate;
 2. ask the user the desired Proton version to use.

After this, a number of environment variable overrides will be performed to
ensure that any wine-specific tooling will work on the selected Proton prefix,
using the selected Proton version executables (`wine`/`wine64` will indeed point
to the selected Proton version binaries).

## Steam library directories location

All the prompts previously described are based on locating the Steam library
directories (`SteamApps`/`steamapps`) and looking at their contents.
This is done by looking at the default `~/.steam/steam/steamapps` location and
at the directories pointed at by the `BaseInstallFolder` settings inside the
`config.vdf` file.

# Local overrides

Local environment variable overrides can be specified in the `~/.config/protonsh`
file, that will be sourced if found.

These are the available variable overrides:

| Variable name | Description | Default value |
|---------------|-------------| --------------|
| STEAMAPPS_DIRS | Steam library directories location. Must be an array | Autodetected |
| SHELL | the shell to launch inside a Proton prefix | `/bin/bash` |
| LOGLEVEL | the log level of log messages. Can be `ERROR`, `WARN`, `INFO`, `DEBUG` | `WARN` |



[Proton]: https://github.com/ValveSoftware/Proton

# Installation

There is a basic Makefile in place to ease installing the script on the system.

Run `make` or `make help` to see what commands/variables are currently
supported.

By issuing a `make install` command as root, the script will be put in
`/usr/bin/protonsh`.
If you'd like to change the installation prefix to something other than `/usr`,
you can override this by overriding the `PREFIX` make variable, like:

```sh
make PREFIX=/usr/local install
```

To ease package creation, the `DESTDIR` make variable is used throughout the
Makefile as a prefix to `PREFIX` ;-)

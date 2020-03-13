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

## SteamApps directory location

All the prompts previously described are based on locating the `SteamApps`
directory in `~/.steam/steam/SteamApps`. If this is not your case, you can
override this by setting the `STEAM_APPS_DIR` environment variable before
launching the script, e.g. `STEAM_APPS_DIR=/some/dir protonsh`. To make this
permanent, you can add this line:

```sh
export STEAM_APPS_DIR=/some/dir
```

to the `~/.config/protonsh` file, which will be sourced if found.


[Proton]: https://github.com/ValveSoftware/Proton
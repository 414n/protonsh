# Protonsh

Simple shell tool to ease operations inside [Proton] prefixes.

# Usage

The script currently takes no arguments. When run, it will:

 1. ask the user on which Proton prefix he wants to operate;
 2. ask the user the desired Proton version to use.

After this, a number of environment variable overrides will be performed to
ensure that any wine-specific tooling will work on the selected Proton prefix,
using the selected Proton version executables (`wine`/`wine64` will indeed
point to the selected Proton version binaries).


[Proton]: https://github.com/ValveSoftware/Proton
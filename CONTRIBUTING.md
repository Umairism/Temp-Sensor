# Contributing to Thermal Monitor Pro

Thanks for your interest in improving Thermal Monitor Pro! This document explains how to set up a development environment, test changes, and submit them.

## Development setup

You need:

- **KDE Plasma 6** (a VM, a spare machine, or your daily driver — a Wayland/X11 session both work)
- **ksystemstats** (ships with Plasma), and `lm_sensors` configured via `sudo sensors-detect --auto`
- `kpackagetool6` (from `kf6-kpackage`) to install/remove the plasmoid
- `plasmawindowed` / `plasma-sdk` to run the widget standalone in a window

Clone and install for development:

```bash
git clone https://github.com/Umairism/Temp-Sensor.git
cd Temp-Sensor
./install.sh
```

Or, for faster iteration, symlink the package into your local plasmoids directory:

```bash
mkdir -p ~/.local/share/plasma/plasmoids
ln -sfn "$PWD/package" ~/.local/share/plasma/plasmoids/com.github.umairism.thermalmonitor
```

Then reload Plasma after each change:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

## Testing

There is no unit-test suite (QML applets are tested by running them). Before submitting:

1. `plasmawindowed com.github.umairism.thermalmonitor` opens the widget in a standalone window — verify it renders, updates, and survives sensors disappearing (e.g. after re-running `sensors-detect`).
2. `scripts/build-plasmoid.sh` must succeed (it validates `metadata.json`, `main.xml` and the archive layout).
3. Check the widget in a **panel** and on the **desktop** (form factors behave differently).
4. Check both light and dark Plasma themes.
5. If you changed i18n strings, make sure every user-facing string uses `i18n()`/`i18np()`.
6. Turn notifications off/on and confirm the hysteresis behavior by temporarily lowering the critical threshold.

CI runs the same packaging validation on every PR.

## Code style

- QML files use 4-space indentation, `qmlformat`-compatible layout, and KDE API conventions.
- User-facing strings must go through `i18n()`/`i18np()`.
- Keep the `package/` directory free of anything that is not part of the installed widget; tooling belongs at the repository root.

## Commit style

- One logical change per commit; imperative subject line ≤ 72 chars.
- Reference issues in the body (`Fixes #12`).

## Release process (maintainers)

1. Update `Version` in `package/metadata.json` and add a `CHANGELOG.md` entry.
2. `git tag -a vX.Y.Z -m "vX.Y.Z" && git push --tags`
3. CI builds the `.plasmoid` and attaches it to the GitHub Release automatically.
4. Upload the same `.plasmoid` and fresh screenshots to store.kde.org — see [PUBLISHING.md](PUBLISHING.md).

## Reporting bugs

Open an issue with: Plasma version (`plasmashell --version`), distribution, output of `kstatsviewer --list` (sensor IDs only — it contains no private data), and steps to reproduce.

## Linting

Static analysis with Qt's linter is welcome but not enforceable in CI yet (the
Plasma 6 QML modules aren't packaged for Ubuntu CI runners). When you have
`qmllint` (Debian/Ubuntu: `qt6-declarative-dev-tools`) and `libksysguard`
installed:

```bash
qmllint -I /usr/lib/x86_64-linux-gnu/qt6/qml package/contents/ui/main.qml
```

Expected noise: `i18n`/`modelData` "unqualified access" warnings (Plasma
injects these into the plasmoid context) and "Failed to import
org.kde.plasma.*" if `plasma-workspace` isn't installed. Anything else —
syntax errors, unresolved types, missing properties — is a real bug.

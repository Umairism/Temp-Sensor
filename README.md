# Thermal Monitor Pro

[![CI](https://github.com/Umairism/Temp-Sensor/actions/workflows/ci.yml/badge.svg)](https://github.com/Umairism/Temp-Sensor/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A native **KDE Plasma 6** desktop and panel widget for monitoring live **CPU, core, motherboard, NVMe, and GPU temperatures** — powered by `ksystemstats` (the same sensor backend as KDE System Monitor) and `lm_sensors`.

## Features

- **Automatic discovery** of temperature sensors (`lmsensors/`, `cpu/`, `gpu/`, `disk/`)
- **Per-sensor selection** — tick the sensors you want in the settings dialog; automatic mode shows everything (up to a configurable limit)
- **Color-coded gauges** — normal / warning / critical, themed via Kirigami (works in light and dark)
- **Configurable thresholds, refresh interval, units** (°C/°F)
- **Panel & desktop modes** — compact hottest-temperature readout in panels, full sensor dashboard on the desktop or as a popup
- **Critical-temperature notifications** (optional, with hysteresis so you aren't spammed)
- **Live tooltip & accessible names** — hover a panel widget to see the hottest sensor
- **Actionable empty state** when no sensors are found (tells you exactly what to install, instead of spinning forever)

## Requirements

| Component | Why |
|---|---|
| KDE Plasma 6 | Widget runtime (`KF6 Plasma`, `org.kde.ksysguard.sensors`) |
| `ksystemstats` | Sensor backend (usually installed with Plasma) |
| `lm_sensors` | Hardware temperature sources on most boards (optional but recommended) |
| `gdbus` (from GLib) | Only for critical-temperature desktop notifications |

### Installing `lm_sensors`

```bash
# Fedora
sudo dnf install lm_sensors && sudo sensors-detect --auto
# Debian / Ubuntu
sudo apt install lm-sensors && sudo sensors-detect --auto
# Arch
sudo pacman -S lm_sensors && sudo sensors-detect --auto
# openSUSE
sudo zypper install sensors && sudo sensors-detect --auto
```

`sensors-detect` scans your motherboard for sensor chips and loads the right kernel modules — answer *yes* to loading them at boot. Some virtual machines and ARM boards expose no thermal sensors at all; in that case only GPU/NVMe sensors reported by the kernel may appear.

## Installation

### From a release (recommended)

1. Download the `.plasmoid` from the [latest release](https://github.com/Umairism/Temp-Sensor/releases) (or build one — see below).
2. Install it:

```bash
kpackagetool6 --type Plasma/Applet --install com.github.umairism.thermalmonitor-*.plasmoid
```

If upgrading from `1.0.0`, note the plugin id changed to `com.github.umairism.thermalmonitor` — remove the old one: `kpackagetool6 --type Plasma/Applet --remove com.custom.thermalmonitor`.

### From source

```bash
git clone https://github.com/Umairism/Temp-Sensor.git
cd Temp-Sensor
./install.sh          # or: ./install.sh --uninstall
```

### First run

Right-click your desktop or an empty panel area → **Add Widgets…** → search **Thermal Monitor Pro** → drag it in.

Before adding it to your panel, smoke-test it in a standalone window:

```bash
plasmawindowed com.github.umairism.thermalmonitor
```

If nothing appears or sensors are missing, restart Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

## Configuration

Right-click the widget → **Configure Thermal Monitor Pro…**

| Setting | Default | Notes |
|---|---|---|
| Fahrenheit display | off | Thresholds are always configured in °C |
| Warning threshold | 70 °C | Neutral color at/above this value |
| Critical threshold | 85 °C | Negative color + optional notification at/above this value |
| Refresh interval | 1500 ms | 500–10000 ms |
| Max sensors (automatic mode) | 12 | Only applies when no explicit selection is made |
| Show raw sensor IDs | off | e.g. `lmsensors/it8620-isa-0290/temp1` |
| Notify when critical | on | Fires once per breach; re-arms 5 °C below the threshold |
| Sensors to show | *(empty = all)* | Tick sensors to display exactly those, in discovery order |

Want to know which sensor IDs your machine reports?

```bash
kstatsviewer --list
```

## Troubleshooting

**"No temperature sensors found"**
1. Install `lm_sensors` and run `sudo sensors-detect --auto` (see above), then log out and back in.
2. Check that Plasma's own sensor backend sees them: `kstatsviewer --list` should list `lmsensors/…`, `cpu/…temperature…`, etc.
3. On NVIDIA GPUs, `nvidia-smi` sensors come from ksystemstats' GPU support — make sure `ksystemstats` and your proprietary driver are installed.
4. Some hardware (notably many VMs and ARM SoCs) exposes no readable thermal sensor. Nothing to fix on the software side.

**Widget missing after install** — restart Plasma (command above) and double-check the id: `kpackagetool6 --type Plasma/Applet --show com.github.umairism.thermalmonitor`.

**Notifications don't appear** — notifications are sent via `gdbus` on the session bus. Ensure `gdbus` is installed (`glib2` / `libglib2.0-bin` on your distro) and your desktop exposes `org.freedesktop.Notifications`. If a notification fails, the widget disables notifications for that session and logs a warning — everything else keeps working.

## Building a `.plasmoid` package

```bash
scripts/build-plasmoid.sh
```

This validates `metadata.json` / `main.xml`, then writes `dist/com.github.umairism.thermalmonitor-<version>.plasmoid` with its SHA-256. Tagged releases build this automatically in CI and attach it to the GitHub release.

## Repository layout

```
├── package/                 # the installable plasmoid (only this goes inside the .plasmoid)
│   ├── metadata.json
│   └── contents/
│       ├── ui/              # main.qml, configGeneral.qml
│       └── config/          # config.qml (tabs), main.xml (KConfigXT schema)
├── scripts/build-plasmoid.sh
├── install.sh               # user-level install/upgrade/uninstall
├── .github/workflows/       # CI + tag-triggered release
└── docs in README / CONTRIBUTING / CHANGELOG / PUBLISHING
```

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). If you found a bug or have an idea, please [open an issue](https://github.com/Umairism/Temp-Sensor/issues) first for anything non-trivial.

## Publishing this widget

The maintainer playbook for KDE Store submission, distro packaging, and release tagging lives in [PUBLISHING.md](PUBLISHING.md).

## Screenshots

Store screenshots (panel compact view, full dashboard, configuration page) are captured with `plasmawindowed` once per release — see [PUBLISHING.md](PUBLISHING.md#screenshots) for the exact list.

## License

[GPL-3.0-or-later](LICENSE). You're free to use, study, modify and redistribute this under the terms of the GNU General Public License v3 or later.

## Acknowledgements

- The KDE `ksystemstats` / `libksysguard` developers, without whom none of this sensor data would be reachable from QML.
- Inspired by other Plasma temperature applets; this project takes a configuration-first, selection-driven approach on the sensor side.

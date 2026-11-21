# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-22

### Added
- Per-sensor selection in the settings dialog: tick exactly which discovered
  sensors to show (stored as a semicolon-separated list; empty = automatic,
  capped by "Max Sensors").
- Optional desktop notification when a sensor reaches the critical threshold,
  with 5 °C hysteresis to avoid notification storms. Notifications are sent
  via `gdbus` and are disabled gracefully for the session if `gdbus` fails.
- Actionable empty state shown when ksystemstats reports no temperature
  sensors, with install guidance for lm_sensors.
- Hover tooltip reporting the hottest sensor, live while values update.
- `scripts/build-plasmoid.sh` to validate and build `.plasmoid` packages.
- `CONTRIBUTING.md`, `PUBLISHING.md`, CI (metadata/packaging validation) and
  a tag-triggered release workflow attaching the `.plasmoid` to GitHub Releases.

### Changed
- Plugin id changed to `com.github.umairism.thermalmonitor`. After upgrading,
  remove the old id once: `kpackagetool6 --type Plasma/Applet --remove com.custom.thermalmonitor`.
- Panel uses the compact representation; the desktop representation only
  appears on the desktop form factor.
- "Max sensors" now only applies in automatic (no explicit selection) mode.
- Repository restructured into the recommended `package/` layout: the
  installable plasmoid lives in `package/`, tooling stays at the root.
- Metadata cleaned up: real website, issue tracker, keywords, SPDX
  `GPL-3.0-or-later`; dropped the misleading `X-Plasma-Provides` declaration.
- Threshold colors and the gauge are driven by the configured warning/critical
  values instead of hard-coded tiers.

### Fixed
- The panel/header temperature read-out no longer ratchets upward forever; it
  is computed from the currently shown sensors and renders `--` until the
  first reading arrives.
- Sensor selection is not rebuilt on every discovery pass, eliminating the
  periodic destruction/re-creation of all live sensor bindings.
- Sensor values outside −50…150 °C are ignored instead of skewing the display.

## [1.0.0] - 2026-11-21

Initial public release: auto-discovered temperature sensors from ksystemstats
(`lmsensors/*`, `cpu/*`, `gpu/*`, `disk/*`), color-coded gauges, configurable
warning/critical thresholds, °C/°F units, compact panel and full desktop views.

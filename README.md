# Thermal Monitor Pro (KDE Plasma 6 Widget)

A native KDE Plasma 6 desktop & panel widget for monitoring live **CPU, Core, Motherboard, NVMe, and GPU** temperatures using KDE's `ksystemstats` / `lm_sensors` backend.

## Features
- **Auto-discovers** temperature sensors (`lmsensors/*`, `cpu/*`, `gpu/*`, `disk/*`)
- **Color-coded thermal gauges** (Normal, Warm, Warning, Critical)
- **Configurable settings** (°C / °F, Warning & Critical thresholds, Refresh interval, Max sensors)
- **Panel & Desktop modes** (Compact temperature readout in panels, full sensor list on desktop)

## Prerequisites (Fedora)
```bash
sudo dnf install lm_sensors
sudo sensors-detect --auto
```

## Installation
```bash
chmod +x install.sh
./install.sh
```

Then right-click your desktop → **Add Widgets...** → search **Thermal Monitor Pro**.

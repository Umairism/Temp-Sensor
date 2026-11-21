# Publishing playbook

How Thermal Monitor Pro goes from this repository to a polished, discoverable Linux contribution. Do the steps in order.

## 1. Release readiness (code side) — done in-tree

- [x] Correct widget behavior on panel and desktop form factors
- [x] `metadata.json` complete: unique id, keywords, BugReportUrl, SPDX license, version 1.1.0+
- [x] LICENSE file (GPL-3.0-or-later)
- [x] `package/` layout, `scripts/build-plasmoid.sh`, CI validation, tag-triggered release with `.plasmoid` artifact
- [x] README with requirements, install, troubleshooting; CONTRIBUTING; CHANGELOG

## 2. Screenshots (required by the store)

The in-app preview cannot show Plasma. Capture on a real Plasma 6 session with `plasmawindowed` (or the widget placed on the desktop):

1. `hero.png` — desktop widget with several sensors, mid-range temperatures (annotate the compact panel next to it if cropping fits)
2. `panel.png` — horizontal panel showing the compact hottest-temperature readout
3. `config.png` — the Configure dialog (thresholds + sensor selection visible)
4. `critical.png` — optional but effective: a sensor driven above its critical threshold showing the notification

Store tips: 1920×1080, real theme (light *and* dark is a bonus), no personal desktop clutter, crop tightly, PNG. Put them in `docs/screenshots/` (git) and reuse them for both GitHub Release notes and the store listing.

## 3. KDE Store submission

1. Create / sign into an account at <https://store.kde.org>.
2. **Submit new addon** → category **Plasma 6 → Widgets** (a.k.a. "Plasma Desktop Applets").
3. Fill in: name ("Thermal Monitor Pro" — search first to avoid an exact clash), a description derived from the README features list, tags/keywords matching `metadata.json`, license **GPL-3.0-or-later**, Plasma 6 as target.
4. Upload the `.plasmoid` from the GitHub release and the screenshots above; link the repository and issue tracker.
5. Review is typically quick for QML-only applets; the store enforces metadata consistency (license/version) more than review-by-human. Keep `metadata.json` and the store listing in sync on every release.

## 4. After the store listing exists

- Announce in [KDE Discuss — Plasma](https://discuss.kde.org/c/plasma) ("Show and Tell" rules: describe, don't spam; link repo + store).
- Submit to awesome lists (e.g. awesome-kde) via PR.
- Distribution packaging (each just needs the `.plasmoid` and metadata):
  - **AUR** (`plasma6-applets-thermal-monitor-pro`) — trivial PKGBUILD using the release artifact
  - **Fedora COPR** — rpmbuild spec with `kf6-kpackage` build dep, `%build` = `kpackagetool6 --install` target or plain file install into `%{_datadir}/plasma/plasmoids/`
  - **openSUSE OBS** — same shape as COPR
  - **Nix** — `plasma6Packages.mkKpackage` in nixpkgs (needs a reviewer from nixpkgs)

## 5. Optional: deeper KDE involvement

If the widget proves its worth, the natural next step is upstreaming improvements rather than the applet itself: `ksystemstats` (sensor backend — e.g. better NVMe/GPU labels, new chip support) and documentation on develop.kde.org. Maintainer sponsorship via [KDE invent](https://invent.kde.org) is the route for anything merged into KDE proper.

## Checklist per release

- [ ] `Version` bumped in `package/metadata.json`, CHANGELOG entry written
- [ ] `scripts/build-plasmoid.sh` succeeds; tag `vX.Y.Z`; GitHub release carries the `.plasmoid`
- [ ] Fresh screenshots committed
- [ ] Store listing updated (new version + changelog + screenshots)
- [ ] README "Installation from release" still accurate

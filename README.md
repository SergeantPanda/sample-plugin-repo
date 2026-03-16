# Plugin Releases

This branch contains all published plugin releases.

## Quick Access

- [manifest.json](./manifest.json) - Complete plugin registry with metadata
- [releases/](./releases/) - All plugin ZIP files
- [metadata/](./metadata/) - Version metadata with checksums

## Available Plugins

| Plugin | Version | Owner | Description |
|--------|---------|-------|-------------|
| [`Dispatcharr Exporter`](#dispatcharr-exporter) | `2.4.0` | sethwv | Expose Dispatcharr metrics in Prometheus exporter-compatible format for monitoring |
| [`old-proof-of-concept`](#old-proof-of-concept) | `0.1.0` | sethwv | A cool description |
| [`Weatharr Station`](#weatharr-station) | `2.0.0` | OkinawaBoss | Start a local WeatherStream broadcast and publish it as a channel. |

---

### Dispatcharr Exporter

**Version:** `2.4.0` | **Owner:** sethwv | **Last Updated:** 2026-03-16T18:57:47-04:00

Expose Dispatcharr metrics in Prometheus exporter-compatible format for monitoring

**Downloads:**
- [Latest Release (`2.4.0`)](https://github.com/sethwv/sample-plugin-repo/raw/releases/releases/dispatcharr-exporter/dispatcharr-exporter-latest.zip)
- [All Versions (1 available)](./releases/dispatcharr-exporter)


**Maintainers:** sethwv-alt | **Source:** [Browse](https://github.com/sethwv/sample-plugin-repo/tree/main/plugins/dispatcharr-exporter) | **Last Change:** [`594de34`](https://github.com/sethwv/sample-plugin-repo/commit/594de3454ecc7d6859800991e895a4f84e979ffb)

---

### [old-proof-of-concept](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/old-proof-of-concept/README.md)

**Version:** `0.1.0` | **Owner:** sethwv | **Last Updated:** 2026-03-16T18:27:35-04:00

A cool description

**Downloads:**
- [Latest Release (`0.1.0`)](https://github.com/sethwv/sample-plugin-repo/raw/releases/releases/old-proof-of-concept/old-proof-of-concept-latest.zip)
- [All Versions (1 available)](./releases/old-proof-of-concept)


**Maintainers:** sethwv-alt | **Source:** [Browse](https://github.com/sethwv/sample-plugin-repo/tree/main/plugins/old-proof-of-concept) | [README](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/old-proof-of-concept/README.md) | **Last Change:** [`c68c06e`](https://github.com/sethwv/sample-plugin-repo/commit/c68c06eb069fd86c2294ad0c976055936d8a593e)

---

### [Weatharr Station](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/weatharr-station/README.md)

**Version:** `2.0.0` | **Owner:** OkinawaBoss | **Last Updated:** 2026-03-16T18:27:35-04:00

Start a local WeatherStream broadcast and publish it as a channel.

**Downloads:**
- [Latest Release (`2.0.0`)](https://github.com/sethwv/sample-plugin-repo/raw/releases/releases/weatharr-station/weatharr-station-latest.zip)
- [All Versions (1 available)](./releases/weatharr-station)


**Maintainers:** OkinawaBoss, sethwv-alt | **Source:** [Browse](https://github.com/sethwv/sample-plugin-repo/tree/main/plugins/weatharr-station) | [README](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/weatharr-station/README.md) | **Last Change:** [`c68c06e`](https://github.com/sethwv/sample-plugin-repo/commit/c68c06eb069fd86c2294ad0c976055936d8a593e)

---

## Using the Manifest

Fetch `manifest.json` to programmatically access plugin metadata and download URLs:

```bash
curl https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json
```

---

*Last updated: 2026-03-16 23:03:50 UTC*

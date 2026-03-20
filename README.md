# Plugin Releases

This branch contains all published plugin releases.

## Quick Access

- [manifest.json](./manifest.json) - Complete plugin registry with metadata
- [releases/](./releases/) - All plugin ZIP files
- [metadata/](./metadata/) - Version metadata with checksums

## Available Plugins

| Plugin | Version | Owner | Description |
|--------|---------|-------|-------------|
| [`Cool Test Plugin`](#cool-test-plugin) | `0.1.0` | sethwv-alt | A cool description |
| [`old-proof-of-concept`](#old-proof-of-concept) | `0.1.0` | sethwv | A cool description |

---

### Cool Test Plugin

**Version:** `0.1.0` | **Owner:** sethwv-alt | **Last Updated:** 2026-03-20T09:43:12-04:00

A cool description

**Downloads:**
- [Latest Release (`0.1.0`)](https://github.com/sethwv/sample-plugin-repo/raw/releases/releases/my-cool-test-plugin/my-cool-test-plugin-latest.zip)
- [All Versions (1 available)](./releases/my-cool-test-plugin)

**Source:** [Browse](https://github.com/sethwv/sample-plugin-repo/tree/main/plugins/my-cool-test-plugin) | **Last Change:** [`b0833ed`](https://github.com/sethwv/sample-plugin-repo/commit/b0833ed39b83b6d956e016bcafe7272cdfca51eb)

---

### [old-proof-of-concept](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/old-proof-of-concept/README.md)

**Version:** `0.1.0` | **Owner:** sethwv | **Last Updated:** 2026-03-20T09:58:38-04:00

A cool description

**Downloads:**
- [Latest Release (`0.1.0`)](https://github.com/sethwv/sample-plugin-repo/raw/releases/releases/old-proof-of-concept/old-proof-of-concept-latest.zip)
- [All Versions (1 available)](./releases/old-proof-of-concept)

**Maintainers:** sethwv-alt-zzz | **Source:** [Browse](https://github.com/sethwv/sample-plugin-repo/tree/main/plugins/old-proof-of-concept) | [README](https://github.com/sethwv/sample-plugin-repo/blob/main/plugins/old-proof-of-concept/README.md) | **Last Change:** [`06102ef`](https://github.com/sethwv/sample-plugin-repo/commit/06102ef9e17680f867f98d918e5b3e7d8c6dc84a)

---

## Using the Manifest

Fetch `manifest.json` to programmatically access plugin metadata and download URLs:

```bash
curl https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json
```

---

*Last updated: 2026-03-20 13:58:56 UTC*

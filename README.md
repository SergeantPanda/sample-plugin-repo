# Dispatcharr Plugin Repository

A repository for publishing and distributing Dispatcharr Python plugins with automated validation and release management.

## Quick Links

| Resource | Description |
|----------|-------------|
| [Browse Plugins](https://github.com/sethwv/sample-plugin-repo/tree/releases) | All available plugins on the releases branch |
| [Plugin Manifest](https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json) | Plugin metadata, checksums, and download URLs |
| [Download Releases](https://github.com/sethwv/sample-plugin-repo/tree/releases/releases) | Plugin ZIP files |
| [View Metadata](https://github.com/sethwv/sample-plugin-repo/tree/releases/metadata) | Version metadata with commit info and checksums |

## How It Works

Each plugin lives in `plugins/<plugin-name>/` and must contain a valid `plugin.json`. When a PR is merged to `main`, plugins are automatically packaged and published to the [`releases` branch](https://github.com/sethwv/sample-plugin-repo/tree/releases).

### PR Validation

Every PR runs automated validation that checks:

- Folder name is lowercase-kebab-case
- `plugin.json` is valid and contains required fields
- Version is incremented for existing plugins
- PR author is listed in `owner` or `maintainers`
- `.github/` files are not modified by non-maintainers
- Python code is scanned by CodeQL (required check)

PRs where the author has no permission for any modified plugin are automatically closed with instructions.

Results are posted as a comment on the PR.

### Publishing

On merge to `main`, each plugin is:

- Packaged into a versioned ZIP (`plugin-name-1.0.0.zip`) and a latest ZIP (`plugin-name-latest.zip`)
- Given MD5 and SHA256 checksums
- Listed in `manifest.json` with download URLs and metadata
- Only the 10 most recent versioned ZIPs are kept per plugin

## Contributing

### Adding or Updating a Plugin

This repository is for publishing plugins to the official Dispatcharr plugin manifest. Development and testing should happen in your own repository first. Once your plugin is stable, submit a PR here to publish it.

1. Fork the repository and create a branch
2. Create or modify your plugin folder under `plugins/your-plugin-name/`
3. Submit a pull request to `main`

For updates, increment the version in `plugin.json`.

### `plugin.json` Required Fields

```json
{
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "A brief description of what the plugin does",
  "owner": "github-username"
}
```

- `name`, `version`, `description` are required
- At least one of `owner` or `maintainers` must include your GitHub username - these are not part of the Dispatcharr spec but are required by this repository to manage who can submit PRs for each plugin
- Plugin folder names must be lowercase-kebab-case

**Optional fields:**
- `maintainers` - Array of additional GitHub usernames who can submit PRs for this plugin
- `min_dispatcharr_version` - Minimum Dispatcharr version required (e.g. `v0.19.0` or `0.19.0`)
- `max_dispatcharr_version` - Maximum Dispatcharr version supported (e.g. `v1.2.0` or `1.2.0`). Must be ≥ `min_dispatcharr_version` if both are set.
- `repo_url` - URL to the plugin's source repository
- `discord_thread` - URL or ID of the associated Discord thread
- `deprecated` - Marks plugin as deprecated (default: `false`)
- `unlisted` - Hides plugin from the releases README (default: `false`)
- `license` - [OSI-approved SPDX license identifier](https://spdx.org/licenses/) for your plugin (e.g. `MIT`, `Apache-2.0`, `GPL-3.0-only`). If omitted, the plugin is distributed under the repository's [AGPL-3.0](https://spdx.org/licenses/AGPL-3.0-only.html) license by default.

## Licensing

Plugins submitted to this repository must be distributed under an [OSI-approved open source license](https://opensource.org/licenses). Specify your license using the `license` field in `plugin.json` with a valid [SPDX identifier](https://spdx.org/licenses/) (e.g. `"license": "MIT"`).

If no `license` field is provided, your plugin will be distributed under the same [AGPL-3.0](https://spdx.org/licenses/AGPL-3.0-only.html) license as this repository. By submitting a plugin without a `license` field, you agree to these terms.

## Versioning

Plugins use semantic versioning (`MAJOR.MINOR.PATCH`). Version increments are enforced by the validation workflow.

## Downloading Plugins

Visit the [releases branch](https://github.com/sethwv/sample-plugin-repo/tree/releases) to browse and download plugins, or fetch `manifest.json` programmatically:

```bash
curl https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json
```
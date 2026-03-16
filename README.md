# Dispatcharr Plugin Repository

A centralized repository for publishing and distributing Dispatcharr Python plugins with automated validation, versioning, and release management.

## Quick Links

| Resource | Description |
|----------|-------------|
| [**Browse Plugins**](https://github.com/sethwv/sample-plugin-repo/tree/releases) | View all available plugins on the releases branch |
| [**Plugin Manifest**](https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json) | JSON file with complete plugin metadata, checksums, and URLs |
| [**Download Releases**](https://github.com/sethwv/sample-plugin-repo/tree/releases/releases) | Direct access to all plugin ZIP files |
| [**View Metadata**](https://github.com/sethwv/sample-plugin-repo/tree/releases/metadata) | Version metadata with commit info and checksums |

## How It Works

### Repository Structure

```
plugins/
├── plugin-name-1/
│   ├── plugin.json      # Plugin metadata and configuration
│   ├── README.md        # Plugin documentation
│   └── plugin.py        # Plugin entry point
└── plugin-name-2/
    ├── plugin.json
    ├── README.md
    └── ...
```

### Automated Workflow

#### 1. **Pull Request Validation** (`validate-plugin.yml`)

When you submit a PR to update or add a plugin:

- **Folder Name Validation**: Ensures plugin folder names use lowercase-kebab-case (lowercase letters, numbers, and hyphens only)
- **Ownership Verification**: Ensures only the plugin owner, listed maintainers, or repository maintainers can modify plugins
- **Structure Validation**: Checks for required files (`plugin.json`, `README.md`)
- **JSON Validation**: Verifies `plugin.json` is valid and contains required fields (`name`, `version`, `owner`, `maintainers`, `description`)
- **Version Enforcement**: For existing plugins, ensures the version is semantically incremented (e.g., `1.0.0` → `1.0.1`)
- **Multi-Plugin Support**: Validates permissions for each plugin when multiple plugins are modified in one PR
- **Draft PR Protection**: Validation only runs when PRs are marked "ready for review"

The workflow posts a detailed validation report as a comment on your PR, showing which checks passed or failed.

#### 2. **Automated Publishing** (`publish-plugins.yml`)

Once your PR is merged to `main`:

- **Automatic ZIP Creation**: Each plugin is packaged into versioned and latest ZIPs
  - `plugin-name-1.0.0.zip` (versioned)
  - `plugin-name-latest.zip` (always points to the newest version)
- **Checksums Generated**: MD5 and SHA256 checksums calculated for integrity verification
- **Metadata Files**: JSON metadata for each version with commit SHA, checksums, and timestamps
- **Per-Plugin Manifests**: Individual manifest.json files for each plugin in the metadata folder
- **Retention Policy**: Only the 10 most recent versioned ZIPs are kept per plugin
- **Manifest Generation**: A `manifest.json` file is generated with complete metadata and download URLs for all plugins
- **Release Branch**: All artifacts are published to the [`releases` branch](https://github.com/sethwv/sample-plugin-repo/tree/releases)
- **Auto-Generated README**: An enhanced README on the releases branch with:
  - Table of contents with anchor links
  - Alphabetically sorted plugins
  - Deprecated plugin section (conditionally shown)
  - README links for each plugin
  - Download links with checksums
  - Source code and commit history links

## Contributing a Plugin

### Adding a New Plugin

1. **Fork the repository** and create a new branch
2. **Create your plugin folder** under `plugins/your-plugin-name/`
3. **Add required files**:
   - `plugin.json` - Plugin metadata
   - `README.md` - Plugin documentation *(optional)*
   - Source files (e.g., `plugin.py`)
4. **Submit a pull request** to `main`

### Updating an Existing Plugin

1. **Fork the repository** and create a new branch
2. **Modify files** in `plugins/your-plugin-name/`
3. **Increment the version** in `plugin.json` (e.g., `1.0.0` → `1.0.1`)
4. **Submit a pull request** to `main`

### `plugin.json` Required Fields

Your `plugin.json` must include the following fields to pass validation:

```json
{
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "A brief description of what the plugin does",
  "owner": "github-username"
}
```

- `name`: Display name of the plugin
- `version`: Semantic version (e.g., `1.0.0`)
- `description`: Brief explanation of plugin functionality
- `owner` / `maintainers`: At least one must be present and include your GitHub username. These are not part of the Dispatcharr spec but are required by this repository to manage contribution permissions.

**Optional repository fields:**
- `maintainers`: Array of additional GitHub usernames who can submit PRs for this plugin
- `deprecated`: Boolean (default: `false`) - Marks plugin as deprecated
- `unlisted`: Boolean (default: `false`) - Hides plugin from the releases README while keeping it in the manifest and releases

**Important:** Plugin folder names must use lowercase-kebab-case (e.g., `my-awesome-plugin`, not `My_Awesome_Plugin`).

### PR Requirements & Validation

**Your PR must**:
- Use lowercase-kebab-case for plugin folder names (e.g., `my-plugin`, not `My_Plugin`)
- Be submitted by the plugin owner, a listed maintainer, or a repository maintainer (for each modified plugin)
- Include valid `plugin.json` for each plugin (`README.md` is optional)
  - Include your GitHub username in `owner`, `maintainers`, or both — at least one must be present in `plugin.json`
- Use semantic versioning (`MAJOR.MINOR.PATCH`)
- Increment the version for updates to existing plugins
- Have proper permissions for all modified plugins

**Your PR will fail if**:
- Plugin folder name contains uppercase letters, underscores, or spaces
- Required files are missing
  - `plugin.json` is invalid, missing required fields, or missing your GitHub username from both `owner` and `maintainers`
- Version is not incremented (for existing plugins)
- Submitter lacks permission for any modified plugin

**Note:** You can modify multiple plugins in a single PR as long as you have proper permissions for all of them.

## Downloading Plugins

### For End Users

Visit the [**releases branch**](https://github.com/sethwv/sample-plugin-repo/tree/releases) to:
- Browse available plugins in the auto-generated README with table of contents
- Download the latest version: `releases/plugin-name/plugin-name-latest.zip`
- Download specific versions: `releases/plugin-name/plugin-name-1.0.0.zip`
- Verify downloads using provided MD5 and SHA256 checksums

### For Applications

Use the `manifest.json` on the releases branch to programmatically access plugin metadata and download URLs:

```bash
curl https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json
```

**The manifest includes:**
- Plugin metadata (name, version, owner, description)
- Download URLs for all versions
- MD5 and SHA256 checksums for verification
- Git commit SHA for traceability
- Build timestamps
- Latest version metadata at top level for easy access

**Example usage:**
```bash
# Get latest version of a plugin
VERSION=$(curl -s https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json | jq -r '.plugins[] | select(.name=="my-plugin") | .version')

# Download and verify
URL=$(curl -s https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json | jq -r '.plugins[] | select(.name=="my-plugin") | .latest_url')
CHECKSUM=$(curl -s https://raw.githubusercontent.com/sethwv/sample-plugin-repo/releases/manifest.json | jq -r '.plugins[] | select(.name=="my-plugin") | .latest_checksum_sha256')

curl -L "$URL" -o plugin.zip
echo "$CHECKSUM  plugin.zip" | shasum -a 256 -c
```

## Ownership & Permissions

- **Plugin Owner**: The GitHub user specified in `plugin.json` `owner` field
- **Maintainers**: Additional GitHub users listed in `plugin.json` `maintainers` array
- **Repository Maintainers**: Users with write/admin access to this repository

Only these users can submit PRs that modify a given plugin.

## Versioning

This repository uses **semantic versioning** for plugins:

- `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)
- **PATCH**: Bug fixes and minor changes (`1.0.0` → `1.0.1`)
- **MINOR**: New features, backward compatible (`1.0.0` → `1.1.0`)
- **MAJOR**: Breaking changes (`1.0.0` → `2.0.0`)

Version increments are **enforced** by the validation workflow.
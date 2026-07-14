# esparformctl

A CLI for managing espar form.

[日本語](README.ja.md)

- Use `--json` to produce JSON output.
- Commands that modify data (`mail update`, `setting set`, and `form set`) display the changes and ask for confirmation before applying them.
- Credentials (access tokens) are stored securely and separately for each profile. They are never written to output or logs.

## Installation

### Install script (macOS/Linux)

```sh
curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh | sh
```

To specify a version or installation directory:

```sh
ESPARFORMCTL_VERSION=v1.2.3 INSTALL_DIR=$HOME/.local/bin \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/feedtailor/espar-esparformctl/main/scripts/install.sh)"
```

The script detects the OS and architecture and installs the appropriate binary. It requires `curl` and `tar`.

- `ESPARFORMCTL_VERSION`: Specify a version such as `v1.2.3`. The leading `v` is optional. If omitted, the latest release (`latest`) is installed.
- `INSTALL_DIR`: Defaults to `~/.local/bin` on macOS and `/usr/local/bin` on Linux. If `~/.local/bin` is not in `PATH`, follow the instructions displayed after installation to add it.

### Update

To update to the latest version, run the installation script again. It overwrites the existing binary.

### Manual installation

Download `esparformctl_<version>_<os>_<arch>.tar.gz` from [Releases](https://github.com/feedtailor/espar-esparformctl/releases) (`.zip` on Windows), extract it, and place the executable in a directory included in `PATH`.

### Windows

The installation script does not support Windows. Install the CLI manually:

1. Download `esparformctl_<version>_windows_amd64.zip` from [Releases](https://github.com/feedtailor/espar-esparformctl/releases), or `_windows_arm64.zip` for Arm
2. Extract `esparformctl.exe`
3. Place it in a directory included in `PATH`, or add its directory to `PATH`
4. Verify the installation in PowerShell or Command Prompt

```powershell
esparformctl.exe --version
```

### Check the version

```sh
esparformctl --version
```

## Authentication (`login`)

```sh
# Log in with the target site's hostname
esparformctl login --hostname=<hostname>
# Enter the password at the hidden terminal prompt; passwords are not accepted as arguments

# In an interactive terminal, omitting --hostname prompts for the hostname as well
esparformctl login
```

- If `--hostname` is omitted in an **interactive terminal**, enter the hostname at the `hostname: ` prompt.
- For **non-interactive input** such as a pipe or redirection, or when using `--password-stdin` or `--json`, prompts are disabled and `--hostname` is required. Omitting it causes an error.

To pass a password non-interactively from a script or Skill:

```sh
printf '%s' "$PASSWORD" | esparformctl login --hostname=www.example.com --password-stdin
```

The credentials are stored by profile in the `credentials` file under the configuration directory. If `--profile` is omitted, the `default` profile is created or updated. See [Profiles](#profiles-switching-between-multiple-hostnames) to use multiple hostnames and [Configuration files](#configuration-files) for storage locations.

## `logout` (delete a profile)

Use `logout` to delete stored credentials for a profile.

```sh
# Log out of the current profile (confirmation required; use --yes to skip it)
esparformctl logout

# Log out of a specific profile
esparformctl logout --profile shop

# From a script or Skill (--json requires --yes)
esparformctl logout --json --yes
```

## Profiles (switching between multiple hostnames)

You can store credentials for **multiple hosts at the same time** and switch between them. Use `--profile` to assign a profile name.

```sh
# Create a profile for each site (profile names are arbitrary)
esparformctl login --profile=www --hostname=www.espar.biz
esparformctl login --profile=shop --hostname=shop.espar.biz

# Select the profile to use (the default profile is used when --profile is omitted)
esparformctl --profile=shop setting get espf

# Set a profile for the current shell session
export ESPARFORMCTL_PROFILE=shop

# List profiles
esparformctl profile list

# Delete a profile (confirmation required; use --yes to skip it)
esparformctl profile delete shop
```

Profile selection follows this precedence: **`--profile` flag > `ESPARFORMCTL_PROFILE` environment variable > `default`**.

## Command reference

### `auth status` — Check login status

Displays the login status, active profile, and hostname. This command is read-only and never outputs the access token.

```sh
esparformctl auth status [--json]
```

```json
{ "logged_in": true, "profile": "www", "hostname": "www.espar.biz",
  "token_expired": false, "expires_at": "2026-07-15T11:14:00+09:00", "source": "server" }
```

- **Being logged out is returned as a status, not an error**: `logged_in` is `false`, the other fields are `null`, and the exit code is 2. Because this command is read-only, `--yes` is not required with `--json`.
- Use `--all` to show the status of every saved profile. With `--json`, the output has the form `{"profiles": [...]}`. If a profile lookup fails, results for the other profiles are still returned and the failure appears in that entry's `error` field. The exit code is 0 if every profile is logged in, or 2 if at least one profile is logged out or could not be queried. `--all` cannot be used with `--profile`.

### `form` — Get form IDs and API keys

```sh
esparformctl form list [--json]
esparformctl form get <formID> [--json]
```

- The output fields are `id`, `name`, `url`, and `api_key`. `get` returns one form, while `list` returns a `forms` array.
- `api_key` is a **public value** embedded in HTML, so it is displayed without masking.
- When passing `api_key` to AI or automation tools, **do not allow it to be included in AI training, telemetry, or feedback**.

### `form set` — Change the form name or installation URL

```sh
esparformctl form set <formID> --name="Contact (Production)"
esparformctl form set <formID> --url=https://www.example.com/contact/
```

- **Only the specified flags are updated**; unspecified fields remain unchanged. An empty value (`--name=` or `--url=`) **clears the field**.
- Only URLs using `http` or `https` are valid. Validation is performed by the server, and invalid values produce an input error.
- As with `setting set`, the changes are displayed for confirmation before they are applied. `--dry-run` and `--json --yes` work the same way.
- Of the fields returned by `form get`, **only `api_key` is read-only**.

### `form logs` — Inspect email delivery results (read-only)

Displays the form's email history in reverse chronological order, including the send time, message type (notification or auto-reply), and delivery result. Use it to diagnose cases where a form submission succeeds but no email arrives. If no entry appears after a submission, no email was generated because the template is missing or disabled. If an entry exists and its `status` indicates failure, the issue is with delivery.

```sh
esparformctl form logs <formID> [--date <YYYY-MM[-DD]>] [--json]
```

```sh
# Show recent delivery results (latest 20)
esparformctl form logs espf

# Show every result for a specific day
esparformctl form logs espf --date 2026-07-08

# Get every result for a month as JSON
esparformctl form logs espf --date 2026-07 --json
```

- Without `--date`, the command displays the **latest 20 entries**. Use `--date` with a day (`YYYY-MM-DD`) or month (`YYYY-MM`) to display **all entries for that period**. Dates without hyphens (`20260708` or `202607`) are also accepted.
- The delivery result (`status`) is **updated asynchronously at intervals of about 10 minutes**. Immediately after sending, it is pending (`status` is `null` with `--json`), so wait and query again.
- Common `status` values are `sent`, `deferred`, `bounced`, `expired`, `skipped`, and `error`. Additional values may be introduced in the future.
- Queries cover the latest 12 months. If older history is available, a notice appears at the end of the output (`has_more` is `true` with `--json`).
- Recipients, senders, and other personal information are not displayed. The history is read-only and cannot be deleted or modified.
- Each output line contains one entry, so you can filter the results with `head`, `tail`, `grep`, or `jq`.

### `mail get` — Retrieve email templates (TOML)

Outputs notification and auto-reply email templates as TOML. The output can be passed directly to `mail update --mail-file` for a get-edit-update workflow.

```sh
# Retrieve as TOML
esparformctl mail get <formID>

# Retrieve, edit, and apply
esparformctl mail get <formID> > mail.toml
$EDITOR mail.toml
esparformctl mail update <formID> --mail-file mail.toml

# Output as JSON
esparformctl mail get <formID> --json
```

- The first line of the output is `etag = "..."`. Keep this line when passing the output to `mail update`.
- **Concurrent update detection**: The `etag` line allows `mail update` to warn automatically if another user changed the form after `mail get` ran. With `--json`, `warnings` contains `stale_input`. The warning does not prevent the update; the diff is always calculated against the latest settings. Use `--dry-run` to inspect the diff and warnings without applying the changes.

### `mail sample` — Generate a TOML template (no login required)

Outputs a commented TOML template for writing an email template from scratch. It does not require login or a server connection.

```sh
# Generate, edit, and apply a template
esparformctl mail sample > mail.toml
$EDITOR mail.toml
esparformctl mail update <formID> --mail-file mail.toml
```

- Comments explain the update rules: writing a key updates it, setting it to `""` clears it, and omitting it leaves it unchanged. Optional fields are commented out. **Leave unused lines commented out**; applying them as `""` clears those fields.
- To start from the current settings, use `mail get`. Use `sample` to write a template from scratch and `get` to edit the current values.
- `--json` is not supported because the output is always TOML. Specifying it causes an error. Use `mail get --json` to inspect existing content as JSON.

### `mail update` — Update email templates

Pass **TOML containing only the fields to update** with `--mail-file`. Use `-` to read from `stdin`. You can extract only the required sections from a local `espf.toml` file. Output from `mail get`, including its `etag` line, can also be passed directly.

```sh
# Update the notification email subject (set subject = "..." in [notification.mail])
esparformctl mail update <formID> --mail-file ./mail.toml

# Warn about template variables that do not match the form fields (--known-fields)
esparformctl mail update <formID> --mail-file ./mail.toml --known-fields name,email,message --dry-run

# Preview the diff without applying it (--dry-run)
esparformctl mail update <formID> --mail-file ./mail.toml --dry-run

# Read from stdin
cat <<'TOML' | esparformctl mail update <formID> --mail-file -
[notification]
enabled = true

[notification.mail]
subject = "Thank you for contacting us"
to = "ops@example.com"
TOML
```

- Structure: `enabled` and `allow_attach` (`bool`) under `[notification]` or `[reply]`; `from`, `subject`, `body`, `to`, `cc`, `bcc`, and `reply_to` (strings) under `[notification.mail]` or `[reply.mail]`.
- **Before applying the update, the command compares the input with the current values and updates only the fields that actually changed**. A key set to its current value remains unchanged, `""` clears a non-empty value, and an omitted key remains unchanged. Cleared fields appear in `cleared_fields`. When the output of `mail get` is passed directly, only the edited fields appear in the diff. If nothing changed, the command displays "No changes" and exits.
- Recipients (`to`, `cc`, `bcc`, and `reply_to`) are **text values in standard email-header format**. Multiple recipients can be separated by commas.
- Write `body` directly as a TOML multiline string (`"""..."""`). A value beginning with `@` is also sent **as a literal string** and is not expanded as a file.
- **`--dry-run`** (short form: `-n`): Displays the diff and warnings as usual, but exits without applying changes or showing a confirmation prompt. The exit code is 0 whether or not the input contains changes. `--json --dry-run` produces the normal update result with `dry_run` set to `true`. **`--yes` is not required**.
- **Change detection after retrieval**: If the input TOML starts with an `etag` line from `mail get`, the command warns when another user has changed the form since it was retrieved. With `--json`, `warnings` contains `stale_input`. The warning does not prevent the update.
- **Template variable validation (`--known-fields`)**: Pass the form's actual field names (`name` attributes) as a comma-separated list to warn about `{{ .xxx }}` variables that do not exist in the form. With `--json`, `warnings` contains `unknown_template_var`. The warning does not prevent the update. Built-in variables such as `{{ .espf_date }}` are excluded. Without this option, no validation is performed. Combine it with `--dry-run` to detect mismatches that would leave template content blank before using the template.

### `setting` — Retrieve or change form settings

```sh
esparformctl setting get <formID> [--json]

esparformctl setting set <formID> \
  --allow-http=false \
  --allow-localhost=true \
  --token-expiration=90m \
  --send-rate-limit=60s
```

- `setting get` displays eight settings (`allow_http`, `allow_localhost`, `allowed_referers`, `token_expiration`, `send_rate_limit`, `date_format`, `time_format`, and `list_delimiter`) and the `etag`.
- `setting set` can change **seven settings other than `allowed_referers`**: `--allow-http`, `--allow-localhost`, `--token-expiration`, `--send-rate-limit`, `--date-format`, `--time-format`, and `--list-delimiter`.
- **Only the specified flags are updated**; settings for omitted flags remain unchanged. An empty value for a string flag, such as `--token-expiration=`, **resets the setting to its default value**.
- **Duration format**: Specify `--token-expiration` and `--send-rate-limit` as **positive durations** with units, such as `30s`, `10m`, or `1h30m`. A unitless value such as `10`, a negative value, or `0s` produces an error before the request is sent.
- **Allowed source hosts can be displayed but not changed** from the CLI. Contact the administrator if they need to be changed.
- Deny-list settings cannot be displayed or changed from the CLI. Use the administration interface instead.
- **`--dry-run`**: Displays the diff without applying it. It behaves like `mail update --dry-run`, exits with code 0, and does not require `--yes` with `--json --dry-run`.

## JSON output (`--json`)

Scripts and automation can rely on the following behavior:

- `--json`: Writes one JSON object to `stdout`.
- `--yes`: Skips confirmation prompts. **`--yes` is required when using `--json` for a write operation** (`mail update`, `setting set`, `form set`, or `logout`). Omitting it causes an error. As an exception, `--json --dry-run` does not require `--yes` because a dry run does not write data.
- Confirmation prompts and diagnostics are written to `stderr`; results are written to `stdout`.
- Error output is JSON with an `error` object containing `code`, `message`, and `request_id`. Update results contain `updated_fields`, `unchanged_fields`, `cleared_fields`, `etag`, and `warnings`. For `--dry-run` only, `dry_run` is `true`.
- **Use `auth status --json` to check whether the CLI is logged in**. It is lightweight because it does not retrieve form data, and you can check either the exit code or the JSON result.

### Exit codes

| Error code | Meaning | Exit code |
|------------|---------|-----------|
| (none) | Success | `0` |
| `validation_error` | Input validation failed | `1` |
| `auth_required` | Not logged in | `2` |
| `auth_expired` | Access token expired | `3` |
| `auth_invalid` | Access token is invalid | `4` |
| `permission_denied` | Insufficient permissions | `5` |
| `conflict` | Conflict (ETag mismatch or omission) | `6` |
| `not_found` | Resource not found | `7` |
| `network_error` | Network failure | `8` |
| `non_interactive_required` | `--yes` omitted for a JSON write operation | `9` |
| `api_error` | Other server error | `10` |
| `usage_error` | Invalid command usage | `64` |
| `internal_error` | Internal error | `70` |

## Configuration files

Credentials are stored as TOML under `<config-dir>/esparformctl/`.

| File | Contents |
|------|----------|
| `<config-dir>/esparformctl/credentials` | Credentials, with access tokens separated by profile |

`<config-dir>` resolves as follows:

| OS | `<config-dir>` |
|----|----------------|
| Linux | `$XDG_CONFIG_HOME`, or `~/.config` if unset |
| macOS | `$XDG_CONFIG_HOME` if it is set to an absolute path; otherwise `~/Library/Application Support` |
| Windows | `%AppData%`; `XDG_CONFIG_HOME` is ignored |

> **Note:** Changing `XDG_CONFIG_HOME` on macOS does **not automatically migrate** files from `~/Library/Application Support/esparformctl/`. Run `login` again for the new location or move the files manually.

Credentials (access tokens) are never written to `stdout`, `stderr`, logs, errors, or JSON output.

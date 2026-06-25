# Shotup Developer Sync Scripts

These scripts provide reusable local validation for the Shotup Cloud development sync pipeline.

They assume the Vapor API server is already running at:

```text
http://127.0.0.1:8080
```

You can override the API base URL with:

```bash
SHOTUP_API_BASE_URL=http://127.0.0.1:8080 ./scripts/smoke-test.sh
```

## Scripts

- `dev-login.sh`: calls development login and prints only the access token.
- `sync-project.sh`: logs in and upserts the test project.
- `sync-scene.sh`: logs in and upserts the test scene under the test project.
- `sync-shot.sh`: logs in and upserts the test shot under the test scene.
- `sync-download.sh`: logs in and requests a download sync with empty changes.
- `smoke-test.sh`: runs project, scene, shot, and download sync scripts in order.

## Usage

Make the scripts executable:

```bash
chmod +x scripts/*.sh
```

Run the full smoke test:

```bash
./scripts/smoke-test.sh
```

The smoke test stops on the first failure.

## Requirements

- `bash`
- `curl`
- `python3`
- A running local Shotup Cloud API server

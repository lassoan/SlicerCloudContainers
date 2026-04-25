# SlicerCloudContainers
Repository storing containers for SlicerCloud services

## linux-desktop local storage config

For `linux-desktop/start-container.sh` and `linux-desktop/start-container.bat`:

- Keep all container environment variables in `linux-desktop/.env.local` (local-only, ignored by git).
- Ensure `STORAGE_DIR` is set in `linux-desktop/.env.local`.
- Container config is stored under `STORAGE_DIR/config`.
- Use `linux-desktop/.env.local.example` as the template.

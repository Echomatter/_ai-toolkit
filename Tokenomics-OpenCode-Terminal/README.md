# Tokenomics OpenCode Terminal

Reserved for a native terminal UI module: sidebar, approval dialogs and detailed
activity/economics screens. This folder is a design stub, not an installable npm
package. OpenCode CLI support is already supplied by the Desktop/backend plugin.

## Boundary

Reuse the backend in ../Tokenomics-OpenCode-Desktop. Do not duplicate routing,
provider/authentication plumbing, native permissions, outcome recording or child
sessions. A future UI subscribes to OpenCode message-part events and renders the
backend's tokenomics_activity payload. See the [status contract](../Tokenomics-OpenCode-Desktop/docs/STATUS-EVENTS.md).

OpenCode's existing @opencode-ai/plugin host is the backend container already in use.
Publishing that backend as a versioned npm package could simplify updates later.
The current installer still owns PowerShell/Python assets and their root locator;
packaging must include and resolve those assets before an npm migration can replace it.

A native terminal extension must use the host's supported UI extension surface.
Do not assume a backend plugin can inject arbitrary TUI panels. Research the current
OpenCode interface at implementation time, keep a version compatibility check, and
avoid building an independent terminal application as scaffolding.

Reference: [OpenCode plugin documentation](https://opencode.ai/docs/plugins/) supports local and npm backend loading. No new container is needed for V1.

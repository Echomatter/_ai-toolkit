# Optional local fallback

The local model is no longer part of the default economic path because OpenCode currently exposes usable free hosted models.

Install local Qwen only when you want:

- offline development;
- local/private inference;
- insulation from temporary hosted free-model availability or rate limits.

Run:

```powershell
.\scripts\install-local-fallback.cmd
```

It installs Ollama, pulls Qwen2.5-Coder 7B, and creates a 16K-context `qwen2.5-coder:7b-16k` variant.

Automatic routing uses it only if suitable free hosted models are unavailable. To prefer local explicitly:

```powershell
.\scripts\refresh-routing.cmd -PreferLocal
```

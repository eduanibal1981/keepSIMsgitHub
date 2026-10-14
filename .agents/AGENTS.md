# KeepSIMs Operational, Cross-Platform & Deployment Rules

## 1. Backend Worker Architecture & Direct VM Deployment

The architecture maintains **two authoritative locations** for backend worker code:
1. **Local Single Source of Truth** (OS-aware workspace reference):
   - **Windows & macOS**: `../backend-sync-wt` (dedicated backend worktree / repo)
2. **Cloud Runtime**: Google Cloud Compute Engine VM (`34.40.33.208`) at `/home/abdal/keepsims_backend/servers/`

> [!IMPORTANT]
> Deployment to the Cloud VM is performed **directly via SSH/SCP** from the local worker directory (`../backend-sync-wt`). Do NOT rely on GitHub pulls on the VM.
> Ensure your SSH key is at `~/.ssh/google_compute_engine` (on macOS, set `chmod 600 ~/.ssh/google_compute_engine`).

### Mandatory Direct Synchronization Workflow

Whenever modifying backend workers or server scripts:

#### Step 1: Local Codebase Update
- Modify and test the target files in the local worker workspace (`../backend-sync-wt`).
- Run syntax verification locally (works identically in macOS `zsh` and Windows PowerShell):
  ```bash
  node --check <filename>.js
  ```

#### Step 2: Direct Cloud VM Deployment (SCP)
- Transfer the updated files directly to the Google Cloud VM servers directory using `~/.ssh/google_compute_engine`:
  ```bash
  scp -i ~/.ssh/google_compute_engine <file1> <file2> abdal@34.40.33.208:/home/abdal/keepsims_backend/servers/
  ```

#### Step 3: Syntax Verification & PM2 Restart on Cloud VM
- Connect to the VM via SSH, run `node --check`, and restart the PM2 worker processes:
  ```bash
  ssh -i ~/.ssh/google_compute_engine abdal@34.40.33.208 "node --check /home/abdal/keepsims_backend/servers/<file>.js && pm2 restart <worker-name> && pm2 status"
  ```

---

## 2. Project-Scoped Memory & Windows ↔️ Mac Handoff Rule

To avoid cross-project memory conflicts and eliminate copying `~/.gemini/antigravity/brain/` across machines:

1. **Progressive Context Loading**:
   - Use the workspace skill **`keepsims-memory`** (`.agents/skills/keepsims-memory/SKILL.md`) to load `.codex/*.md`, `.agents/memory/*.md`, and `docs/implementation-plans/*.md` on demand rather than duplicating large docs into `AGENTS.md`.
2. **Cross-Machine Handoff (`ACTIVE_HANDOFF.md`)**:
   - Whenever the user asks to **"Save handoff state"** (or before switching between Windows and Mac), you MUST update `.agents/memory/ACTIVE_HANDOFF.md` with:
     - Active task status & branch
     - Modified and untracked files
     - Exact next steps to resume seamlessly
   - Whenever the user says **"Resume from `@.agents/memory/ACTIVE_HANDOFF.md`"**, read `.agents/memory/ACTIVE_HANDOFF.md` first, check `git status`, and continue from the recorded state.

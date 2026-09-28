# KeepSIMs Deployment & Worker Modification Rule

The architecture maintains **two authoritative locations** for backend worker code:
1. **Local Single Source of Truth**: `c:\Users\abdal\Work\KeepSIMs\backend-sync-wt`
2. **Cloud Runtime**: Google Cloud Compute Engine VM (`34.40.33.208`) at `/home/abdal/keepsims_backend/servers/`

> [!IMPORTANT]
> Deployment to the Cloud VM is performed **directly via SSH/SCP** from `backend-sync-wt`. Do NOT rely on GitHub pulls on the VM.

## Mandatory Direct Synchronization Workflow

Whenever modifying backend workers or server scripts:

### 1. Local Codebase Update
- Modify and test the target files in the local workspace: `c:\Users\abdal\Work\KeepSIMs\backend-sync-wt`.
- Run syntax verification locally:
  ```powershell
  node --check <filename>.js
  ```

### 2. Direct Cloud VM Deployment (SCP)
- Transfer the updated files directly to the Google Cloud VM servers directory:
  ```powershell
  scp -i "C:/Users/abdal/.ssh/google_compute_engine" <file1> <file2> abdal@34.40.33.208:/home/abdal/keepsims_backend/servers/
  ```

### 3. Syntax Verification & PM2 Restart on Cloud VM
- Connect to the VM via SSH, run `node --check`, and restart the PM2 worker processes:
  ```bash
  ssh -i "C:/Users/abdal/.ssh/google_compute_engine" abdal@34.40.33.208 "node --check /home/abdal/keepsims_backend/servers/<file>.js && pm2 restart <worker-name> && pm2 status"
  ```

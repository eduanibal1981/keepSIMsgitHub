# KeepSIMs Deployment & Worker Modification Rule

Whenever modifying any backend code, workers, or server scripts in this codebase, the AI agent MUST strictly execute the following 3-step synchronization workflow:

## 1. Local Codebase Update
- Modify and verify the target worker or server files in the local workspace (`keepsims-backend`).

## 2. GitHub Synchronization
- Stage, commit, and push the updated files to the GitHub repository (`https://github.com/eduanibal1981/keepsims-backend`):
  ```bash
  git add .
  git commit -m "<descriptive message>"
  git push origin main
  ```

## 3. Remote VM Deployment & PM2 Restart
- Connect to the VM instance via SSH:
  ```bash
  ssh -i "C:/Users/abdal/.ssh/google_compute_engine" abdal@34.185.194.90
  ```
- Pull/sync the changes in `/home/abdal/keepsims_backend`:
  ```bash
  cd /home/abdal/keepsims_backend && git pull origin main
  ```
- Restart the updated worker/server process using PM2:
  ```bash
  pm2 restart <worker-or-service-name>
  ```

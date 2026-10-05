# 09 — Protection Console and Simulators

## Alert simulator
### TC-ALM-001: Simulate expiry and critical-balance alerts
- **Preconditions**: Debug build has an isolated test SIM with configured alert thresholds.
- **Expected**: Simulation creates the expected alert event and preview without charging a wallet or contacting a carrier.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Simulator route is debug-only; no live simulator interaction was performed.

## Device alarm preferences
### TC-ALM-002: Set an alarm time and synchronize device scheduling
- **Preconditions**: Notification and exact-alarm permissions are granted or denied explicitly.
- **Expected**: Enabled schedule is registered with the device; disabled state clears it; permission denial is reported accurately.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Alarm controller/widget tests exist but Flutter did not run; physical-device alarm behavior is unverified.

## Alarm sound and vibration preview
### TC-ALM-003: Preview sound and vibration without creating a refill
- **Preconditions**: Device sound and vibration capabilities are available.
- **Expected**: Preview uses selected sound/vibration settings and stops cleanly without creating a server event.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Requires a device for haptics/audio verification.

## Push simulation
### TC-ALM-004: Queue a test push for the current device
- **Preconditions**: The current device has a valid push token and test notifications are enabled.
- **Expected**: One test push reaches the device and navigation data targets the intended screen.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Push delivery contracts passed with provider doubles; no device notification was sent.

# ESIM-06 — installation links, guides and recovery

28 October 2026, Asia/Muscat. Customer implementation is tested locally.
No app binary is published. Native installation and same-device recovery with a
real Apple device/profile remain **UNVERIFIED**: the account has zero owned Access
profiles, and no paid test profile/action was authorized.

## Behavior

Apple setup is an explicit user action on a physical iOS device reporting 17.4
or later. The native channel returns OS version and simulator status on both
standard and implicit Flutter engine startup. The app constructs a fixed HTTPS
`esimsetup.apple.com/esim_qrcode_provisioning` URL using the entire validated LPA
as an encoded `carddata` parameter, then hands it directly to the OS through the
existing URL launcher. It does not use an embedded browser, tracked redirect,
analytics event, provider-supplied install URL, or Android provisioning SDK.
Opening setup never changes installation state or reports installation success.
An unsupported OS, simulator, missing native method or launch failure preserves
the QR/manual fallback.

The shared payload parser rejects malformed prefixes, invalid DNS hosts, schemes,
ports, credentials in the host, paths, control characters and excessive payloads.
Its diagnostic representation is redacted. QR rendering uses the loaded LPA on
the device; the existing remote QR-image URL is ignored. Manual entry exposes
SM-DP+ and matching ID separately, with an explicit full-string copy when needed.
Activation credentials are never passed to logs or analytics by these paths.

Every screen/action checks the signed-in owner, including already-loaded profile
objects. Profile/order providers now watch account changes and filter returned
rows to that owner. A pending refresh from a previous account cannot publish its
credentials into a subsequent session. The existing server owner projection and
RLS remain the authority; no manager entitlement is invented.

The plan activation trigger and known activation deadline appear before install
controls. Guides cover compatibility/unlock checks, platform menu differences,
travel data selection, keeping the primary SIM for calls/SMS, data switching,
conditional roaming and the supplied APN/help facts. Missing APNs/deadlines stay
unknown. Owned profiles remain accessible on a display device that cannot itself
provision an eSIM. Local QR rendering works with an already-loaded owner snapshot;
install/recovery still needs internet. This step adds no persistent credential cache.

Previously downloaded/installed/enabled/disabled profiles lead to connection
help rather than another QR/install prompt. Terminal, deadline-passed, malformed
or unknown states refuse installation and offer refresh/support. A deleted profile
offers recovery only when its observation is within six hours, its profile and
bundle are active, its confirmed expiry is still future, its payload is proven,
and no refresh error is present. The owner must then confirm this is the original
device before any QR/manual/link is revealed. This is an attestation, not a device
identity check or a guarantee of provider approval. Transfer/code sharing is not
offered; recovery never reissues a profile or changes a financial/provider state.

## Runtime and deployment scope

The user approved deploying migrations, Edge functions and scoped VM workers when
needed. **This step needs no change on those surfaces.** The deployed ESIM-03
`customer_esim_profiles` view already exposes the verified activation, installation,
plan, expiry and `last_observation_at` fields required here. It uses an explicit
owner predicate, invoker security and a security barrier, backed by owner SELECT
RLS. Adding another Edge endpoint or worker would duplicate that contract.

Read-only live checks verify owner reads, cross-owner exclusion, anonymous denial,
unverified-payload redaction and required observation fields. No runtime schema,
data, configuration or provider setting was changed. The VM helper/entrypoint
hashes and PID `1060343` remain those of ESIM-05; the outbox Edge remains v8.
New sales stay disabled and the purchase RPC fingerprint is unchanged. Existing
workers report zero cycle errors. No wallet mutation or paid provider action occurred.

## Validation and source

- 103 focused Flutter tests pass across the entire eSIM feature and notification
  navigation, including the new policy, URI, platform, privacy, recovery, layout,
  offline and account-switch scenarios.
- Affected production and test Dart analysis reports no issues. Generated model
  output was regenerated; Swift syntax parsing passes.
- Actual live read-only SQL passes the installation access boundary checks.
- **iOS simulator build passes** for the exact isolated release sources: see [build log](esimaccess-installation-20261028/tests/ios-simulator-build.log).
  The build result is recorded in the final receipt; it is not a real-device
  installation acceptance test.

The isolated build exposed one prior release prerequisite: the ESIM-02 checkout
already called `PlanPayment.availableWalletBalance`, but that helper was absent
from its release branch. This release adds only that existing read helper to the
prior branch's `PlanPayment` file. It uses the established wallet summary contract,
validates `available_balance`, and fails closed on errors/missing/invalid amounts;
no pending wallet/payment implementation was copied. Three focused tests cover
spendable-versus-posted funds and failure behavior. This is a source compilation
prerequisite, not a new wallet or provider action.

Source is synchronized on [`codex/esim06-installation-20261028`](https://github.com/eduanibal1981/keepSIMsgitHub/tree/codex/esim06-installation-20261028), following the ESIM-05
customer release branch. The [manifest](esimaccess-installation-20261028/release/manifest.json)
records the exact customer source hashes. Rebuild it with
`python3 tools/prepare_esim_installation_release.py`. App binaries remain unpublished;
default branches and unrelated working-tree edits are preserved.

## Provider/device contract

Apple documents carrier-link setup on iOS 17.4 or later; compatibility and carrier
support still apply. [Apple setup guide](https://support.apple.com/en-us/118669).
The supplier documents the Apple Universal Link route and QR/manual alternatives.
[Access link format](https://esimaccess.com/new-apple-universal-link-for-esim-install/),
[activation methods](https://esimaccess.com/docs/what-are-the-available-esim-activation-methods/).
Its reinstall guidance allows reuse of the original code on the original device
and forbids using it on another device. The app offers a conditional attempt and
support fallback, without inventing a reinstall-count guarantee.
[Reinstall guidance](https://esimaccess.com/docs/can-users-reinstall-a-deleted-esim/).

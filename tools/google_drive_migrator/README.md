# Verified Google Drive account migration

This tool migrates files owned by one personal Gmail account to another. It is a
dry run by default and keeps an append-only progress journal, so an interrupted
run can resume without starting over.

## Choose a mode

### Ownership mode (recommended)

Transfers each existing Drive item to Account B. It preserves the file ID,
sharing link, Google-native format, comments, and revision history. After every
requested item has transferred and Account B is verified as its owner, Account B
removes Account A's permission. If any transfer fails, Account A's access is kept
so the migration can safely resume.

Google Drive shortcuts and Google Sites are reported for manual handling.

### Staged mode

Downloads one file at a time into an operating-system temporary directory,
uploads it to Account B, downloads/exports the destination again, and verifies
the result. The local copies are then removed and checked as absent. Only after
that is the source moved to Trash (the default) or permanently deleted. The
temporary directory is removed after every attempt.

Binary files use exact SHA-256 verification. Docs, Sheets, and Slides are
exported to their Microsoft Office equivalents, imported back into Google format,
then compared using a content-and-media fingerprint. Because that round trip can
change unsupported formatting or features, ownership mode is preferable for
Google-native files. Forms, Sites, Drawings, Apps Script projects, and shortcuts
are not locally round-tripped; they are reported and left in Account A.

## One-time Google setup

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project, then enable **Google Drive API**.
3. Configure the OAuth consent screen for external use and add both Gmail
   addresses as test users if the app remains in testing.
4. Create an **OAuth client ID** of type **Desktop app**.
5. Download the JSON as `credentials.json` into this directory.

The credentials and account tokens are ignored by Git. Keep them private. You
can revoke access later from each Google Account's connected-app settings.

## Install

From this directory, create an isolated Python environment and install:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Preview first

The first run opens a browser twice. Carefully choose Account A first and
Account B second.

```powershell
python migrate_drive.py `
  --source-email old.account@gmail.com `
  --destination-email new.account@gmail.com `
  --mode ownership
```

This writes `.state/inventory.json` and changes nothing in Drive. Review that
inventory before executing.

## Execute ownership transfer

Test the workflow with throwaway accounts before using it for a valuable Drive.
The current tool inventories all items owned by Account A.

```powershell
python migrate_drive.py `
  --source-email old.account@gmail.com `
  --destination-email new.account@gmail.com `
  --mode ownership `
  --execute
```

Use `--keep-source-access` if Account A should remain an editor.

## Execute staged copy with recoverable cleanup

```powershell
python migrate_drive.py `
  --source-email old.account@gmail.com `
  --destination-email new.account@gmail.com `
  --mode staged `
  --source-cleanup trash `
  --execute
```

The tool creates a dated migration folder in Account B. To use an existing
folder, supply `--destination-folder-id FOLDER_ID`.

Add `--flat` to put every file directly inside that one migration folder instead
of recreating Account A's source folder hierarchy. Duplicate filenames are
allowed by Google Drive and remain separate files.

Permanent source deletion requires both flags:

```powershell
--source-cleanup delete --confirm-permanent-delete DELETE-SOURCE-PERMANENTLY
```

Moving sources to Trash is strongly preferred until you inspect the destination.
Google normally retains trashed items for a recovery period.

## Reports and restart behavior

The `.state` directory contains:

- `inventory.json`: every non-trashed Drive item owned by Account A.
- `migration.json`: binds this state directory to the selected account pair and
  migration mode. Use a different `--state-dir` if you change modes.
- `progress-ownership.jsonl` or `progress-staged.jsonl`: each attempted step,
  destination ID, verification evidence, and error.
- `token_source.json` and `token_destination.json`: private OAuth tokens.

Run the same command again to continue after quota throttling or an interruption.
Items successfully cleaned up are skipped. A destination copy that fails
verification is retained for inspection, while its source remains untouched.
The inventory is retained and merged across runs because successfully transferred
items no longer appear in Account A's current owned-file listing.

For ownership mode, do not manually share a parent migration folder with Account
B first. The tool grants direct access from the deepest items upward, avoiding a
Google API limitation around pending ownership and inherited permissions. If the
accounts already share part of the tree, any affected item is reported instead
of being removed from Account A without verification.

Items merely shared with Account A are outside this migration because Account A
does not own them. The staged mode keeps source folders that still contain such
items instead of deleting a folder that may organize someone else's files.

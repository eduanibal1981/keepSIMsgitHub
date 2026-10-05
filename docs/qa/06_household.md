# 06 — Household and Shared Lines

## Household overview
### TC-HOU-001: Show owner, members, and invite states
- **Preconditions**: The signed-in account owns a household with invited and accepted members.
- **Expected**: Member identity, role, and invitation state match saved data; an empty household state is actionable.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Both /household and /settings/household route to the same screen; one catalog entry covers both.

## Invite member
### TC-HOU-002: Create an email, QR, or link invitation
- **Preconditions**: Owner has a valid invite destination and household capacity remains.
- **Expected**: Invitation is created once with the requested role and a usable invite token; duplicate submission is prevented.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Household widget tests exist but Flutter did not run.

## Role assignment
### TC-HOU-003: Restrict member role changes to the household owner
- **Preconditions**: A viewer and manager account share a household.
- **Expected**: Members cannot self-promote; only authorized owners can change roles, with database authorization enforced.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: The H8 SQL suite was rejected by approval review: its fixture deletes memberships for the first real profile and mutates real invitation state. It was not retried or bypassed.

## Shared wallet allowance
### TC-HOU-004: Set and enforce a member spending allowance
- **Preconditions**: Household owner has a wallet and a member with an assigned allowance.
- **Expected**: Allowance changes persist; member spending over the limit is refused and owner balances remain protected.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Household spend tests exist but Flutter did not run; database suite was not safely executable with its current fixture.

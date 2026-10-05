# 12 — Help and Support

## Support ticket list
### TC-SUP-001: Load open, closed, and empty ticket lists
- **Preconditions**: The account has tickets in multiple statuses or no tickets.
- **Expected**: Tickets are scoped to the user and status; empty/error states offer a safe retry.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Support list screen and controller inspected; no authenticated UI test ran.

## Create support ticket
### TC-SUP-002: Submit a ticket with a valid category and description
- **Preconditions**: User is signed in and enters a supported category with non-empty details.
- **Expected**: One ticket is created and the list refreshes; invalid submissions show validation without creating a row.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Create-ticket screen and controller were not runtime-tested.

## Attachment picker
### TC-SUP-003: Attach an allowed file and handle cancellation
- **Preconditions**: Device file picker permission is available and a valid attachment exists.
- **Expected**: Selected file metadata is shown and uploaded once; canceled or unsupported files do not submit a ticket.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Device file-picker path was not exercised.

## Ticket detail and messaging
### TC-SUP-004: Read, send, and close a ticket conversation
- **Preconditions**: A ticket belongs to the current account and is open.
- **Expected**: Messages appear in order; only the owner can reply or close; closed state is reflected in the list.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Ticket details and controller were inspected; no live ticket was modified.

## FAQ
### TC-SUP-005: Search and expand FAQ answers
- **Preconditions**: FAQ list contains multiple searchable entries.
- **Expected**: Search narrows by question/answer and accordion state toggles the selected answer.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: FAQ screen has search and expandable items; no widget test completed.

## Feedback submission
### TC-SUP-006: Submit feedback and show success or retryable error
- **Preconditions**: User enters valid feedback and network state is online or offline.
- **Expected**: Successful feedback is acknowledged once; failures retain the draft and do not create duplicates.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Feedback UI/controller was not runtime-tested.

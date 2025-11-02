# Google Calendar Integration

This demonstrates how the ICalendar library now automatically appends `X-INCLUDE-DTSTART=TRUE` to the rrule_str when Google Calendar is detected via PRODID.

## Example Usage

```elixir
# Create an event with Google Calendar PRODID
event = %ICalendar.Event{
  prodid: "-//Google Inc//Google Calendar 70.9054//EN",
  rrule_str: "RRULE:FREQ=DAILY;COUNT=3\nDTSTART:20251114T070000Z",
  dtstart: ~U[2025-11-14 07:00:00Z],
  dtend: ~U[2025-11-14 08:00:00Z],
  summary: "Daily Meeting"
}

# Get recurrences
recurrences = ICalendar.Recurrence.get_recurrences(
  event,
  ~U[2025-11-14 07:00:00Z],
  ~U[2025-11-20 07:00:00Z]
)

# The library automatically adds X-INCLUDE-DTSTART=TRUE for Google Calendar
# Result: 4 recurrences (original DTSTART + 3 from COUNT=3)
# - 2025-11-14 07:00:00Z (original DTSTART)
# - 2025-11-15 07:00:00Z
# - 2025-11-16 07:00:00Z  
# - 2025-11-17 07:00:00Z
```

## What is X-INCLUDE-DTSTART=TRUE?

When `X-INCLUDE-DTSTART=TRUE` is present in an RRULE, it tells the recurrence engine to include the original DTSTART time as an additional occurrence. This is particularly important for Google Calendar events that use BYHOUR, BYMINUTE, or other BY* rules where the original start time might not match the BY* pattern.

## BYHOUR Example

This is especially useful with BYHOUR rules:

```elixir
event = %ICalendar.Event{
  prodid: "-//Google Inc//Google Calendar 70.9054//EN",
  rrule_str: "RRULE:FREQ=WEEKLY;BYHOUR=9,17\nDTSTART:20251014T070000Z",
  dtstart: ~U[2025-10-14 07:00:00Z],
  dtend: ~U[2025-10-14 08:00:00Z],
  summary: "Weekly Check-ins"
}

recurrences = ICalendar.Recurrence.get_recurrences(
  event,
  ~U[2025-10-14 07:00:00Z],
  ~U[2025-10-21 07:00:00Z]
)

# Without X-INCLUDE-DTSTART=TRUE: Only 9:00 and 17:00 occurrences
# With X-INCLUDE-DTSTART=TRUE: Also includes the original 7:00 occurrence
# Result includes:
# - 2025-10-14 07:00:00Z (original DTSTART)
# - 2025-10-14 09:00:00Z (from BYHOUR=9)
# - 2025-10-14 17:00:00Z (from BYHOUR=17)
# - 2025-10-21 09:00:00Z (next week)
# - 2025-10-21 17:00:00Z (next week)
```

## Auto-Detection from Calendar PRODID

The library automatically detects Google Calendar events from the calendar-level PRODID field:

```elixir
ics = """
BEGIN:VCALENDAR
PRODID:-//Google Inc//Google Calendar 70.9054//EN
VERSION:2.0
CALSCALE:GREGORIAN
BEGIN:VEVENT
RRULE:FREQ=WEEKLY;BYHOUR=9,17
SUMMARY:Weekly Meeting
DTSTART:20251014T070000Z
DTEND:20251014T080000Z
END:VEVENT
END:VCALENDAR
"""

[event] = ICalendar.from_ics(ics)
# event.prodid will be automatically set to "-//Google Inc//Google Calendar 70.9054//EN"
# X-INCLUDE-DTSTART=TRUE will be automatically appended to the RRULE during recurrence processing
```

## Other Calendar Providers

Events from non-Google calendars will not have `X-INCLUDE-DTSTART=TRUE` automatically added:

```elixir
event = %ICalendar.Event{
  prodid: "-//Microsoft Corporation//Outlook 16.0 MIMEDIR//EN",
  rrule_str: "RRULE:FREQ=DAILY;COUNT=3\nDTSTART:20251114T070000Z",
  dtstart: ~U[2025-11-14 07:00:00Z],
  summary: "Daily Meeting"
}

# X-INCLUDE-DTSTART=TRUE will NOT be added automatically
```

## Avoiding Duplication

If `X-INCLUDE-DTSTART=TRUE` is already present in the RRULE, the library will not duplicate it:

```elixir
event = %ICalendar.Event{
  prodid: "-//Google Inc//Google Calendar 70.9054//EN",
  rrule_str: "RRULE:FREQ=DAILY;COUNT=3;X-INCLUDE-DTSTART=TRUE\nDTSTART:20251114T070000Z",
  # X-INCLUDE-DTSTART=TRUE is already present, won't be duplicated
}
```

## Implementation Notes

- Google Calendar detection is based on the PRODID field from the calendar level
- PRODID is extracted during calendar parsing and assigned to individual events
- The `X-INCLUDE-DTSTART=TRUE` parameter is appended to RRULE lines during recurrence processing
- Detection looks for both "GOOGLE" and "CALENDAR" in the PRODID (case-insensitive)
- This functionality is specific to Google Calendar's behavior and expectations

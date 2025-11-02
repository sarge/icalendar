defmodule ICalendar.ProviderTest do
  use ExUnit.Case

  alias ICalendar.Event

  describe "PRODID-based Google Calendar functionality" do
    test "Google Calendar PRODID adds X-INCLUDE-DTSTART=TRUE to RRULE" do
      # Create an event with Google Calendar PRODID
      event = %Event{
        prodid: "-//Google Inc//Google Calendar 70.9054//EN",
        rrule_str: "RRULE:FREQ=DAILY;COUNT=3\nDTSTART:20251114T070000Z",
        dtstart: ~U[2025-11-14 07:00:00Z],
        dtend: ~U[2025-11-14 08:00:00Z],
        summary: "Test Event"
      }

      # Get recurrences - should automatically add X-INCLUDE-DTSTART=TRUE
      recurrences = ICalendar.Recurrence.get_recurrences(
        event,
        ~U[2025-11-14 07:00:00Z],
        ~U[2025-11-20 07:00:00Z]
      )

      # Should get 4 recurrences: original DTSTART + 3 more as specified by COUNT=3
      # This happens because X-INCLUDE-DTSTART=TRUE includes the original DTSTART
      assert length(recurrences) == 4
      assert Enum.at(recurrences, 0).dtstart == ~U[2025-11-14 07:00:00Z]
      assert Enum.at(recurrences, 1).dtstart == ~U[2025-11-15 07:00:00Z]
      assert Enum.at(recurrences, 2).dtstart == ~U[2025-11-16 07:00:00Z]
      assert Enum.at(recurrences, 3).dtstart == ~U[2025-11-17 07:00:00Z]
    end

    test "Non-Google PRODID does not add X-INCLUDE-DTSTART=TRUE to RRULE" do
      # Create an event with different (non-Google) PRODID
      event = %Event{
        prodid: "-//Microsoft Corporation//Outlook 16.0 MIMEDIR//EN",
        rrule_str: "RRULE:FREQ=DAILY;COUNT=3\nDTSTART:20251114T070000Z",
        dtstart: ~U[2025-11-14 07:00:00Z],
        dtend: ~U[2025-11-14 08:00:00Z],
        summary: "Test Event"
      }

      # Get recurrences - should NOT add X-INCLUDE-DTSTART=TRUE
      recurrences = ICalendar.Recurrence.get_recurrences(
        event,
        ~U[2025-11-14 07:00:00Z],
        ~U[2025-11-20 07:00:00Z]
      )

      # Should get 3 recurrences as specified by COUNT=3
      assert length(recurrences) == 3
    end

    test "PRODID is extracted from calendar level" do
      ics = """
      BEGIN:VCALENDAR
      PRODID:-//Google Inc//Google Calendar 70.9054//EN
      VERSION:2.0
      CALSCALE:GREGORIAN
      BEGIN:VEVENT
      SUMMARY:Test Event
      DTSTART:20251114T070000Z
      DTEND:20251114T080000Z
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      assert event.prodid == "-//Google Inc//Google Calendar 70.9054//EN"
    end

    test "Google Calendar does not duplicate X-INCLUDE-DTSTART if already present" do
      # Create an event with Google Calendar PRODID and X-INCLUDE-DTSTART already in the rrule
      event = %Event{
        prodid: "-//Google Inc//Google Calendar 70.9054//EN",
        rrule_str: "RRULE:FREQ=DAILY;COUNT=3;X-INCLUDE-DTSTART=TRUE\nDTSTART:20251114T070000Z",
        dtstart: ~U[2025-11-14 07:00:00Z],
        dtend: ~U[2025-11-14 08:00:00Z],
        summary: "Test Event"
      }

      # Get recurrences - should not duplicate X-INCLUDE-DTSTART=TRUE
      recurrences = ICalendar.Recurrence.get_recurrences(
        event,
        ~U[2025-11-14 07:00:00Z],
        ~U[2025-11-20 07:00:00Z]
      )

      # Should still get 4 recurrences (original + 3 from COUNT=3)
      assert length(recurrences) == 4
    end

    test "Google Calendar with BYHOUR demonstrates X-INCLUDE-DTSTART behavior" do
      # Create an event with Google Calendar PRODID and BYHOUR (similar to weekly test)
      event = %Event{
        prodid: "-//Google Inc//Google Calendar 70.9054//EN",
        rrule_str: "RRULE:FREQ=WEEKLY;BYHOUR=9,17\nDTSTART:20251014T070000Z",
        dtstart: ~U[2025-10-14 07:00:00Z],
        dtend: ~U[2025-10-14 08:00:00Z],
        summary: "Test Event"
      }

      # Get first 5 recurrences
      recurrences = ICalendar.Recurrence.get_recurrences(
        event,
        ~U[2025-10-14 07:00:00Z],
        ~U[2025-10-30 07:00:00Z]
      )

      # Should include the original DTSTART at 07:00 plus the BYHOUR times
      # First occurrence should include the original 07:00 time, then 09:00 and 17:00
      recurrence_times = Enum.map(recurrences, & &1.dtstart)

      # Should have the original DTSTART time (07:00) plus the BYHOUR times (09:00, 17:00)
      assert ~U[2025-10-14 07:00:00Z] in recurrence_times
      assert ~U[2025-10-14 09:00:00Z] in recurrence_times
      assert ~U[2025-10-14 17:00:00Z] in recurrence_times
    end
  end
end

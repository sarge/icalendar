defmodule ICalendar.RecurrenceTest do
  use ExUnit.Case

  test "daily reccuring event with until" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;UNTIL=20151231T083000Z
      DESCRIPTION:Let's go see Star Wars.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      SUMMARY:Film with Amy and Adam
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 8

    [event | events] = events
    assert event.dtstart == ~U[2015-12-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-25 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-26 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-27 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-28 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-29 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-30 08:30:00Z]
    [event] = events
    assert event.dtstart == ~U[2015-12-31 08:30:00Z]
  end

  test "daily reccuring event with count" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=3
      DESCRIPTION:Let's go see Star Wars.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      SUMMARY:Film with Amy and Adam
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 3

    [event | events] = events
    assert event.dtstart == ~U[2015-12-24 08:30:00Z]
    [event | _events] = events
    assert event.dtstart == ~U[2015-12-25 08:30:00Z]
  end

  test "monthly reccuring event with until" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=MONTHLY;UNTIL=20160624T083000Z
      DESCRIPTION:Let's go see Star Wars.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      SUMMARY:Film with Amy and Adam
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 7

    [event | events] = events
    assert event.dtstart == ~U[2015-12-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-01-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-02-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-03-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-04-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-05-24 08:30:00Z]
    [event] = events
    assert event.dtstart == ~U[2016-06-24 08:30:00Z]
  end

  test "weekly reccuring event with until" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=WEEKLY;UNTIL=20160201T083000Z
      DESCRIPTION:Let's go see Star Wars.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      SUMMARY:Film with Amy and Adam
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 6

    [event | events] = events
    assert event.dtstart == ~U[2015-12-24 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2015-12-31 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-01-07 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-01-14 08:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2016-01-21 08:30:00Z]
    [event] = events
    assert event.dtstart == ~U[2016-01-28 08:30:00Z]
  end

  test "exdates not included in reccuring event with until and byday, ignoring invalid byday value" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      DTSTART:20200903T143000Z
      DTEND:20200903T153000Z
      RRULE:FREQ=WEEKLY;WKST=SU;UNTIL=20201028T045959Z;INTERVAL=2;BYDAY=TH,WE,AD
      EXDATE:20200917T143000Z
      EXDATE:20200916T143000Z
      SUMMARY:work!
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 5

    [event | events] = events
    assert event.dtstart == ~U[2020-09-03 14:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2020-10-01 14:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2020-09-30 14:30:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2020-10-15 14:30:00Z]
    [event] = events
    assert event.dtstart == ~U[2020-10-14 14:30:00Z]
  end

  test "daily recurring event with date-only values" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=4
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:Daily all-day event
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 4

    [event | events] = events
    assert event.dtstart == ~U[2025-11-14 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2025-11-15 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2025-11-16 00:00:00Z]
    [event] = events
    assert event.dtstart == ~U[2025-11-17 00:00:00Z]
  end

  test "weekly recurring event with date-only values and X-WR-TIMEZONE" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      RRULE:FREQ=WEEKLY;COUNT=3
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:Weekly all-day event with timezone
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 3

    [event | events] = events
    # November 2025: Pacific/Auckland is UTC+13 (daylight saving time)
    # Midnight in Auckland = 11:00 UTC previous day
    assert event.dtstart == ~U[2025-11-13 11:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2025-11-20 11:00:00Z]
    [event] = events
    assert event.dtstart == ~U[2025-11-27 11:00:00Z]
  end

  test "monthly recurring event with date-only values and UNTIL" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=MONTHLY;UNTIL=20260314
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:Monthly all-day event with date until
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 5

    [event | events] = events
    assert event.dtstart == ~U[2025-11-14 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2025-12-14 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2026-01-14 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2026-02-14 00:00:00Z]
    [event] = events
    assert event.dtstart == ~U[2026-03-14 00:00:00Z]
  end

  test "recurring event with date-only values and EXDATE" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=5
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      EXDATE;VALUE=DATE:20251116
      EXDATE;VALUE=DATE:20251117
      SUMMARY:Daily all-day event with exception dates
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    # Should have 3 events (5 count minus 2 excluded dates)
    assert events |> Enum.count() == 3

    [event | events] = events
    assert event.dtstart == ~U[2025-11-14 00:00:00Z]
    [event | events] = events
    assert event.dtstart == ~U[2025-11-15 00:00:00Z]
    # 2025-11-16 and 2025-11-17 are excluded
    [event] = events
    assert event.dtstart == ~U[2025-11-18 00:00:00Z]
  end

  test "weekly recurring event with date-only values and BYDAY" do
    events =
      """
      BEGIN:VCALENDAR
      PRODID:-//Google Inc//Google Calendar 70.9054//EN
      VERSION:2.0
      CALSCALE:GREGORIAN
      X-WR-CALNAME:Liberation
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      RRULE:FREQ=WEEKLY;WKST=SU;INTERVAL=2;BYDAY=FR
      DTSTAMP:20251002T041046Z
      UID:55v24sq3ih6oto8ib9bu4a7352@google.com
      CREATED:20251002T041045Z
      DESCRIPTION:
      LAST-MODIFIED:20251002T041046Z
      LOCATION:
      SEQUENCE:0
      STATUS:CONFIRMED
      SUMMARY:Fridays off
      TRANSP:TRANSPARENT
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        # Provide explicit end date to ensure recurrences are generated
        end_date = ~U[2027-01-01 00:00:00Z]

        recurrences =
          ICalendar.Recurrence.get_recurrences(event, end_date)
          # Take first 4 recurrences
          |> Enum.take(4)

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 5

    # All events represent "Friday midnight Auckland" converted to "Thursday 11:00 UTC"
    # The RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=FR generates recurrences every 2 weeks on Friday (Auckland time)
    # All times maintain consistent timezone conversion: Fri 00:00 Auckland → Thu 11:00 UTC
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (original)
    assert event.dtstart == ~U[2025-11-13 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+2 weeks)
    assert event.dtstart == ~U[2025-11-27 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+2 weeks)
    assert event.dtstart == ~U[2025-12-11 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+2 weeks)
    assert event.dtstart == ~U[2025-12-25 11:00:00Z]
    [event] = events
    # Thu UTC = Fri 00:00 Auckland (+2 weeks)
    assert event.dtstart == ~U[2026-01-08 11:00:00Z]
  end

  test "weekly recurring event with date-only values and BYDAY omit INTERVAL and COUNT" do
    events =
      """
      BEGIN:VCALENDAR
      PRODID:-//Google Inc//Google Calendar 70.9054//EN
      VERSION:2.0
      CALSCALE:GREGORIAN
      X-WR-CALNAME:Liberation
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      RRULE:FREQ=WEEKLY;WKST=SU;BYDAY=FR
      DTSTAMP:20251002T041046Z
      UID:55v24sq3ih6oto8ib9bu4a7352@google.com
      CREATED:20251002T041045Z
      DESCRIPTION:
      LAST-MODIFIED:20251002T041046Z
      LOCATION:
      SEQUENCE:0
      STATUS:CONFIRMED
      SUMMARY:Fridays off
      TRANSP:TRANSPARENT
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        # Provide explicit end date to ensure recurrences are generated
        end_date = ~U[2027-01-01 00:00:00Z]

        recurrences =
          ICalendar.Recurrence.get_recurrences(event, end_date)
          # Take first 4 recurrences
          |> Enum.take(4)

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 5

    # All events represent "Friday midnight Auckland" converted to "Thursday 11:00 UTC"
    # The RRULE:FREQ=WEEKLY;BYDAY=FR generates recurrences every week on Friday (Auckland time)
    # All times maintain consistent timezone conversion: Fri 00:00 Auckland → Thu 11:00 UTC
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (original)
    assert event.dtstart == ~U[2025-11-13 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+1 week)
    assert event.dtstart == ~U[2025-11-20 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+1 week)
    assert event.dtstart == ~U[2025-11-27 11:00:00Z]
    [event | events] = events
    # Thu UTC = Fri 00:00 Auckland (+1 week)
    assert event.dtstart == ~U[2025-12-04 11:00:00Z]
    [event] = events
    # Thu UTC = Fri 00:00 Auckland (+1 week)
    assert event.dtstart == ~U[2025-12-11 11:00:00Z]
  end

  test "yearly recurring event with bymonth and until" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=YEARLY;BYMONTH=4,9;UNTIL=20250101T000000Z
      DESCRIPTION:Quarterly meeting
      DTEND:20240415T100000Z
      DTSTART:20240415T090000Z
      SUMMARY:Quarterly Review
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    # With BYMONTH=4,9 and UNTIL=20250101, we should get events in April and September 2024
    assert events |> Enum.count() == 2

    # Original/First event in April 2024
    [event | events] = events
    assert event.dtstart == ~U[2024-04-15 09:00:00Z]

    # Second event in September 2024
    [event] = events
    assert event.dtstart == ~U[2024-09-15 09:00:00Z]
  end

  test "yearly recurring event with bymonth and count" do
    events =
      """
      BEGIN:VCALENDAR
      CALSCALE:GREGORIAN
      VERSION:2.0
      BEGIN:VEVENT
      RRULE:FREQ=YEARLY;BYMONTH=6;COUNT=3
      DESCRIPTION:Annual summer event
      DTEND:20240615T160000Z
      DTSTART:20240615T150000Z
      SUMMARY:Summer Festival
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event)
          |> Enum.to_list()

        [event | recurrences]
      end)
      |> List.flatten()

    # With COUNT=3, we should get the original event plus 2 yearly recurrences
    assert events |> Enum.count() == 3

    # Original event in June 2024
    [event | events] = events
    assert event.dtstart == ~U[2024-06-15 15:00:00Z]

    # First recurrence in June 2025
    [event | events] = events
    assert event.dtstart == ~U[2025-06-15 15:00:00Z]

    # Second recurrence in June 2026
    [event] = events
    assert event.dtstart == ~U[2026-06-15 15:00:00Z]
  end

  test "monthly recurring event with byday until and count omitted" do
    events =
      """
      BEGIN:VCALENDAR
      VERSION:2.0
      CALSCALE:GREGORIAN
      X-WR-TIMEZONE:UTC
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251003
      DTEND;VALUE=DATE:20251004
      RRULE:FREQ=MONTHLY;BYDAY=3TH
      DTSTAMP:20250920T053811Z
      LAST-MODIFIED:20250920T053811Z
      SEQUENCE:0
      STATUS:CONFIRMED
      SUMMARY:Monthly on the 3rd Thursday
      TRANSP:TRANSPARENT
      END:VEVENT
      END:VCALENDAR
      """
      |> ICalendar.from_ics()
      |> Enum.map(fn event ->
        recurrences =
          ICalendar.Recurrence.get_recurrences(event, ~U[2025-12-31 23:59:59Z])
          # Take only first 3 recurrences
          |> Enum.take(3)

        [event | recurrences]
      end)
      |> List.flatten()

    assert events |> Enum.count() == 4

    # First event - original (Oct 3, 2025)
    [event | events] = events
    assert event.dtstart == ~U[2025-10-03 00:00:00Z]

    # Second event - 3rd Thursday of Oct 2025
    [event | events] = events
    assert event.dtstart == ~U[2025-10-16 00:00:00Z]

    # Third event - 3rd Thursday of Nov 2025
    [event | events] = events
    assert event.dtstart == ~U[2025-11-20 00:00:00Z]

    # Fourth event - 3rd Thursday of Dec 2025
    [event] = events
    assert event.dtstart == ~U[2025-12-18 00:00:00Z]
  end
end

defmodule ICalendar.RecurrenceFloatingDateTimeTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(
        %NaiveDateTime{} = dtstart,
        %DateTime{} = start_date,
        %DateTime{} = end_date,
        rrule,
        timezone \\ nil
      ) do
    start = ICalendar.Value.to_ics(dtstart)

    """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    BEGIN:VEVENT
    RRULE:#{rrule}
    DTEND:#{start}
    DTSTART:#{start}
    SUMMARY:Test Event
    END:VEVENT
    END:VCALENDAR
    """
    |> ICalendar.from_ics()
    |> Enum.flat_map(fn event ->
      ICalendar.Recurrence.get_recurrences(event, start_date, end_date, timezone)
      |> Enum.take(5)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=DAILY - Basic" do
    test "FREQ=DAILY" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY"
        )

      assert results == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-18 14:30:00Z],
               ~U[2025-10-19 14:30:00Z],
               ~U[2025-10-20 14:30:00Z],
               ~U[2025-10-21 14:30:00Z]
             ]
    end

    test "FREQ=DAILY;COUNT=5" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;COUNT=5"
        )

      assert results == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-18 14:30:00Z],
               ~U[2025-10-19 14:30:00Z],
               ~U[2025-10-20 14:30:00Z],
               ~U[2025-10-21 14:30:00Z]
             ]
    end

    test "FREQ=DAILY;UNTIL=20251231T143000" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;UNTIL=20251231T143000"
        )

      assert results == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-18 14:30:00Z],
               ~U[2025-10-19 14:30:00Z],
               ~U[2025-10-20 14:30:00Z],
               ~U[2025-10-21 14:30:00Z]
             ]
    end
  end

  describe "FREQ=DAILY - With Interval" do
    test "FREQ=DAILY;INTERVAL=2" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2"
        )

      assert results == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-19 14:30:00Z],
               ~U[2025-10-21 14:30:00Z],
               ~U[2025-10-23 14:30:00Z],
               ~U[2025-10-25 14:30:00Z]
             ]
    end

    test "FREQ=DAILY;INTERVAL=2;COUNT=10" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2;COUNT=10"
        )

      assert Enum.take(results, 5) == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-19 14:30:00Z],
               ~U[2025-10-21 14:30:00Z],
               ~U[2025-10-23 14:30:00Z],
               ~U[2025-10-25 14:30:00Z]
             ]
    end

    test "FREQ=DAILY;INTERVAL=3;UNTIL=20251031T143000" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=3;UNTIL=20251031T143000"
        )

      assert results == [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-20 14:30:00Z],
               ~U[2025-10-23 14:30:00Z],
               ~U[2025-10-26 14:30:00Z],
               ~U[2025-10-29 14:30:00Z]
             ]
    end
  end

  describe "FREQ=DAILY - Edge cases" do
    test "FREQ=DAILY;COUNT=1" do
      results =
        create_ical_event(
          ~N[2025-10-17 14:30:00],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;COUNT=1"
        )

      assert results == [~U[2025-10-17 14:30:00Z]]
    end
  end
end

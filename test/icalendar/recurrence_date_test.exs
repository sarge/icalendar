defmodule ICalendar.RecurrenceDateTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(
        %Date{} = dtstart,
        %DateTime{} = start_date,
        %DateTime{} = end_date,
        rrule,
        timezone \\ nil
      ) do
    start = ICalendar.Value.to_ics(dtstart)

    # if the rrule does not contain LOCAL-TZID=UTC then we need to add it
    rrule =
      if String.contains?(rrule, "LOCAL-TZID") do
        rrule
      else
        rrule <> ";LOCAL-TZID=" <> (timezone || "UTC")
      end

    """
    BEGIN:VCALENDAR
    CALSCALE:GREGORIAN
    VERSION:2.0
    BEGIN:VEVENT
    RRULE:#{rrule}
    DTEND;VALUE=DATE:#{start}
    DTSTART;VALUE=DATE:#{start}
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

  def create_ical_event_tzid(
        %Date{} = dtstart,
        tzid,
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
    DTEND;VALUE=DATE;TZID=#{tzid}:#{start}
    DTSTART;VALUE=DATE;TZID=#{tzid}:#{start}
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

  @tag :skip
  describe "FREQ=DAILY - Basic" do
    test "FREQ=DAILY" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY"
        )

      # Note: uses the current system timezone for the time
      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ]
    end

    @tag :skip
    test "FREQ=DAILY tzid" do
      results =
        create_ical_event_tzid(
          ~D[2025-10-17],
          "Pacific/Auckland",
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY"
        )

      assert results == [
               ~U[2025-10-17 11:00:00Z],
               ~U[2025-10-18 11:00:00Z],
               ~U[2025-10-19 11:00:00Z],
               ~U[2025-10-20 11:00:00Z],
               ~U[2025-10-21 11:00:00Z]
             ]
    end

    @tag :skip
    test "FREQ=DAILY in Pacific/Auckland" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY",
          "Pacific/Auckland"
        )

      assert results == [
               DateTime.from_naive!(~N[2025-10-17 13:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-18 13:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-19 13:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-20 13:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-21 13:00:00], "Pacific/Auckland")
             ]
    end

    test "FREQ=DAILY;COUNT=5" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;COUNT=5"
        )

      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ]
    end

    test "FREQ=DAILY;UNTIL=20251231" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;UNTIL=20251231"
        )

      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ]
    end
  end

  describe "FREQ=DAILY - With Interval" do
    test "FREQ=DAILY;INTERVAL=2" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2"
        )

      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-21 00:00:00Z],
               ~U[2025-10-23 00:00:00Z],
               ~U[2025-10-25 00:00:00Z]
             ]
    end

    test "FREQ=DAILY;INTERVAL=2;COUNT=10" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2;COUNT=10"
        )

      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-21 00:00:00Z],
               ~U[2025-10-23 00:00:00Z],
               ~U[2025-10-25 00:00:00Z]
             ]
    end
  end

  describe "FREQ=DAILY - Edge cases" do
    test "FREQ=DAILY;COUNT=1" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          ~U[2025-10-17 00:00:00Z],
          ~U[2025-11-17 00:00:00Z],
          "FREQ=DAILY;COUNT=1"
        )

      assert [~U[2025-10-17 00:00:00Z]] = results
    end
  end
end

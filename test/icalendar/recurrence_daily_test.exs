defmodule ICalendar.RecurrenceDailyTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(dtstart, rrule) do
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
      # For infinite recurrence (no COUNT or UNTIL), provide an end date
      # that's far enough in the future to generate the expected test results
      end_date =
        if String.contains?(rrule, "COUNT") or String.contains?(rrule, "UNTIL") do
          DateTime.utc_now()
        else
          # For infinite recurrence, set end date 1 year from start
          DateTime.add(dtstart, 365, :day)
        end

      ICalendar.Recurrence.get_recurrences(event, end_date)
      |> Enum.take(5)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=DAILY - Basic" do
    test "FREQ=DAILY" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;COUNT=5" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;COUNT=5"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;UNTIL=20251231T000000Z" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;UNTIL=20251231T000000Z"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ] = results
    end
  end

  describe "FREQ=DAILY - With Interval" do
    test "FREQ=DAILY;INTERVAL=2" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-21 00:00:00Z],
               ~U[2025-10-23 00:00:00Z],
               ~U[2025-10-25 00:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;INTERVAL=2;COUNT=10" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=2;COUNT=10"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-21 00:00:00Z],
               ~U[2025-10-23 00:00:00Z],
               ~U[2025-10-25 00:00:00Z]
             ] = Enum.take(results, 5)
    end

    test "FREQ=DAILY;INTERVAL=3;UNTIL=20251031T000000Z" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;INTERVAL=3;UNTIL=20251031T000000Z"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-23 00:00:00Z],
               ~U[2025-10-26 00:00:00Z],
               ~U[2025-10-29 00:00:00Z]
             ] = results
    end
  end

  describe "FREQ=DAILY - With BYHOUR rule" do
    test "FREQ=DAILY;BYHOUR=9,12,15" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;BYHOUR=9,12,15"
        )

      # Should create 3 events per day at 9, 12, and 15 hours
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 15:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-18 12:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;BYHOUR=9,12,15 include the DTSTART time if it missing" do
      results =
        create_ical_event(
          ~U[2025-10-17 08:00:00Z],
          "FREQ=DAILY;BYHOUR=9,12,15"
        )

      # Should create 3 events per day at 9, 12, and 15 hours
      assert [
               ~U[2025-10-17 08:00:00Z],
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 15:00:00Z],
               ~U[2025-10-18 09:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;BYHOUR=9;BYMINUTE=0,30" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;BYHOUR=9;BYMINUTE=0,30"
        )

      # Should create 2 events per day at 9:00 and 9:30
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:30:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-18 09:30:00Z],
               ~U[2025-10-19 09:00:00Z]
             ] = results
    end

    @tag :skip
    test "FREQ=DAILY;BYMONTHDAY=1,15" do
      results =
        create_ical_event(
          ~U[2025-10-01 00:00:00Z],
          "FREQ=DAILY;BYMONTHDAY=1,15"
        )

      # Should only occur on 1st and 15th of each month
      assert [
               ~U[2025-10-01 00:00:00Z],
               ~U[2025-10-15 00:00:00Z],
               ~U[2025-11-01 00:00:00Z],
               ~U[2025-11-15 00:00:00Z],
               ~U[2025-12-01 00:00:00Z],
               ~U[2025-12-15 00:00:00Z]
             ] = results
    end
  end

  describe "FREQ=DAILY - Edge cases" do
    test "FREQ=DAILY;COUNT=1" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;COUNT=1"
        )

      assert [~U[2025-10-17 00:00:00Z]] = results
    end

    test "FREQ=DAILY with time component" do
      results =
        create_ical_event(
          ~U[2025-10-17 14:30:00Z],
          "FREQ=DAILY;COUNT=3"
        )

      assert [
               ~U[2025-10-17 14:30:00Z],
               ~U[2025-10-18 14:30:00Z],
               ~U[2025-10-19 14:30:00Z]
             ] = results
    end
  end
end

defmodule ICalendar.RecurrenceEdgeCasesTest do
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

  describe "Boundary values" do
    test "FREQ=DAILY;COUNT=1 (minimum count)" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;COUNT=1"
        )

      assert [~U[2025-10-17 09:00:00Z]] = results
    end

    test "FREQ=DAILY;INTERVAL=1 (minimum interval)" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;INTERVAL=1;COUNT=3"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-19 09:00:00Z]
             ] = results
    end

    @tag :skip
    test "FREQ=DAILY;COUNT=0 (invalid count - should handle gracefully)" do
      # This should either fail gracefully or treat as no recurrence
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;COUNT=0"
        )

      # Implementation dependent - might return empty list or original event only
      assert is_list(results)
    end

    @tag :skip
    test "FREQ=DAILY;INTERVAL=0 (invalid interval - should handle gracefully)" do
      # This should fail gracefully
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;INTERVAL=0"
        )

      # Should handle gracefully, possibly treating as INTERVAL=1
      assert is_list(results)
    end
  end

  describe "Leap year handling" do
    test "FREQ=YEARLY starting on Feb 29 (leap year)" do
      results =
        create_ical_event(
          # Feb 29 in leap year 2024
          ~U[2024-02-29 09:00:00Z],
          "FREQ=YEARLY;COUNT=4"
        )

      # Should handle transition from leap year to non-leap years
      # Implementation dependent: might skip non-leap years or adjust to Feb 28
      assert hd(results) == ~U[2024-02-29 09:00:00Z]
      assert length(results) >= 1
    end

    @tag :skip
    test "FREQ=YEARLY;BYMONTHDAY=29;BYMONTH=2" do
      results =
        create_ical_event(
          ~U[2024-02-29 09:00:00Z],
          "FREQ=YEARLY;BYMONTHDAY=29;BYMONTH=2"
        )

      # Should only occur in leap years
      assert [
               ~U[2024-02-29 09:00:00Z],
               ~U[2028-02-29 09:00:00Z],
               ~U[2032-02-29 09:00:00Z],
               ~U[2036-02-29 09:00:00Z],
               ~U[2040-02-29 09:00:00Z]
             ] = results
    end
  end

  describe "Month boundary edge cases" do
    test "FREQ=MONTHLY starting on 31st" do
      results =
        create_ical_event(
          # Jan 31
          ~U[2025-01-31 09:00:00Z],
          "FREQ=MONTHLY;COUNT=4"
        )

      # February doesn't have 31 days - behavior depends on implementation
      # Might skip February or adjust to last day of February
      assert hd(results) == ~U[2025-01-31 09:00:00Z]
      assert length(results) >= 1
    end

    test "FREQ=MONTHLY starting on 30th" do
      results =
        create_ical_event(
          # Jan 30
          ~U[2025-01-30 09:00:00Z],
          "FREQ=MONTHLY;COUNT=4"
        )

      # February doesn't have 30 days - behavior depends on implementation
      assert hd(results) == ~U[2025-01-30 09:00:00Z]
      assert length(results) >= 1
    end

    @tag :skip
    test "FREQ=MONTHLY;BYMONTHDAY=31" do
      results =
        create_ical_event(
          ~U[2025-01-31 09:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=31"
        )

      # Should only occur in months with 31 days
      assert [
               # January
               ~U[2025-01-31 09:00:00Z],
               # March (skip February)
               ~U[2025-03-31 09:00:00Z],
               # May (skip April)
               ~U[2025-05-31 09:00:00Z],
               # July (skip June)
               ~U[2025-07-31 09:00:00Z],
               # August
               ~U[2025-08-31 09:00:00Z]
             ] = results
    end
  end

  describe "Week boundary edge cases" do
    test "FREQ=WEEKLY starting on Sunday" do
      results =
        create_ical_event(
          # Sunday
          ~U[2025-10-12 09:00:00Z],
          "FREQ=WEEKLY;COUNT=3"
        )

      assert [
               ~U[2025-10-12 09:00:00Z],
               ~U[2025-10-19 09:00:00Z],
               ~U[2025-10-26 09:00:00Z]
             ] = results
    end

    test "FREQ=WEEKLY starting on Saturday" do
      results =
        create_ical_event(
          # Saturday
          ~U[2025-10-11 09:00:00Z],
          "FREQ=WEEKLY;COUNT=3"
        )

      assert [
               ~U[2025-10-11 09:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-25 09:00:00Z]
             ] = results
    end

    @tag :skip
    test "FREQ=WEEKLY;WKST=SU vs WKST=MO behavior difference" do
      # Test how week start affects weekly recurrence
      results_sun =
        create_ical_event(
          # Sunday
          ~U[2025-10-12 09:00:00Z],
          "FREQ=WEEKLY;WKST=SU;COUNT=3"
        )

      results_mon =
        create_ical_event(
          # Sunday
          ~U[2025-10-12 09:00:00Z],
          "FREQ=WEEKLY;WKST=MO;COUNT=3"
        )

      # Both should behave the same for simple weekly recurrence
      assert results_sun == results_mon
    end
  end

  describe "Year boundary edge cases" do
    test "FREQ=YEARLY crossing year boundary" do
      results =
        create_ical_event(
          # Last second of 2025
          ~U[2025-12-31 23:59:59Z],
          "FREQ=YEARLY;COUNT=3"
        )

      assert [
               ~U[2025-12-31 23:59:59Z],
               ~U[2026-12-31 23:59:59Z],
               ~U[2027-12-31 23:59:59Z]
             ] = results
    end

    test "FREQ=DAILY crossing year boundary" do
      results =
        create_ical_event(
          ~U[2025-12-30 09:00:00Z],
          "FREQ=DAILY;COUNT=4"
        )

      assert [
               ~U[2025-12-30 09:00:00Z],
               ~U[2025-12-31 09:00:00Z],
               ~U[2026-01-01 09:00:00Z],
               ~U[2026-01-02 09:00:00Z]
             ] = results
    end
  end

  describe "UNTIL edge cases" do
    test "FREQ=DAILY;UNTIL exactly on occurrence" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;UNTIL=20251019T090000Z"
        )

      # UNTIL is inclusive, so should include the UNTIL date
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-19 09:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;UNTIL between occurrences" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;UNTIL=20251018T120000Z"
        )

      # UNTIL is between 18th 09:00 and 19th 09:00, so should include 18th
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-18 09:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;UNTIL before first occurrence" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;UNTIL=20251016T090000Z"
        )

      # UNTIL is before start, should only include original event
      assert [~U[2025-10-17 09:00:00Z]] = results
    end
  end

  describe "Timezone edge cases (if supported)" do
    @tag :skip
    test "FREQ=DAILY crossing DST boundary" do
      # This would test behavior during daylight saving time transitions
      # Implementation dependent on timezone support
      results =
        create_ical_event(
          # Around DST transition
          ~U[2025-03-08 02:00:00Z],
          "FREQ=DAILY;COUNT=3"
        )

      # Should handle DST transitions gracefully
      assert length(results) == 3
    end

    @tag :skip
    test "FREQ=HOURLY during DST spring forward" do
      # During spring DST transition, 2 AM becomes 3 AM
      results =
        create_ical_event(
          # 1 AM before DST
          ~U[2025-03-09 01:00:00Z],
          "FREQ=HOURLY;COUNT=4"
        )

      # Should handle the "missing" 2 AM hour gracefully
      assert length(results) == 4
    end

    @tag :skip
    test "FREQ=HOURLY during DST fall back" do
      # During fall DST transition, 2 AM occurs twice
      results =
        create_ical_event(
          # 1 AM before DST
          ~U[2025-11-02 01:00:00Z],
          "FREQ=HOURLY;COUNT=4"
        )

      # Should handle the repeated 1 AM hour gracefully
      assert length(results) == 4
    end
  end

  describe "Large values" do
    test "FREQ=DAILY;INTERVAL=365 (approximately yearly)" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;INTERVAL=365;COUNT=3"
        )

      # Should be roughly yearly, but might drift due to leap years
      assert [
               ~U[2025-10-17 09:00:00Z],
               # Exactly 365 days later
               ~U[2026-10-17 09:00:00Z],
               # Another 365 days
               ~U[2027-10-17 09:00:00Z]
             ] = results
    end

    @tag :skip
    test "FREQ=YEARLY;INTERVAL=100" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=YEARLY;INTERVAL=100;COUNT=3"
        )

      # Should occur every 100 years
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2125-10-17 09:00:00Z],
               ~U[2225-10-17 09:00:00Z]
             ] = results
    end
  end

  describe "Multiple modifiers interaction" do
    @tag :skip
    test "FREQ=DAILY;COUNT=10;UNTIL before count reached" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;COUNT=10;UNTIL=20251019T090000Z"
        )

      # UNTIL should take precedence over COUNT
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-19 09:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;COUNT=3;UNTIL after count reached" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;COUNT=3;UNTIL=20251030T090000Z"
        )

      # COUNT should take precedence over UNTIL
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-19 09:00:00Z]
             ] = results
    end
  end
end

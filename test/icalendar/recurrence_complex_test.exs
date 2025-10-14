defmodule ICalendar.RecurrenceComplexTest do
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
      recurrances =
        ICalendar.Recurrence.get_recurrences(event)
        |> Enum.take(8)  # Take more for complex rules
        |> Enum.map(fn r -> r.dtstart end)

      [event.dtstart | recurrances]
    end)
  end

  describe "Complex BY* combinations (currently not supported)" do
    @tag :skip
    test "FREQ=MONTHLY;BYDAY=MO;BYMONTHDAY=1,2,3,4,5,6,7" do
      results =
        create_ical_event(
          ~U[2025-10-06 09:00:00Z], # First Monday in range
          "FREQ=MONTHLY;BYDAY=MO;BYMONTHDAY=1,2,3,4,5,6,7"
        )

      # Should occur on Monday if it falls on days 1-7 of the month (first week)
      assert [
               ~U[2025-10-06 09:00:00Z], # Oct 6 is Monday in first week
               ~U[2025-11-03 09:00:00Z], # Nov 3 is Monday in first week
               ~U[2025-12-01 09:00:00Z], # Dec 1 is Monday in first week
               ~U[2026-01-05 09:00:00Z], # Jan 5 is Monday in first week
               ~U[2026-02-02 09:00:00Z], # Feb 2 is Monday in first week
               ~U[2026-03-02 09:00:00Z]  # Mar 2 is Monday in first week
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=YEARLY;BYMONTH=1;BYDAY=SU;BYMONTHDAY=1,2,3,4,5,6,7" do
      results =
        create_ical_event(
          ~U[2025-01-05 09:00:00Z], # First Sunday of January 2025
          "FREQ=YEARLY;BYMONTH=1;BYDAY=SU;BYMONTHDAY=1,2,3,4,5,6,7"
        )

      # Should occur on first Sunday of January each year
      assert [
               ~U[2025-01-05 09:00:00Z],
               ~U[2026-01-04 09:00:00Z],
               ~U[2027-01-03 09:00:00Z],
               ~U[2028-01-02 09:00:00Z],
               ~U[2029-01-07 09:00:00Z], # Jan 1 is Mon, so first Sun is 7th
               ~U[2030-01-06 09:00:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=YEARLY;BYWEEKNO=1;BYDAY=MO" do
      results =
        create_ical_event(
          ~U[2025-01-06 09:00:00Z], # Monday of week 1, 2025
          "FREQ=YEARLY;BYWEEKNO=1;BYDAY=MO"
        )

      # Should occur on Monday of the first week of each year
      assert [
               ~U[2025-01-06 09:00:00Z],
               ~U[2026-01-05 09:00:00Z],
               ~U[2027-01-04 09:00:00Z],
               ~U[2028-01-03 09:00:00Z],
               ~U[2029-01-01 09:00:00Z],
               ~U[2030-01-07 09:00:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13" do
      results =
        create_ical_event(
          ~U[2025-06-13 09:00:00Z], # Friday the 13th in June 2025
          "FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13"
        )

      # Should only occur when the 13th falls on a Friday
      # This is the classic "Friday the 13th" rule
      assert hd(results) == ~U[2025-06-13 09:00:00Z]
      # Subsequent occurrences depend on when 13th falls on Friday
    end

    @tag :skip
    test "FREQ=DAILY;BYMONTH=6,7,8;BYDAY=MO,TU,WE,TH,FR" do
      results =
        create_ical_event(
          ~U[2025-06-02 09:00:00Z], # Monday in June
          "FREQ=DAILY;BYMONTH=6,7,8;BYDAY=MO,TU,WE,TH,FR"
        )

      # Should occur on weekdays during summer months (June, July, August)
      assert [
               ~U[2025-06-02 09:00:00Z], # Monday
               ~U[2025-06-03 09:00:00Z], # Tuesday
               ~U[2025-06-04 09:00:00Z], # Wednesday
               ~U[2025-06-05 09:00:00Z], # Thursday
               ~U[2025-06-06 09:00:00Z], # Friday
               ~U[2025-06-09 09:00:00Z]  # Next Monday (skip weekend)
             ] = Enum.take(results, 6)
    end
  end

  describe "BYSETPOS combinations (currently not supported)" do
    @tag :skip
    test "FREQ=YEARLY;BYDAY=MO;BYSETPOS=1,50" do
      results =
        create_ical_event(
          ~U[2025-01-06 09:00:00Z], # First Monday of 2025
          "FREQ=YEARLY;BYDAY=MO;BYSETPOS=1,50"
        )

      # Should occur on 1st and 50th Monday of each year
      # Most years have 52-53 Mondays, so 50th should exist
      assert [
               ~U[2025-01-06 09:00:00Z], # 1st Monday
               ~U[2025-12-15 09:00:00Z], # 50th Monday (approximate)
               ~U[2026-01-05 09:00:00Z], # 1st Monday next year
               ~U[2026-12-14 09:00:00Z]  # 50th Monday next year
             ] = Enum.take(results, 4)
    end

    @tag :skip
    test "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1,-1" do
      results =
        create_ical_event(
          ~U[2025-10-13 09:00:00Z], # First weekday of week
          "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1,-1"
        )

      # Should occur on first and last weekday of each week
      assert [
               ~U[2025-10-13 09:00:00Z], # Monday (first weekday)
               ~U[2025-10-17 09:00:00Z], # Friday (last weekday)
               ~U[2025-10-20 09:00:00Z], # Next Monday
               ~U[2025-10-24 09:00:00Z], # Next Friday
               ~U[2025-10-27 09:00:00Z], # Following Monday
               ~U[2025-10-31 09:00:00Z]  # Following Friday
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1,2,3" do
      results =
        create_ical_event(
          ~U[2025-10-01 09:00:00Z], # First weekday of October
          "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1,2,3"
        )

      # Should occur on 1st, 2nd, and 3rd weekday of each month
      assert [
               ~U[2025-10-01 09:00:00Z], # 1st weekday (Wed)
               ~U[2025-10-02 09:00:00Z], # 2nd weekday (Thu)
               ~U[2025-10-03 09:00:00Z], # 3rd weekday (Fri)
               ~U[2025-11-03 09:00:00Z], # 1st weekday of Nov (Mon)
               ~U[2025-11-04 09:00:00Z], # 2nd weekday of Nov (Tue)
               ~U[2025-11-05 09:00:00Z]  # 3rd weekday of Nov (Wed)
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-3,-2,-1" do
      results =
        create_ical_event(
          ~U[2025-10-29 09:00:00Z], # 3rd from last weekday
          "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-3,-2,-1"
        )

      # Should occur on last 3 weekdays of each month
      assert [
               ~U[2025-10-29 09:00:00Z], # 3rd from last (Tue)
               ~U[2025-10-30 09:00:00Z], # 2nd from last (Wed)
               ~U[2025-10-31 09:00:00Z], # Last (Thu)
               ~U[2025-11-26 09:00:00Z], # 3rd from last of Nov
               ~U[2025-11-27 09:00:00Z], # 2nd from last of Nov
               ~U[2025-11-28 09:00:00Z]  # Last of Nov
             ] = Enum.take(results, 6)
    end
  end

  describe "Time-based BY* rules with date frequencies (currently not supported)" do
    @tag :skip
    test "FREQ=DAILY;BYHOUR=9,12,15;BYMINUTE=0,30" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=DAILY;BYHOUR=9,12,15;BYMINUTE=0,30"
        )

      # Should create 6 events per day: 9:00, 9:30, 12:00, 12:30, 15:00, 15:30
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:30:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 12:30:00Z],
               ~U[2025-10-17 15:00:00Z],
               ~U[2025-10-17 15:30:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=9,17" do
      results =
        create_ical_event(
          ~U[2025-10-13 09:00:00Z], # Monday
          "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=9,17"
        )

      # Should occur twice on Mon/Wed/Fri: at 9 AM and 5 PM
      assert [
               ~U[2025-10-13 09:00:00Z], # Mon 9 AM
               ~U[2025-10-13 17:00:00Z], # Mon 5 PM
               ~U[2025-10-15 09:00:00Z], # Wed 9 AM
               ~U[2025-10-15 17:00:00Z], # Wed 5 PM
               ~U[2025-10-17 09:00:00Z], # Fri 9 AM
               ~U[2025-10-17 17:00:00Z]  # Fri 5 PM
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MONTHLY;BYMONTHDAY=1,15;BYHOUR=12;BYMINUTE=0" do
      results =
        create_ical_event(
          ~U[2025-10-01 12:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=1,15;BYHOUR=12;BYMINUTE=0"
        )

      # Should occur on 1st and 15th of each month at noon
      assert [
               ~U[2025-10-01 12:00:00Z],
               ~U[2025-10-15 12:00:00Z],
               ~U[2025-11-01 12:00:00Z],
               ~U[2025-11-15 12:00:00Z],
               ~U[2025-12-01 12:00:00Z],
               ~U[2025-12-15 12:00:00Z]
             ] = Enum.take(results, 6)
    end
  end

  describe "Invalid/Edge case combinations (should fail gracefully)" do
    @tag :skip
    test "FREQ=MONTHLY;BYMONTHDAY=30;BYMONTH=2" do
      # February never has 30 days - should handle gracefully
      results =
        create_ical_event(
          ~U[2025-01-30 09:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=30;BYMONTH=2"
        )

      # Should either skip February or handle the error gracefully
      # Implementation dependent
      assert is_list(results)
    end

    @tag :skip
    test "FREQ=YEARLY;BYYEARDAY=366" do
      # Day 366 only exists in leap years
      results =
        create_ical_event(
          ~U[2024-12-31 09:00:00Z], # Dec 31 in leap year (day 366)
          "FREQ=YEARLY;BYYEARDAY=366"
        )

      # Should only occur in leap years
      assert hd(results) == ~U[2024-12-31 09:00:00Z]
      # Next occurrence should be 2028 (next leap year)
    end

    @tag :skip
    test "FREQ=WEEKLY;BYDAY=MO;BYMONTHDAY=1" do
      # Monday that falls on 1st of month - rare combination
      results =
        create_ical_event(
          ~U[2025-12-01 09:00:00Z], # Dec 1, 2025 is Monday
          "FREQ=WEEKLY;BYDAY=MO;BYMONTHDAY=1"
        )

      # Should only occur when 1st of month is Monday
      assert hd(results) == ~U[2025-12-01 09:00:00Z]
      # Very infrequent occurrences
    end
  end
end

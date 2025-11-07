defmodule ICalendar.RecurrenceMonthlyTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(%DateTime{} = dtstart, rrule, timezone \\ nil, take \\ 5) do
    start = ICalendar.Value.to_ics(dtstart)

    # if the rrule does not contain LOCAL-TZID=UTC then we need to add it
    rrule =
      if String.contains?(rrule, "LOCAL-TZID") do
        rrule
      else
        rrule <> ";LOCAL-TZID=UTC"
      end

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
      end_date = DateTime.add(dtstart, 2 * 365, :day)

      ICalendar.Recurrence.get_recurrences(event, dtstart, end_date, timezone)
      |> Enum.take(take)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=MONTHLY - Basic" do
    test "FREQ=MONTHLY" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-11-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-14 07:00:00Z]
             ] = results
    end

    test "FREQ=MONTHLY;COUNT=6" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;COUNT=6"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-11-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-14 07:00:00Z]
             ] = results
    end

    test "FREQ=MONTHLY;UNTIL=20260301T070000Z" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;UNTIL=20260301T070000Z"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-11-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-14 07:00:00Z]
             ] = results
    end
  end

  describe "FREQ=MONTHLY - With Interval" do
    test "FREQ=MONTHLY;INTERVAL=2" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;INTERVAL=2"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-02-14 07:00:00Z],
               ~U[2026-04-14 07:00:00Z],
               ~U[2026-06-14 07:00:00Z]
             ] = results
    end

    test "FREQ=MONTHLY;INTERVAL=3;COUNT=4" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;INTERVAL=3;COUNT=4"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-04-14 07:00:00Z],
               ~U[2026-07-14 07:00:00Z]
             ] = results
    end
  end

  # test "ex" do
  #   results =
  #     ExCycle.new()
  #     |> ExCycle.add_rule(:monthly, days: [{2,  :wednesday}])
  #     # |> ExCycle.add_rule(:daily, interval: 2, hours: [20, 10])
  #     # |> ExCycle.add_rule(:daily, interval: 1, hours: [15])
  #     |> ExCycle.occurrences(~U[2025-10-13 07:00:00Z])
  #     |> Enum.take(5)
  #     |> IO.inspect(label: "EX CYCLE TEST")

  #   assert results == [
  #            # Monday
  #            ~U[2025-10-13 07:00:00Z],
  #            # Wednesday
  #            ~U[2025-10-15 07:00:00Z],
  #            # Friday
  #            ~U[2025-10-17 07:00:00Z],
  #            # Next Monday
  #            ~U[2025-10-20 07:00:00Z],
  #            # Next Wednesday
  #            ~U[2025-10-22 07:00:00Z],
  #            # Next Friday
  #            ~U[2025-10-24 07:00:00Z]
  #          ]
  # end

  describe "FREQ=MONTHLY - With BYDAY (partially supported)" do
    test "FREQ=MONTHLY;BYDAY=2WE;COUNT=5" do
      results =
        create_ical_event(
          # 2nd Wednesday of October 2025
          ~U[2025-10-08 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=2WE;COUNT=5"
        )

      assert results == [
               ~U[2025-10-08 07:00:00Z],
               ~U[2025-11-12 07:00:00Z],
               ~U[2025-12-10 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-11 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYDAY=1MO;COUNT=5" do
      results =
        create_ical_event(
          # 1st Monday of October 2025
          ~U[2025-10-06 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=1MO;COUNT=5"
        )

      assert [
               ~U[2025-10-06 07:00:00Z],
               ~U[2025-11-03 07:00:00Z],
               ~U[2025-12-01 07:00:00Z],
               ~U[2026-01-05 07:00:00Z],
               ~U[2026-02-02 07:00:00Z]
             ] = results
    end

    test "FREQ=MONTHLY;BYDAY=-1FR;COUNT=5" do
      results =
        create_ical_event(
          # Last Friday of October 2025
          ~U[2025-10-25 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=-1FR;COUNT=5;X-INCLUDE-DTSTART=TRUE"
        )

      assert results == [
               ~U[2025-10-25 07:00:00Z],
               ~U[2025-10-31 07:00:00Z],
               ~U[2025-11-28 07:00:00Z],
               ~U[2025-12-26 07:00:00Z],
               ~U[2026-01-30 07:00:00Z]
             ]
    end
  end

  describe "FREQ=MONTHLY - BYMONTHDAY (currently not supported)" do
    test "FREQ=MONTHLY;BYMONTHDAY=15" do
      results =
        create_ical_event(
          ~U[2025-10-15 07:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=15"
        )

      assert results == [
               ~U[2025-10-15 07:00:00Z],
               ~U[2025-11-15 07:00:00Z],
               ~U[2025-12-15 07:00:00Z],
               ~U[2026-01-15 07:00:00Z],
               ~U[2026-02-15 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYMONTHDAY=1,15" do
      results =
        create_ical_event(
          ~U[2025-10-01 07:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=1,15"
        )

      assert results == [
               ~U[2025-10-01 07:00:00Z],
               ~U[2025-10-15 07:00:00Z],
               ~U[2025-11-01 07:00:00Z],
               ~U[2025-11-15 07:00:00Z],
               ~U[2025-12-01 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYMONTHDAY=-1" do
      results =
        create_ical_event(
          # Last day of October
          ~U[2025-10-31 07:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=-1",
          nil,
          6
        )

      assert results == [
               ~U[2025-10-31 07:00:00Z],
               ~U[2025-11-30 07:00:00Z],
               ~U[2025-12-31 07:00:00Z],
               ~U[2026-01-31 07:00:00Z],
               # February has 28 days in 2026
               ~U[2026-02-28 07:00:00Z],
               ~U[2026-03-31 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYMONTHDAY=-3,-1" do
      results =
        create_ical_event(
          # 3rd from last day of October
          ~U[2025-10-29 07:00:00Z],
          "FREQ=MONTHLY;BYMONTHDAY=-3,-1",
          nil,
          6
        )

      # Should occur on 3rd from last and last day of each month
      assert results == [
               # Oct 29 (3rd from last)
               ~U[2025-10-29 07:00:00Z],
               # Oct 31 (last)
               ~U[2025-10-31 07:00:00Z],
               # Nov 28 (3rd from last)
               ~U[2025-11-28 07:00:00Z],
               # Nov 30 (last)
               ~U[2025-11-30 07:00:00Z],
               # Dec 29 (3rd from last)
               ~U[2025-12-29 07:00:00Z],
               # Dec 31 (last)
               ~U[2025-12-31 07:00:00Z]
             ]
    end
  end

  describe "FREQ=MONTHLY - BYSETPOS" do
    test "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1" do
      results =
        create_ical_event(
          # First weekday of October
          ~U[2025-10-01 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1"
        )

      # Should be first weekday of each month
      assert results == [
               # Oct 1 (Wed)
               ~U[2025-10-01 07:00:00Z],
               # Nov 3 (Mon) - Nov 1 is Fri, Nov 2 is Sat, Nov 3 is Mon
               ~U[2025-11-03 07:00:00Z],
               # Dec 1 (Mon)
               ~U[2025-12-01 07:00:00Z],
               # Jan 1 (Thu)
               ~U[2026-01-01 07:00:00Z],
               # Feb 2 (Mon) - Feb 1 is Sun
               ~U[2026-02-02 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1" do
      results =
        create_ical_event(
          # Last weekday of October (Thu)
          ~U[2025-10-31 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1",
          nil,
          6
        )

      # Should be last weekday of each month
      assert results == [
               # Oct 31 (Thu)
               ~U[2025-10-31 07:00:00Z],
               # Nov 28 (Fri)
               ~U[2025-11-28 07:00:00Z],
               # Dec 31 (Tue)
               ~U[2025-12-31 07:00:00Z],
               # Jan 30 (Fri)
               ~U[2026-01-30 07:00:00Z],
               # Feb 27 (Fri)
               ~U[2026-02-27 07:00:00Z],
               # Mar 31 (Tue)
               ~U[2026-03-31 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYDAY=SA,SU;BYSETPOS=1" do
      results =
        create_ical_event(
          # First weekend day of October (Sat)
          ~U[2025-10-04 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=SA,SU;BYSETPOS=1",
          nil,
          6
        )

      # Should be first weekend day of each month
      assert results == [
               # Oct 4 (Sat)
               ~U[2025-10-04 07:00:00Z],
               # Nov 1 (Sat)
               ~U[2025-11-01 07:00:00Z],
               # Dec 6 (Sat)
               ~U[2025-12-06 07:00:00Z],
               # Jan 3 (Sat) - Jan 1&2 are weekdays
               ~U[2026-01-03 07:00:00Z],
               # Feb 1 (Sun)
               ~U[2026-02-01 07:00:00Z],
               # Mar 1 (Sun)
               ~U[2026-03-01 07:00:00Z]
             ]
    end

    test "FREQ=MONTHLY;BYDAY=SA,SU;BYSETPOS=-1" do
      results =
        create_ical_event(
          # Last weekend day of October (Sun)
          ~U[2025-10-26 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=SA,SU;BYSETPOS=-1",
          nil,
          6
        )

      # Should be last weekend day of each month
      assert results == [
               # Oct 26 (Sun)
               ~U[2025-10-26 07:00:00Z],
               # Nov 30 (Sun)
               ~U[2025-11-30 07:00:00Z],
               # Dec 28 (Sun)
               ~U[2025-12-28 07:00:00Z],
               # Jan 31 (Sat)
               ~U[2026-01-31 07:00:00Z],
               # Feb 28 (Sat)
               ~U[2026-02-28 07:00:00Z],
               # Mar 29 (Sun)
               ~U[2026-03-29 07:00:00Z]
             ]
    end
  end

  describe "FREQ=MONTHLY - Multiple BYDAY values (currently not supported)" do
    test "FREQ=MONTHLY;BYDAY=1MO,3WE" do
      results =
        create_ical_event(
          # 1st Monday of October
          ~U[2025-10-06 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=1MO,3WE",
          nil,
          6
        )

      # Should occur on 1st Monday and 3rd Wednesday of each month
      assert results == [
               # Oct 6 (1st Mon)
               ~U[2025-10-06 07:00:00Z],
               # Oct 15 (3rd Wed)
               ~U[2025-10-15 07:00:00Z],
               # Nov 3 (1st Mon)
               ~U[2025-11-03 07:00:00Z],
               # Nov 19 (3rd Wed)
               ~U[2025-11-19 07:00:00Z],
               # Dec 1 (1st Mon)
               ~U[2025-12-01 07:00:00Z],
               # Dec 17 (3rd Wed)
               ~U[2025-12-17 07:00:00Z]
             ]
    end
  end

  describe "FREQ=MONTHLY - Edge cases" do
    test "FREQ=MONTHLY;COUNT=1" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;COUNT=1"
        )

      assert [~U[2025-10-14 07:00:00Z]] = results
    end

    test "FREQ=MONTHLY on 31st (month boundary handling)" do
      results =
        create_ical_event(
          # Oct 31
          ~U[2025-10-31 07:00:00Z],
          "FREQ=MONTHLY;COUNT=3"
        )

      # November doesn't have 31 days, so should skip to December 31
      # This behavior depends on implementation - some skip, some adjust
      # ical.js skips

      assert [
               ~U[2025-10-31 07:00:00Z],
               ~U[2025-12-31 07:00:00Z],
               ~U[2026-01-31 07:00:00Z]
             ] =
               results
    end

    test "FREQ=MONTHLY leap year February 29" do
      results =
        create_ical_event(
          # Feb 29 in leap year 2024
          ~U[2024-02-29 07:00:00Z],
          "FREQ=MONTHLY;COUNT=3"
        )

      # Should handle transition from leap year to non-leap year
      assert [~U[2024-02-29 07:00:00Z], ~U[2024-03-29 07:00:00Z], ~U[2024-04-29 07:00:00Z]] =
               results
    end
  end
end

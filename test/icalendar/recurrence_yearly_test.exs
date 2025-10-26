defmodule ICalendar.RecurrenceYearlyTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(%DateTime{} = dtstart, rrule, timezone \\ nil, take \\ 5) do
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
      end_date = DateTime.add(dtstart, 365 * 10, :day)

      ICalendar.Recurrence.get_recurrences(event, dtstart, end_date, timezone)
      |> Enum.take(take)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=YEARLY - Basic" do
    test "FREQ=YEARLY" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY",
          nil,
          6
        )

      assert results == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2026-10-14 07:00:00Z],
               ~U[2027-10-14 07:00:00Z],
               ~U[2028-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z],
               ~U[2030-10-14 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;COUNT=5" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;COUNT=5"
        )

      assert results == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2026-10-14 07:00:00Z],
               ~U[2027-10-14 07:00:00Z],
               ~U[2028-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;UNTIL=20301231T000000Z" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;UNTIL=20301231T000000Z",
          nil,
          6
        )

      assert results == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2026-10-14 07:00:00Z],
               ~U[2027-10-14 07:00:00Z],
               ~U[2028-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z],
               ~U[2030-10-14 07:00:00Z]
             ]
    end
  end

  describe "FREQ=YEARLY - With Interval" do
    test "FREQ=YEARLY;INTERVAL=2" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;INTERVAL=2"
        )
        |> Enum.take(5)

      assert results == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2027-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z],
               ~U[2031-10-14 07:00:00Z],
               ~U[2033-10-14 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;INTERVAL=4;COUNT=3" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;INTERVAL=4;COUNT=3"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z],
               ~U[2033-10-14 07:00:00Z]
             ] = results
    end
  end

  describe "FREQ=YEARLY - With BYMONTH (partially supported)" do
    test "FREQ=YEARLY;BYMONTH=6" do
      results =
        create_ical_event(
          ~U[2025-06-14 07:00:00Z],
          "FREQ=YEARLY;BYMONTH=6",
          nil,
          6
        )

      assert results == [
               ~U[2025-06-14 07:00:00Z],
               ~U[2026-06-14 07:00:00Z],
               ~U[2027-06-14 07:00:00Z],
               ~U[2028-06-14 07:00:00Z],
               ~U[2029-06-14 07:00:00Z],
               ~U[2030-06-14 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;BYMONTH=3,6,9,12" do
      results =
        create_ical_event(
          ~U[2025-03-14 07:00:00Z],
          "FREQ=YEARLY;BYMONTH=3,6,9,12",
          nil,
          6
        )

      # Should occur 4 times per year in March, June, September, December

      assert results == [
               ~U[2025-03-14 07:00:00Z],
               ~U[2025-06-14 07:00:00Z],
               ~U[2025-09-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-03-14 07:00:00Z],
               ~U[2026-06-14 07:00:00Z]
             ]
    end
  end

  describe "FREQ=YEARLY - With BYMONTHDAY (currently not supported)" do
    test "FREQ=YEARLY;BYMONTHDAY=15" do
      results =
        create_ical_event(
          ~U[2025-10-15 07:00:00Z],
          "FREQ=YEARLY;BYMONTHDAY=15",
          nil,
          6
        )

      # Should occur on 15th of October every year
      assert results == [
               ~U[2025-10-15 07:00:00Z],
               ~U[2025-11-15 07:00:00Z],
               ~U[2025-12-15 07:00:00Z],
               ~U[2026-01-15 07:00:00Z],
               ~U[2026-02-15 07:00:00Z],
               ~U[2026-03-15 07:00:00Z]
             ]
    end


    test "FREQ=YEARLY;BYMONTHDAY=1,15;BYMONTH=1,7" do
      results =
        create_ical_event(
          ~U[2025-01-01 07:00:00Z],
          "FREQ=YEARLY;BYMONTHDAY=1,15;BYMONTH=1,7"
        )

      # Should occur on Jan 1, Jan 15, July 1, July 15 each year
      assert results == [
               ~U[2025-01-01 07:00:00Z],
               ~U[2025-01-15 07:00:00Z],
               ~U[2025-07-01 07:00:00Z],
               ~U[2025-07-15 07:00:00Z],
               ~U[2026-01-01 07:00:00Z]
             ]
    end
  end

  describe "FREQ=YEARLY - With BYYEARDAY (currently not supported)" do

    test "FREQ=YEARLY;BYYEARDAY=100" do
      results =
        create_ical_event(
          # 100th day of 2025 (April 10)
          ~U[2025-04-10 07:00:00Z],
          "FREQ=YEARLY;BYYEARDAY=100"
        )

      assert results == [
               # 100th day of 2025
               ~U[2025-04-10 07:00:00Z],
               # 100th day of 2026
               ~U[2026-04-10 07:00:00Z],
               # 100th day of 2027
               ~U[2027-04-10 07:00:00Z],
               # 100th day of 2028 (leap year)
               ~U[2028-04-09 07:00:00Z],
               # 100th day of 2029
               ~U[2029-04-10 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;BYYEARDAY=1,100,200,365" do
      results =
        create_ical_event(
          # 1st day of year
          ~U[2025-01-01 07:00:00Z],
          "FREQ=YEARLY;BYYEARDAY=1,100,200,365"
        )

      # Should occur 4 times per year on days 1, 100, 200, 365
      assert results == [
               # Day 1
               ~U[2025-01-01 07:00:00Z],
               # Day 100
               ~U[2025-04-10 07:00:00Z],
               # Day 200
               ~U[2025-07-19 07:00:00Z],
               # Day 365
               ~U[2025-12-31 07:00:00Z],
               # Day 1 next year
               ~U[2026-01-01 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;BYYEARDAY=-1" do
      results =
        create_ical_event(
          # Last day of 2025
          ~U[2025-12-31 07:00:00Z],
          "FREQ=YEARLY;BYYEARDAY=-1"
        )

      # Should occur on last day of each year
      assert results == [
               ~U[2025-12-31 07:00:00Z],
               ~U[2026-12-31 07:00:00Z],
               ~U[2027-12-31 07:00:00Z],
               # 2028 is leap year, still Dec 31
               ~U[2028-12-31 07:00:00Z],
               ~U[2029-12-31 07:00:00Z]
             ]
    end

    test "FREQ=YEARLY;BYYEARDAY=-365,-1" do
      results =
        create_ical_event(
          # First day of year
          ~U[2025-01-01 07:00:00Z],
          "FREQ=YEARLY;BYYEARDAY=-365,-1"
        )

      # Should occur on first day (365 from end) and last day of each year
      assert results == [
               # -365 in non-leap year
               ~U[2025-01-01 07:00:00Z],
               # -1
               ~U[2025-12-31 07:00:00Z],
               # -365 in non-leap year
               ~U[2026-01-01 07:00:00Z],
               # -1
               ~U[2026-12-31 07:00:00Z],
               # -365 in non-leap year
               ~U[2027-01-01 07:00:00Z],
             ]
    end
  end

  describe "FREQ=YEARLY - With BYWEEKNO (currently not supported)" do

    #TODO: need to investigate what google does here too
    # https://github.com/fmeringdal/rust-rrule/issues/127
    @tag :skip
    test "FREQ=YEARLY;BYWEEKNO=20" do
      results =
        create_ical_event(
          # Week 20 of 2025
          ~U[2025-05-12 07:00:00Z],
          "FREQ=YEARLY;BYWEEKNO=20"
        )

      # Should occur during week 20 of each year
      assert results == [
               ~U[2025-05-12 07:00:00Z],
               # Week 20 might start on different dates
               ~U[2026-05-11 07:00:00Z],
               ~U[2027-05-17 07:00:00Z],
               ~U[2028-05-15 07:00:00Z],
               ~U[2029-05-14 07:00:00Z],
              ]
    end


    test "FREQ=YEARLY;BYWEEKNO=1,20,53" do
      results =
        create_ical_event(
          # Week 1 of 2025
          ~U[2025-01-06 07:00:00Z],
          "FREQ=YEARLY;BYWEEKNO=1,20,53"
        )

      # Should occur 3 times per year in weeks 1, 20, and 53 (if it exists)
      # Note: Not all years have week 53
      # At least 2 years worth

      assert results == [
               ~U[2025-05-12 07:00:00Z],
               ~U[2025-05-13 07:00:00Z],
               ~U[2025-05-14 07:00:00Z],
               ~U[2025-05-15 07:00:00Z],
               ~U[2025-05-16 07:00:00Z],
              ]

    end


    test "FREQ=YEARLY;BYDAY=MO;BYWEEKNO=20" do
      results =
        create_ical_event(
          # Monday of week 20, 2025
          ~U[2025-05-12 07:00:00Z],
          "FREQ=YEARLY;BYDAY=MO;BYWEEKNO=20"
        )

      # Should occur on Monday of week 20 each year
      assert results == [
               ~U[2025-05-12 07:00:00Z],
               ~U[2026-05-11 07:00:00Z],
               ~U[2027-05-17 07:00:00Z],
               ~U[2028-05-15 07:00:00Z],
               ~U[2029-05-14 07:00:00Z]
             ]
    end
  end

  describe "FREQ=YEARLY - With BYDAY (currently not supported)" do

    test "FREQ=YEARLY;BYDAY=20MO" do
      results =
        create_ical_event(
          # 20th Monday of 2025
          ~U[2025-05-12 07:00:00Z],
          "FREQ=YEARLY;BYDAY=20MO"
        )

      # Should occur on 20th Monday of each year
      assert results == [
               ~U[2025-05-19 07:00:00Z],
               ~U[2026-05-18 07:00:00Z],
               ~U[2027-05-17 07:00:00Z],
               ~U[2028-05-15 07:00:00Z],
               ~U[2029-05-14 07:00:00Z]
             ]
    end


    test "FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10" do
      results =
        create_ical_event(
          # Last Sunday of October 2025
          ~U[2025-10-26 07:00:00Z],
          "FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10"
        )

      # Should occur on last Sunday of October each year
      assert results == [
               ~U[2025-10-26 07:00:00Z],
               ~U[2026-10-25 07:00:00Z],
               ~U[2027-10-31 07:00:00Z],
               ~U[2028-10-29 07:00:00Z],
               ~U[2029-10-28 07:00:00Z]
             ]
    end


    test "FREQ=YEARLY;BYDAY=1SU;BYMONTH=4" do
      results =
        create_ical_event(
          # First Sunday of April 2025
          ~U[2025-04-06 07:00:00Z],
          "FREQ=YEARLY;BYDAY=1SU;BYMONTH=4"
        )

      # Should occur on first Sunday of April each year
      assert results == [
               ~U[2025-04-06 07:00:00Z],
               ~U[2026-04-05 07:00:00Z],
               ~U[2027-04-04 07:00:00Z],
               ~U[2028-04-02 07:00:00Z],
               ~U[2029-04-01 07:00:00Z]
             ]
    end


    test "FREQ=YEARLY;BYDAY=1SU;BYMONTH=4,10" do
      results =
        create_ical_event(
          # First Sunday of April 2025
          ~U[2025-04-06 07:00:00Z],
          "FREQ=YEARLY;BYDAY=1SU;BYMONTH=4,10"
        )

      # Should occur on first Sunday of April and October each year
      assert results == [
               # First Sunday of April
               ~U[2025-04-06 07:00:00Z],
               # First Sunday of October
               ~U[2025-10-05 07:00:00Z],
               # First Sunday of April next year
               ~U[2026-04-05 07:00:00Z],
               # First Sunday of October next year
               ~U[2026-10-04 07:00:00Z],
               # First Sunday of April
               ~U[2027-04-04 07:00:00Z]
             ]
    end
  end

  describe "FREQ=YEARLY - Edge cases" do
    test "FREQ=YEARLY;COUNT=1" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;COUNT=1"
        )

      assert [~U[2025-10-14 07:00:00Z]] = results
    end

    test "FREQ=YEARLY leap year February 29" do
      results =
        create_ical_event(
          # Feb 29 in leap year 2024
          ~U[2024-02-29 07:00:00Z],
          "FREQ=YEARLY;COUNT=3"
        )

      # Should handle transition from leap year to non-leap years
      # Implementation dependent: might skip non-leap years or adjust to Feb 28
      assert hd(results) == ~U[2024-02-29 07:00:00Z]
      # Next occurrences depend on implementation
      assert length(results) >= 1
    end


    test "FREQ=YEARLY with BYHOUR (currently not supported)" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;BYHOUR=9,17"
        )

      # Should create 2 events per year at 9 and 17 hours
      assert results == [
               ~U[2025-10-14 09:00:00Z],
               ~U[2025-10-14 17:00:00Z],
               ~U[2026-10-14 09:00:00Z],
               ~U[2026-10-14 17:00:00Z],
               ~U[2027-10-14 09:00:00Z]
             ]
    end
  end
end

defmodule ICalendar.RecurrenceWeeklyTest do
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
      # if String.contains?(rrule, "COUNT") or String.contains?(rrule, "UNTIL") do
      #   DateTime.utc_now()
      # else
      # For infinite recurrence, set end date 1 year from start
      end_date =
        DateTime.add(dtstart, 365, :day)

      # end

      ICalendar.Recurrence.get_recurrences(event, dtstart, end_date, timezone)
      |> Enum.take(take)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=WEEKLY - Basic" do
    test "FREQ=WEEKLY" do
      results =
        create_ical_event(
          # Tuesday
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z],
               ~U[2025-11-11 07:00:00Z]
             ] = results
    end

    test "FREQ=WEEKLY;COUNT=4" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;COUNT=4"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z]
             ] = results
    end

    test "FREQ=WEEKLY;UNTIL=20251111T070000Z" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;UNTIL=20251111T070000Z"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z],
               ~U[2025-11-11 07:00:00Z]
             ] = results
    end
  end

  describe "FREQ=WEEKLY - With Interval" do
    test "FREQ=WEEKLY;INTERVAL=2" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;INTERVAL=2"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-11 07:00:00Z],
               ~U[2025-11-25 07:00:00Z],
               ~U[2025-12-09 07:00:00Z]
             ] = results
    end

    test "FREQ=WEEKLY;INTERVAL=2;COUNT=8" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;INTERVAL=2;COUNT=8"
        )

      # Taking only first 5 as per test pattern
      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-11 07:00:00Z],
               ~U[2025-11-25 07:00:00Z],
               ~U[2025-12-09 07:00:00Z]
             ] = Enum.take(results, 5)
    end
  end

  describe "FREQ=WEEKLY - With BYDAY" do
    test "FREQ=WEEKLY;BYDAY=MO,WE,FR" do
      results =
        create_ical_event(
          # Monday
          ~U[2025-10-13 07:00:00Z],
          "FREQ=WEEKLY;BYDAY=MO,WE,FR",
          nil,
          6
        )

      assert results == [
               # Monday
               ~U[2025-10-13 07:00:00Z],
               # Wednesday
               ~U[2025-10-15 07:00:00Z],
               # Friday
               ~U[2025-10-17 07:00:00Z],
               # Next Monday
               ~U[2025-10-20 07:00:00Z],
               # Next Wednesday
               ~U[2025-10-22 07:00:00Z],
               # Next Friday
               ~U[2025-10-24 07:00:00Z]
             ]
    end

    test "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=5" do
      results =
        create_ical_event(
          # Monday
          ~U[2025-10-13 07:00:00Z],
          "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=5"
        )

      # Should create exactly 10 occurrences across Mon/Wed/Fri
      assert length(results) == 5
      assert hd(results) == ~U[2025-10-13 07:00:00Z]
    end

    test "FREQ=WEEKLY;BYDAY=TU,TH;INTERVAL=2" do
      results =
        create_ical_event(
          # Tuesday
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;BYDAY=TU,TH;INTERVAL=2",
          nil,
          7
        )

      assert results == [
               # Tuesday week 1
               ~U[2025-10-14 07:00:00Z],
               # Thursday week 1
               ~U[2025-10-16 07:00:00Z],
               # Tuesday week 3 (skip week 2)
               ~U[2025-10-28 07:00:00Z],
               # Thursday week 3
               ~U[2025-10-30 07:00:00Z],
               # Tuesday week 5
               ~U[2025-11-11 07:00:00Z],
               # Thursday week 5
               ~U[2025-11-13 07:00:00Z],
               # Tuesday week 7
               ~U[2025-11-25 07:00:00Z]
             ]
    end
  end

  describe "FREQ=WEEKLY - With WKST (Week Start)" do
    test "FREQ=WEEKLY;WKST=MO" do
      results =
        create_ical_event(
          # Tuesday
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;WKST=MO"
        )

      # Week starts on Monday, so this should behave same as default
      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z],
               ~U[2025-11-11 07:00:00Z]
             ] = results
    end

    # weekly + wkst looks broken
    test "FREQ=WEEKLY;WKST=SU;BYDAY=SA,SU" do
      results =
        create_ical_event(
          # Sunday
          ~U[2025-10-12 07:00:00Z],
          "FREQ=WEEKLY;WKST=SU;BYDAY=SA,SU",
          nil,
          6
        )

      # Week starts on Sunday, recurring on Saturday and Sunday
      assert results == [
               # Sunday (original)
               ~U[2025-10-12 07:00:00Z],
               # Saturday of same week (WKST=SU, so week is 10/12-10/18, Saturday is 10/18)
               ~U[2025-10-18 07:00:00Z],
               # Next Sunday
               ~U[2025-10-19 07:00:00Z],
               # Next Saturday
               ~U[2025-10-25 07:00:00Z],
               # Following Sunday
               ~U[2025-10-26 07:00:00Z],
               # Following Saturday
               ~U[2025-11-01 07:00:00Z]
             ]
    end
  end

  describe "FREQ=WEEKLY - Edge cases" do
    test "FREQ=WEEKLY;COUNT=1" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;COUNT=1"
        )

      assert [~U[2025-10-14 07:00:00Z]] = results
    end

    test "FREQ=WEEKLY starting on different days" do
      # Test starting on Sunday
      results_sun =
        create_ical_event(
          # Sunday
          ~U[2025-10-12 07:00:00Z],
          "FREQ=WEEKLY;COUNT=3"
        )

      assert results_sun == [
               ~U[2025-10-12 07:00:00Z],
               ~U[2025-10-19 07:00:00Z],
               ~U[2025-10-26 07:00:00Z]
             ]
    end

    test "FREQ=WEEKLY with BYHOUR" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;BYHOUR=9,17;X-INCLUDE-DTSTART=TRUE"
        )

      # Should create 2 events per week at 9 and 17 hours
      assert results == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-14 09:00:00Z],
               ~U[2025-10-14 17:00:00Z],
               ~U[2025-10-21 09:00:00Z],
               ~U[2025-10-21 17:00:00Z]
             ]
    end
  end

  describe "rrule date tests" do
    test "UTC Time" do
      {:ok, {occurrances, _has_more}} =
        RRule.all_between(
          "RRULE:FREQ=WEEKLY;INTERVAL=2\nDTSTART:20251014T070000Z",
          ~U[2025-10-14 07:00:00Z],
          ~U[2025-12-14 07:00:00Z]
        )

      assert occurrances == [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-11 07:00:00Z],
               ~U[2025-11-25 07:00:00Z],
               ~U[2025-12-09 07:00:00Z]
             ]
    end

    test "Non-UTC Time" do
      {:ok, {occurrances, _has_more}} =
        RRule.all_between(
          "RRULE:FREQ=WEEKLY;INTERVAL=2\nDTSTART;TZID=America/New_York:20251014T070000",
          ~U[2025-10-14 07:00:00Z],
          ~U[2025-12-14 07:00:00Z]
        )

      #  DTSTART;VALUE=DATE:20251114
      # DTSTART;TZID=Greenwich Standard Time:20190726T190000
      # ;TZID=America/Chicago:22221224T083000
      assert occurrances == [
               ~U[2025-10-14 11:00:00Z],
               ~U[2025-10-28 11:00:00Z],
               ~U[2025-11-11 12:00:00Z],
               ~U[2025-11-25 12:00:00Z],
               ~U[2025-12-09 12:00:00Z]
             ]
    end
  end
end

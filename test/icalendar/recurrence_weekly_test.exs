defmodule ICalendar.RecurrenceWeeklyTest do
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
        |> Enum.take(5)
        |> Enum.map(fn r -> r.dtstart end)

      [event.dtstart | recurrances]
    end)
  end

  describe "FREQ=WEEKLY - Basic" do
    @tag :skip
    test "FREQ=WEEKLY" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z], # Tuesday
          "FREQ=WEEKLY"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z],
               ~U[2025-11-11 07:00:00Z],
               ~U[2025-11-18 07:00:00Z]
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
    @tag :skip
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
               ~U[2025-12-09 07:00:00Z],
               ~U[2025-12-23 07:00:00Z]
             ] = results
    end

    @tag :skip
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

  describe "FREQ=WEEKLY - With BYDAY (currently not fully supported)" do
    @tag :skip
    test "FREQ=WEEKLY;BYDAY=MO,WE,FR" do
      results =
        create_ical_event(
          ~U[2025-10-13 07:00:00Z], # Monday
          "FREQ=WEEKLY;BYDAY=MO,WE,FR"
        )

      assert [
               ~U[2025-10-13 07:00:00Z], # Monday
               ~U[2025-10-15 07:00:00Z], # Wednesday
               ~U[2025-10-17 07:00:00Z], # Friday
               ~U[2025-10-20 07:00:00Z], # Next Monday
               ~U[2025-10-22 07:00:00Z], # Next Wednesday
               ~U[2025-10-24 07:00:00Z]  # Next Friday
             ] = results
    end

    @tag :skip
    test "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10" do
      results =
        create_ical_event(
          ~U[2025-10-13 07:00:00Z], # Monday
          "FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10"
        )

      # Should create exactly 10 occurrences across Mon/Wed/Fri
      assert length(results) == 10
      assert hd(results) == ~U[2025-10-13 07:00:00Z]
    end

    @tag :skip
    test "FREQ=WEEKLY;BYDAY=TU,TH;INTERVAL=2" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z], # Tuesday
          "FREQ=WEEKLY;BYDAY=TU,TH;INTERVAL=2"
        )

      assert [
               ~U[2025-10-14 07:00:00Z], # Tuesday week 1
               ~U[2025-10-16 07:00:00Z], # Thursday week 1
               ~U[2025-10-28 07:00:00Z], # Tuesday week 3 (skip week 2)
               ~U[2025-10-30 07:00:00Z], # Thursday week 3
               ~U[2025-11-11 07:00:00Z], # Tuesday week 5
               ~U[2025-11-13 07:00:00Z]  # Thursday week 5
             ] = results
    end
  end

  describe "FREQ=WEEKLY - With WKST (currently not supported)" do
    @tag :skip
    test "FREQ=WEEKLY;WKST=MO" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z], # Tuesday
          "FREQ=WEEKLY;WKST=MO"
        )

      # Week starts on Monday, so this should behave same as default
      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-10-21 07:00:00Z],
               ~U[2025-10-28 07:00:00Z],
               ~U[2025-11-04 07:00:00Z],
               ~U[2025-11-11 07:00:00Z],
               ~U[2025-11-18 07:00:00Z]
             ] = results
    end

    @tag :skip
    test "FREQ=WEEKLY;WKST=SU;BYDAY=SA,SU" do
      results =
        create_ical_event(
          ~U[2025-10-12 07:00:00Z], # Saturday
          "FREQ=WEEKLY;WKST=SU;BYDAY=SA,SU"
        )

      # Week starts on Sunday, recurring on Saturday and Sunday
      assert [
               ~U[2025-10-12 07:00:00Z], # Saturday
               ~U[2025-10-13 07:00:00Z], # Sunday
               ~U[2025-10-19 07:00:00Z], # Next Saturday
               ~U[2025-10-20 07:00:00Z], # Next Sunday
               ~U[2025-10-26 07:00:00Z], # Following Saturday
               ~U[2025-10-27 07:00:00Z]  # Following Sunday
             ] = results
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
          ~U[2025-10-12 07:00:00Z], # Sunday
          "FREQ=WEEKLY;COUNT=3"
        )

      assert [
               ~U[2025-10-12 07:00:00Z],
               ~U[2025-10-19 07:00:00Z],
               ~U[2025-10-26 07:00:00Z]
             ] = results_sun
    end

    @tag :skip
    test "FREQ=WEEKLY with BYHOUR (currently not supported)" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=WEEKLY;BYHOUR=9,17"
        )

      # Should create 2 events per week at 9 and 17 hours
      assert [
               ~U[2025-10-14 09:00:00Z],
               ~U[2025-10-14 17:00:00Z],
               ~U[2025-10-21 09:00:00Z],
               ~U[2025-10-21 17:00:00Z],
               ~U[2025-10-28 09:00:00Z],
               ~U[2025-10-28 17:00:00Z]
             ] = results
    end
  end
end

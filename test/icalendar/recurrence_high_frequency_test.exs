defmodule ICalendar.RecurrenceHighFrequencyTest do
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
        |> Enum.take(10)  # Take more for high frequency events
        |> Enum.map(fn r -> r.dtstart end)

      [event.dtstart | recurrances]
    end)
  end

  describe "FREQ=HOURLY (currently not supported)" do
    @tag :skip
    test "FREQ=HOURLY" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=HOURLY"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 10:00:00Z],
               ~U[2025-10-17 11:00:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 13:00:00Z],
               ~U[2025-10-17 14:00:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=HOURLY;COUNT=24" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=HOURLY;COUNT=24"
        )

      # Should create 24 hourly events
      assert length(results) == 24
      assert hd(results) == ~U[2025-10-17 00:00:00Z]
      assert List.last(results) == ~U[2025-10-17 23:00:00Z]
    end

    @tag :skip
    test "FREQ=HOURLY;INTERVAL=6" do
      results =
        create_ical_event(
          ~U[2025-10-17 06:00:00Z],
          "FREQ=HOURLY;INTERVAL=6"
        )

      assert [
               ~U[2025-10-17 06:00:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 18:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-18 06:00:00Z],
               ~U[2025-10-18 12:00:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=HOURLY;BYHOUR=9,12,15,18" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=HOURLY;BYHOUR=9,12,15,18"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 12:00:00Z],
               ~U[2025-10-17 15:00:00Z],
               ~U[2025-10-17 18:00:00Z],
               ~U[2025-10-18 09:00:00Z],
               ~U[2025-10-18 12:00:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=HOURLY;BYMINUTE=15,45" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:15:00Z],
          "FREQ=HOURLY;BYMINUTE=15,45"
        )

      assert [
               ~U[2025-10-17 09:15:00Z],
               ~U[2025-10-17 09:45:00Z],
               ~U[2025-10-17 10:15:00Z],
               ~U[2025-10-17 10:45:00Z],
               ~U[2025-10-17 11:15:00Z],
               ~U[2025-10-17 11:45:00Z]
             ] = Enum.take(results, 6)
    end
  end

  describe "FREQ=MINUTELY (currently not supported)" do
    @tag :skip
    test "FREQ=MINUTELY" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:01:00Z],
               ~U[2025-10-17 09:02:00Z],
               ~U[2025-10-17 09:03:00Z],
               ~U[2025-10-17 09:04:00Z],
               ~U[2025-10-17 09:05:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MINUTELY;COUNT=60" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY;COUNT=60"
        )

      # Should create 60 minutely events
      assert length(results) == 60
      assert hd(results) == ~U[2025-10-17 09:00:00Z]
      assert List.last(results) == ~U[2025-10-17 09:59:00Z]
    end

    @tag :skip
    test "FREQ=MINUTELY;INTERVAL=15" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY;INTERVAL=15"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:15:00Z],
               ~U[2025-10-17 09:30:00Z],
               ~U[2025-10-17 09:45:00Z],
               ~U[2025-10-17 10:00:00Z],
               ~U[2025-10-17 10:15:00Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MINUTELY;BYSECOND=0,30" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY;BYSECOND=0,30"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:00:30Z],
               ~U[2025-10-17 09:01:00Z],
               ~U[2025-10-17 09:01:30Z],
               ~U[2025-10-17 09:02:00Z],
               ~U[2025-10-17 09:02:30Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=MINUTELY;BYMINUTE=0,15,30,45" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY;BYMINUTE=0,15,30,45"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:15:00Z],
               ~U[2025-10-17 09:30:00Z],
               ~U[2025-10-17 09:45:00Z],
               ~U[2025-10-17 10:00:00Z],
               ~U[2025-10-17 10:15:00Z]
             ] = Enum.take(results, 6)
    end
  end

  describe "FREQ=SECONDLY (currently not supported)" do
    @tag :skip
    test "FREQ=SECONDLY" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=SECONDLY"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:00:01Z],
               ~U[2025-10-17 09:00:02Z],
               ~U[2025-10-17 09:00:03Z],
               ~U[2025-10-17 09:00:04Z],
               ~U[2025-10-17 09:00:05Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=SECONDLY;COUNT=60" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=SECONDLY;COUNT=60"
        )

      # Should create 60 events, one per second
      assert length(results) == 60
      assert hd(results) == ~U[2025-10-17 09:00:00Z]
      assert List.last(results) == ~U[2025-10-17 09:00:59Z]
    end

    @tag :skip
    test "FREQ=SECONDLY;INTERVAL=30" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=SECONDLY;INTERVAL=30"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:00:30Z],
               ~U[2025-10-17 09:01:00Z],
               ~U[2025-10-17 09:01:30Z],
               ~U[2025-10-17 09:02:00Z],
               ~U[2025-10-17 09:02:30Z]
             ] = Enum.take(results, 6)
    end

    @tag :skip
    test "FREQ=SECONDLY;BYSECOND=0,15,30,45" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=SECONDLY;BYSECOND=0,15,30,45"
        )

      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:00:15Z],
               ~U[2025-10-17 09:00:30Z],
               ~U[2025-10-17 09:00:45Z],
               ~U[2025-10-17 09:01:00Z],
               ~U[2025-10-17 09:01:15Z]
             ] = Enum.take(results, 6)
    end
  end

  describe "High frequency with complex BY* rules (currently not supported)" do
    @tag :skip
    test "FREQ=HOURLY;BYDAY=MO,TU,WE,TH,FR" do
      results =
        create_ical_event(
          ~U[2025-10-13 09:00:00Z], # Monday
          "FREQ=HOURLY;BYDAY=MO,TU,WE,TH,FR"
        )

      # Should only occur on weekdays, skipping weekends
      # This would generate many events per day during weekdays
      assert hd(results) == ~U[2025-10-13 09:00:00Z]
      # Verify it skips weekend hours
    end

    @tag :skip
    test "FREQ=MINUTELY;BYHOUR=9,17" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=MINUTELY;BYHOUR=9,17"
        )

      # Should only occur during 9 AM and 5 PM hours
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:01:00Z],
               ~U[2025-10-17 09:02:00Z]
             ] = Enum.take(results, 3)

      # After 9:59, should jump to 17:00
      later_results = Enum.drop(results, 60)
      assert hd(later_results) == ~U[2025-10-17 17:00:00Z]
    end

    @tag :skip
    test "FREQ=SECONDLY;BYMINUTE=0,30" do
      results =
        create_ical_event(
          ~U[2025-10-17 09:00:00Z],
          "FREQ=SECONDLY;BYMINUTE=0,30"
        )

      # Should only occur during the 0th and 30th minute of each hour
      assert [
               ~U[2025-10-17 09:00:00Z],
               ~U[2025-10-17 09:00:01Z],
               ~U[2025-10-17 09:00:02Z]
             ] = Enum.take(results, 3)

      # After 09:00:59, should jump to 09:30:00
      later_results = Enum.drop(results, 60)
      assert hd(later_results) == ~U[2025-10-17 09:30:00Z]
    end
  end
end

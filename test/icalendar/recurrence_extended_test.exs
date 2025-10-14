defmodule ICalendar.RecurrenceExtendedTest do
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
    SUMMARY:Film with Amy and Adam
    END:VEVENT
    END:VCALENDAR
    """
    |> ICalendar.from_ics()
    |> Enum.flat_map(fn event ->
      recurrances =
        ICalendar.Recurrence.get_recurrences(event)
        |> Enum.take(5)
        |> Enum.map(fn r -> r.dtstart end)

      # TODO: consider adding the original event to the list of recurrences
      [event.dtstart | recurrances]
    end)
  end

  describe "FREQ=DAILY" do
    test "FREQ=DAILY;UNTIL" do
      results =
        create_ical_event(
          ~U[2025-10-17 00:00:00Z],
          "FREQ=DAILY;UNTIL=20351231T083000Z"
        )

      assert [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z],
               ~U[2025-10-22 00:00:00Z]
             ] = results
    end

    test "FREQ=DAILY;COUNT" do
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
  end

  describe "FREQ=WEEKLY" do
    test "FREQ=WEEKLY;UNTIL" do
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



  describe "FREQ=MONTHLY" do
    test "FREQ=MONTHLY" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=MONTHLY;COUNT=5"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2025-11-14 07:00:00Z],
               ~U[2025-12-14 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-14 07:00:00Z]
             ] = results
    end

    test "FREQ=MONTHLY;BYDAY=2WE" do
      results =
        create_ical_event(
          ~U[2025-10-08 07:00:00Z],
          "FREQ=MONTHLY;BYDAY=2WE;COUNT=5"
        )

      assert [
               ~U[2025-10-08 07:00:00Z],
               ~U[2025-11-12 07:00:00Z],
               ~U[2025-12-10 07:00:00Z],
               ~U[2026-01-14 07:00:00Z],
               ~U[2026-02-11 07:00:00Z]
             ] = results
    end
  end

  describe "FREQ=YEARLY" do
    test "FREQ=YEARLY" do
      results =
        create_ical_event(
          ~U[2025-10-14 07:00:00Z],
          "FREQ=YEARLY;COUNT=5"
        )

      assert [
               ~U[2025-10-14 07:00:00Z],
               ~U[2026-10-14 07:00:00Z],
               ~U[2027-10-14 07:00:00Z],
               ~U[2028-10-14 07:00:00Z],
               ~U[2029-10-14 07:00:00Z]
             ] = results
    end
  end
end

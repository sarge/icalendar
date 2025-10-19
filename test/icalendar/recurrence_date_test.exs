defmodule ICalendar.RecurrenceDateTest do
  use ExUnit.Case

  # test verification via https://kewisch.github.io/ical.js/recur-tester.html
  def create_ical_event(%Date{} = dtstart, rrule, timezone \\ nil) do
    start = ICalendar.Value.to_ics(dtstart)

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
      # For infinite recurrence (no COUNT or UNTIL), provide an end date
      # that's far enough in the future to generate the expected test results
      end_date =
        if String.contains?(rrule, "COUNT") or String.contains?(rrule, "UNTIL") do
          DateTime.utc_now()
        else
          # For infinite recurrence, set end date 1 year from start
          to =
            DateTime.from_naive!(
              NaiveDateTime.new(dtstart, ~T[00:00:00]) |> elem(1),
              timezone || "Etc/UTC"
            )

          DateTime.add(to, 365, :day)
        end

      ICalendar.Recurrence.get_recurrences(event, end_date, timezone)
      |> Enum.take(5)
      |> Enum.map(fn r -> r.dtstart end)
    end)
  end

  describe "FREQ=DAILY - Basic" do
    test "FREQ=DAILY" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          "FREQ=DAILY"
        )

      assert results == [
               ~U[2025-10-17 00:00:00Z],
               ~U[2025-10-18 00:00:00Z],
               ~U[2025-10-19 00:00:00Z],
               ~U[2025-10-20 00:00:00Z],
               ~U[2025-10-21 00:00:00Z]
             ]
    end

    test "FREQ=DAILY in Pacific/Auckland" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          "FREQ=DAILY",
          "Pacific/Auckland"
        )

      assert results == [
               DateTime.from_naive!(~N[2025-10-17 00:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-18 00:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-19 00:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-20 00:00:00], "Pacific/Auckland"),
               DateTime.from_naive!(~N[2025-10-21 00:00:00], "Pacific/Auckland")
             ]
    end

    test "FREQ=DAILY;COUNT=5" do
      results =
        create_ical_event(
          ~D[2025-10-17],
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

    test "FREQ=DAILY;UNTIL=20251231" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          "FREQ=DAILY;UNTIL=20251231"
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
          ~D[2025-10-17],
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
          ~D[2025-10-17],
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

    test "FREQ=DAILY;INTERVAL=3;UNTIL=20251031" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          "FREQ=DAILY;INTERVAL=3;UNTIL=20251031"
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

  describe "FREQ=DAILY - Edge cases" do
    test "FREQ=DAILY;COUNT=1" do
      results =
        create_ical_event(
          ~D[2025-10-17],
          "FREQ=DAILY;COUNT=1"
        )

      assert [~U[2025-10-17 00:00:00Z]] = results
    end
  end
end

defmodule ICalendar.RecurrenceValidationTest do
  use ExUnit.Case
  alias ICalendar.Recurrence

  describe "Recurrence validation" do
    test "returns empty list when rrule_str is nil" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: nil
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-18 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      assert result == []
    end

    test "returns empty list when rrule_str does not contain RRULE or RDATE" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "INVALID_RULE:FREQ=DAILY"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-18 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      assert result == []
    end

    test "returns empty list when rrule_str contains only unrelated content" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "SUMMARY:Test Event\nDESCRIPTION:This is a test"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-18 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      assert result == []
    end

    test "processes recurrence when rrule_str contains RRULE with DTSTART" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "DTSTART:20251017T000000Z\nRRULE:FREQ=DAILY;COUNT=2"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-20 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      # Should return 2 occurrences since COUNT=2
      assert length(result) == 2
      assert Enum.at(result, 0).dtstart == ~U[2025-10-17 00:00:00Z]
      assert Enum.at(result, 1).dtstart == ~U[2025-10-18 00:00:00Z]
    end

    test "processes recurrence when rrule_str contains RDATE with DTSTART" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "DTSTART:20251017T000000Z\nRDATE:20251017T000000Z,20251018T000000Z"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-20 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      # Should return occurrences for the specified dates
      assert length(result) == 2
      assert Enum.at(result, 0).dtstart == ~U[2025-10-17 00:00:00Z]
      assert Enum.at(result, 1).dtstart == ~U[2025-10-18 00:00:00Z]
    end

    test "case insensitive validation - works with lowercase rrule" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "DTSTART:20251017T000000Z\nrrule:FREQ=DAILY;COUNT=1"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-20 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      # Should return 1 occurrence since COUNT=1
      assert length(result) == 1
      assert Enum.at(result, 0).dtstart == ~U[2025-10-17 00:00:00Z]
    end

    test "validation works with mixed case RRULE" do
      event = %ICalendar.Event{
        dtstart: ~U[2025-10-17 00:00:00Z],
        dtend: ~U[2025-10-17 01:00:00Z],
        rrule_str: "DTSTART:20251017T000000Z\nRrule:FREQ=DAILY;COUNT=1"
      }

      start_date = ~U[2025-10-17 00:00:00Z]
      end_date = ~U[2025-10-20 00:00:00Z]

      result = Recurrence.get_recurrences(event, start_date, end_date)

      # Should return 1 occurrence since COUNT=1
      assert length(result) == 1
      assert Enum.at(result, 0).dtstart == ~U[2025-10-17 00:00:00Z]
    end
  end
end

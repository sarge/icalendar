defmodule ICalendar.Recurrence do
  @moduledoc """
  Adds support for recurring events.

  Events can recur by frequency, count, interval, and/or start/end date. To
  see the specific rules and examples, see `add_recurring_events/2` below.

  Credit to @fazibear for this module.
  """

  alias ICalendar.Event

  # ignore :byhour, :bymonthday, :byyearday, :byweekno for now
  @supported_by_x_rrules [:byday, :bymonth]

  # Get the logical datetime for recurrence calculations.
  #
  # This function handles the case where X-WR-TIMEZONE was applied during parsing,
  # converting a date-only value from the intended timezone to UTC, which may have
  # changed the day of the week. For recurrence calculations, we need to work with
  # the original intended date.
  defp get_logical_datetime(event) do
    case event.x_wr_timezone do
      nil ->
        # No X-WR-TIMEZONE, use the datetime as-is
        event.dtstart

      timezone when is_binary(timezone) ->
        # Event has X-WR-TIMEZONE, check if this looks like a converted date-only value
        # Date-only values in X-WR-TIMEZONE get converted to UTC, potentially changing the day
        if is_likely_converted_date_only_value?(event.dtstart, timezone) do
          # For date-only values, we want to use the "logical" date for recurrence calculations
          # This means the date as it appears in the original timezone, but at midnight UTC
          original_datetime = Timex.to_datetime(event.dtstart, timezone)
          original_date = Timex.to_date(original_datetime)
          # Create the logical datetime: the same date at midnight UTC
          DateTime.from_naive!(Timex.to_naive_datetime(original_date), "Etc/UTC")
        else
          # Not a converted date-only value, use as-is
          event.dtstart
        end
    end
  end

  defp get_logical_datetime(event, :dtend) do
    case event.x_wr_timezone do
      nil ->
        event.dtend

      timezone when is_binary(timezone) ->
        if is_likely_converted_date_only_value?(event.dtend, timezone) do
          original_datetime = Timex.to_datetime(event.dtend, timezone)
          original_date = Timex.to_date(original_datetime)
          # Create the logical datetime: the same date at midnight UTC
          DateTime.from_naive!(Timex.to_naive_datetime(original_date), "Etc/UTC")
        else
          event.dtend
        end
    end
  end

  # Heuristic to detect if a datetime is likely the result of converting a date-only value
  # with X-WR-TIMEZONE. This is imperfect but should work for common cases.
  defp is_likely_converted_date_only_value?(datetime, timezone) do
    # Convert the UTC datetime to the original timezone and check if it's at midnight
    timezone_dt = Timex.to_datetime(datetime, timezone)
    timezone_dt.hour == 0 and timezone_dt.minute == 0 and timezone_dt.second == 0
  end

  @doc """
  Given an event, return a stream of recurrences for that event.

  Warning: this may create a very large sequence of event recurrences.

  ## Parameters

    - `event`: The event that may contain an rrule. See `ICalendar.Event`.

    - `end_date` *(optional)*: A date time that represents the fallback end date
      for a recurring event. This value is only used when the options specified
      in rrule result in an infinite recurrance (ie. when neither `count` nor
      `until` is set). If no end_date is set, it will default to
      `DateTime.utc_now()`.

  ## Event rrule options

    Event recurrance details are specified in the `rrule`. The following options
    are considered:

    - `freq`: Represents how frequently the event recurs. Allowed frequencies
      are `DAILY`, `WEEKLY`, and `MONTHLY`. These can be further modified by
      the `interval` option.

    - `count` *(optional)*: Represents the number of times that an event will
      recur. This takes precedence over the `end_date` parameter and the
      `until` option.

    - `interval` *(optional)*: Represents the interval at which events occur.
      This option works in concert with `freq` above; by using the `interval`
      option, an event could recur every 5 days or every 3 weeks.

    - `until` *(optional)*: Represents the end date for a recurring event.
      This takes precedence over the `end_date` parameter.

    - `byday` *(optional)*: Represents the days of the week at which events occur.
    - `bymonth` *(optional)*: Represents the months at which events occur.

    The `freq` option is required for a valid rrule, but the others are
    optional. They may be used either individually (ex. just `freq`) or in
    concert (ex. `freq` + `interval` + `until`).

  ## Future rrule options (not yet supported)

    - `byhour` *(optional)*: Represents the hours of the day at which events occur.
    - `byweekno` *(optional)*: Represents the week number at which events occur.
    - `bymonthday` *(optional)*: Represents the days of the month at which events occur.
    - `byyearday` *(optional)*: Represents the days of the year at which events occur.

  ## Examples

      iex> dt = Timex.Date.from({2016,8,13})
      iex> dt_end = Timex.Date.from({2016, 8, 23})
      iex> event = %ICalendar.Event{rrule:%{freq: "DAILY"}, dtstart: dt, dtend: dt}
      iex> recurrences =
            ICalendar.Recurrence.get_recurrences(event)
            |> Enum.to_list()

  """
  @spec get_recurrences(%Event{}) :: %Stream{}
  @spec get_recurrences(%Event{}, %DateTime{}) :: %Stream{}
  def get_recurrences(event, end_date \\ DateTime.utc_now()) do
    by_x_rrules =
      if is_map(event.rrule), do: Map.take(event.rrule, @supported_by_x_rrules), else: %{}

    reference_events =
      if by_x_rrules != %{} do
        # If there are any by_x modifiers in the rrule, build reference events based on them
        # Remove the invalid reference events later on
        build_refernce_events_by_x_rules(event, by_x_rrules)
      else
        [event]
      end

    case event.rrule do
      nil ->
        Stream.map([nil], fn _ -> [] end)

      %{freq: "DAILY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, days: interval)

      %{freq: "DAILY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, days: interval)

      %{freq: "DAILY", count: count} ->
        add_recurring_events_count(event, reference_events, count, days: 1)

      %{freq: "DAILY", until: until} ->
        add_recurring_events_until(event, reference_events, until, days: 1)

      %{freq: "DAILY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, days: interval)

      %{freq: "DAILY"} ->
        add_recurring_events_until(event, reference_events, end_date, days: 1)

      %{freq: "WEEKLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, days: interval * 7)

      %{freq: "WEEKLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, days: 7)

      %{freq: "WEEKLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, days: 7)

      %{freq: "WEEKLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, days: interval * 7)

      %{freq: "WEEKLY"} ->
        add_recurring_events_until(event, reference_events, end_date, days: 7)

      %{freq: "MONTHLY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, months: interval)

      %{freq: "MONTHLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, months: interval)

      %{freq: "MONTHLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, months: 1)

      %{freq: "MONTHLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, months: 1)

      %{freq: "MONTHLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, months: interval)

      %{freq: "MONTHLY"} ->
        add_recurring_events_until(event, reference_events, end_date, months: 1)

      %{freq: "YEARLY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, years: interval)

      %{freq: "YEARLY", until: until, interval: interval} ->
        add_recurring_events_until(event, reference_events, until, years: interval)

      %{freq: "YEARLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, years: 1)

      %{freq: "YEARLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, years: 1)

      %{freq: "YEARLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, years: interval)

      %{freq: "YEARLY"} ->
        add_recurring_events_until(event, reference_events, end_date, years: 1)
    end
  end

  defp add_recurring_events_until(original_event, reference_events, until, shift_opts) do
    # Check if we have reference events that represent additional occurrences in the same period
    # (e.g., BYMONTH creating events in the same year, or BYDAY creating events in the same week)
    additional_reference_events =
      Enum.filter(reference_events, fn ref_event ->
        # Include reference events that are after the original event and before/at the until date
        DateTime.compare(ref_event.dtstart, original_event.dtstart) == :gt and
        Timex.compare(ref_event.dtstart, until) != 1
      end)

    Stream.resource(
      fn ->
        if additional_reference_events != [] do
          [:emit_references, reference_events]
        else
          [reference_events]
        end
      end,
      fn acc_events ->
        case acc_events do
          [:emit_references | [prev_event_batch]] ->
            # First emit the additional reference events, then set up for regular recurrences
            {remove_excluded_dates(additional_reference_events, original_event), [prev_event_batch]}

          [prev_event_batch | _] when prev_event_batch == [] ->
            {:halt, acc_events}

          [prev_event_batch | _] ->
            new_events =
              Enum.map(prev_event_batch, fn reference_event ->
                new_event = shift_event(reference_event, shift_opts)

                case Timex.compare(new_event.dtstart, until) do
                  1 -> []
                  _ -> [new_event]
                end
              end)
              |> List.flatten()

            {remove_excluded_dates(new_events, original_event), [new_events | acc_events]}
        end
      end,
      fn recurrences ->
        recurrences
      end
    )
  end

  defp add_recurring_events_count(original_event, reference_events, count, shift_opts) do
    Stream.resource(
      fn -> {[reference_events], count} end,
      fn {acc_events, count} ->
        # Use the previous batch of the events as the reference for the next batch
        [prev_event_batch | _] = acc_events

        case prev_event_batch do
          [] ->
            {:halt, acc_events}

          prev_event_batch ->
            new_events =
              Enum.map(prev_event_batch, fn reference_event ->
                new_event = shift_event(reference_event, shift_opts)

                if count > 1 do
                  [new_event]
                else
                  []
                end
              end)
              |> List.flatten()

            {remove_excluded_dates(new_events, original_event),
             {[new_events | acc_events], count - 1}}
        end
      end,
      fn recurrences ->
        recurrences
      end
    )
  end

  defp shift_event(event, shift_opts) do
    Map.merge(event, %{
      dtstart: shift_date(event.dtstart, shift_opts),
      dtend: shift_date(event.dtend, shift_opts),
      rrule: Map.put(event.rrule, :is_recurrence, true)
    })
  end

  defp shift_date(date, shift_opts) do
    result =
      case Timex.shift(date, shift_opts) do
        %Timex.AmbiguousDateTime{} = new_date ->
          new_date.after

        new_date ->
          new_date
      end

    # Truncate microseconds to match expected format
    DateTime.truncate(result, :second)
  end

  defp build_refernce_events_by_x_rules(event, by_x_rrules) do
    by_x_rrules
    |> Map.keys()
    |> Enum.map(fn by_x ->
      build_refernce_events_by_x_rule(event, by_x)
    end)
    |> List.flatten()
  end

  @valid_days ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
  @day_values %{su: 0, mo: 1, tu: 2, we: 3, th: 4, fr: 5, sa: 6}

  defp build_refernce_events_by_x_rule(
         %{rrule: %{bymonth: bymonths}} = event,
         :bymonth
       ) do
    logical_dtstart = get_logical_datetime(event)
    logical_dtend = get_logical_datetime(event, :dtend)

    # For BYMONTH, create reference events for all specified months
    # Include the original event if its month is in the bymonths list
    reference_events = bymonths
    |> Enum.map(fn bymonth ->
      month = String.to_integer(bymonth)

      if month >= 1 and month <= 12 do
        # For BYMONTH, we create events for each specified month in the original year
        year = logical_dtstart.year

        # Create new datetime with the target month, keeping the same day and time
        {:ok, reference_dtstart} = DateTime.new(
          Date.new!(year, month, logical_dtstart.day),
          Time.new!(logical_dtstart.hour, logical_dtstart.minute, logical_dtstart.second),
          logical_dtstart.time_zone
        )

        {:ok, reference_dtend} = DateTime.new(
          Date.new!(year, month, logical_dtend.day),
          Time.new!(logical_dtend.hour, logical_dtend.minute, logical_dtend.second),
          logical_dtend.time_zone
        )

        # Handle X-WR-TIMEZONE conversion pattern similar to byday
        {final_dtstart, final_dtend} =
          case event.x_wr_timezone do
            nil ->
              {reference_dtstart, reference_dtend}

            timezone when is_binary(timezone) ->
              if is_likely_converted_date_only_value?(event.dtstart, timezone) do
                # For date-only conversions, we need to maintain the conversion pattern
                original_date_start = Date.new!(year, month, logical_dtstart.day)
                original_date_end = Date.new!(year, month, logical_dtend.day)

                original_dt_start = DateTime.from_naive!(Timex.to_naive_datetime(original_date_start), timezone)
                original_dt_end = DateTime.from_naive!(Timex.to_naive_datetime(original_date_end), timezone)

                {DateTime.shift_zone!(original_dt_start, "Etc/UTC"),
                 DateTime.shift_zone!(original_dt_end, "Etc/UTC")}
              else
                {reference_dtstart, reference_dtend}
              end
          end

        Map.merge(event, %{
          dtstart: DateTime.truncate(final_dtstart, :second),
          dtend: DateTime.truncate(final_dtend, :second)
        })
      else
        # Ignore invalid month values
        nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))

    # Sort by date and only return events that are > the original event date
    # This excludes the original event itself from the reference events
    filtered_events = reference_events
    |> Enum.filter(fn ref_event ->
      DateTime.compare(ref_event.dtstart, logical_dtstart) == :gt
    end)
    |> Enum.sort_by(& &1.dtstart, DateTime)

    # If no additional reference events (all months are <= current month),
    # return the original event as the only reference
    if filtered_events == [] do
      [event]
    else
      filtered_events
    end
  end

  defp build_refernce_events_by_x_rule(
         %{rrule: %{byday: bydays}} = event,
         :byday
       ) do
    # Use logical datetime for weekday calculations to handle X-WR-TIMEZONE correctly
    logical_dtstart = get_logical_datetime(event)
    logical_dtend = get_logical_datetime(event, :dtend)

    bydays
    |> Enum.map(fn byday ->
      if byday in @valid_days do
        day_atom = byday |> String.downcase() |> String.to_atom()

        # determine the difference between the byday and the logical dtstart
        day_offset_for_reference = Map.get(@day_values, day_atom) - Timex.weekday(logical_dtstart)

        # For X-WR-TIMEZONE date-only conversions, we should use the original event's
        # datetime and shift by days, preserving the timezone conversion pattern
        {reference_dtstart, reference_dtend} =
          case event.x_wr_timezone do
            nil ->
              # No X-WR-TIMEZONE, shift the logical datetime (which is the same as original)
              shifted_logical_dtstart =
                Timex.shift(logical_dtstart, days: day_offset_for_reference)

              shifted_logical_dtend = Timex.shift(logical_dtend, days: day_offset_for_reference)
              {shifted_logical_dtstart, shifted_logical_dtend}

            timezone when is_binary(timezone) ->
              # Has X-WR-TIMEZONE, check if this is a date-only conversion case
              if is_likely_converted_date_only_value?(event.dtstart, timezone) do
                # For date-only conversions, shift the original converted datetime by days
                # This preserves the timezone conversion pattern (e.g., Auckland midnight → UTC time)
                reference_dtstart = Timex.shift(event.dtstart, days: day_offset_for_reference)
                reference_dtend = Timex.shift(event.dtend, days: day_offset_for_reference)
                {reference_dtstart, reference_dtend}
              else
                # Not a date-only conversion, use logical datetime shift
                shifted_logical_dtstart =
                  Timex.shift(logical_dtstart, days: day_offset_for_reference)

                shifted_logical_dtend = Timex.shift(logical_dtend, days: day_offset_for_reference)
                {shifted_logical_dtstart, shifted_logical_dtend}
              end
          end

        Map.merge(event, %{
          dtstart: DateTime.truncate(reference_dtstart, :second),
          dtend: DateTime.truncate(reference_dtend, :second)
        })
      else
        # Ignore the invalid byday value
        nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp build_refernce_events_by_x_rule(event, _unsupported_by_x) do
    # Return original event for unsupported by_x rules
    [event]
  end

  defp remove_excluded_dates(recurrences, original_event) do
    Enum.filter(recurrences, fn new_event ->
      # Make sure new event doesn't fall on an EXDATE
      falls_on_exdate = not is_nil(new_event) and new_event.dtstart in new_event.exdates

      #  This removes any events which were created as references
      is_invalid_reference_event =
        DateTime.compare(new_event.dtstart, original_event.dtstart) == :lt

      !falls_on_exdate &&
        !is_invalid_reference_event
    end)
  end
end

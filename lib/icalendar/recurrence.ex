defmodule ICalendar.Recurrence do
  @moduledoc """
  Adds support for recurring events.

  Events can recur by frequency, count, interval, and/or start/end date. To
  see the specific rules and examples, see `add_recurring_events/2` below.

  Credit to @fazibear for this module.
  """

  alias ICalendar.Event

  # ignore :byhour, :bymonthday, :byyearday, :byweekno for now
  @supported_by_x_rrules [:byday, :bymonth, :bysetpos, :byhour]

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
    reference_events = get_reference_events(event)

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

      %{freq: "WEEKLY", count: count, interval: interval} ->
        add_recurring_events_count(event, reference_events, count, days: interval * 7)

      %{freq: "WEEKLY", count: count} ->
        add_recurring_events_count(event, reference_events, count, days: 7)

      %{freq: "WEEKLY", until: until} ->
        add_recurring_events_until(event, reference_events, until, days: 7)

      %{freq: "WEEKLY", interval: interval} ->
        add_recurring_events_until(event, reference_events, end_date, days: interval * 7)

      %{freq: "WEEKLY"} ->
        add_recurring_events_until(event, reference_events, end_date, days: 7)

      %{freq: "MONTHLY", count: count, interval: interval} ->
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_count(event, count, interval)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_count(event, count, interval)

          true ->
            add_recurring_events_count(event, reference_events, count, months: interval)
        end

      %{freq: "MONTHLY", until: until, interval: interval} ->
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_until(event, until, interval)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_until(event, until, interval)

          true ->
            add_recurring_events_until(event, reference_events, until, months: interval)
        end

      %{freq: "MONTHLY", count: count} ->
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_count(event, count, 1)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_count(event, count, 1)

          true ->
            add_recurring_events_count(event, reference_events, count, months: 1)
        end

      %{freq: "MONTHLY", until: until} ->
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_until(event, until, 1)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_until(event, until, 1)

          true ->
            add_recurring_events_until(event, reference_events, until, months: 1)
        end

      %{freq: "MONTHLY", interval: interval} ->
        # Check if this is a BYDAY rule that requires special handling
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_until(event, end_date, interval)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_until(event, end_date, interval)

          true ->
            add_recurring_events_until(event, reference_events, end_date, months: interval)
        end

      %{freq: "MONTHLY"} ->
        # Check if this is a BYDAY rule that requires special handling
        cond do
          has_nth_weekday_byday_rule?(event) ->
            add_monthly_nth_weekday_recurring_events_until(event, end_date, 1)

          has_bysetpos_with_simple_byday_rule?(event) ->
            add_monthly_bysetpos_recurring_events_until(event, end_date, 1)

          true ->
            add_recurring_events_until(event, reference_events, end_date, months: 1)
        end

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

      %{freq: "HOURLY", count: count, interval: interval} ->
        shift_opts =
          if Map.has_key?(event.rrule, :byhour),
            do: [days: interval],
            else: [hours: interval]

        add_recurring_events_count(event, reference_events, count, shift_opts)

      %{freq: "HOURLY", until: until, interval: interval} ->
        shift_opts =
          if Map.has_key?(event.rrule, :byhour),
            do: [days: interval],
            else: [hours: interval]

        add_recurring_events_until(event, reference_events, until, shift_opts)

      %{freq: "HOURLY", count: count} ->
        shift_opts = if Map.has_key?(event.rrule, :byhour), do: [days: 1], else: [hours: 1]
        add_recurring_events_count(event, reference_events, count, shift_opts)

      %{freq: "HOURLY", until: until} ->
        shift_opts = if Map.has_key?(event.rrule, :byhour), do: [days: 1], else: [hours: 1]
        add_recurring_events_until(event, reference_events, until, shift_opts)

      %{freq: "HOURLY", interval: interval} ->
        shift_opts =
          if Map.has_key?(event.rrule, :byhour),
            do: [days: interval],
            else: [hours: interval]

        add_recurring_events_until(event, reference_events, end_date, shift_opts)

      %{freq: "HOURLY"} ->
        shift_opts = if Map.has_key?(event.rrule, :byhour), do: [days: 1], else: [hours: 1]
        add_recurring_events_until(event, reference_events, end_date, shift_opts)
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
            {remove_excluded_dates(additional_reference_events, original_event),
             [prev_event_batch]}

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

  @valid_days ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
  @weekday_to_number %{
    "SU" => 7,
    "MO" => 1,
    "TU" => 2,
    "WE" => 3,
    "TH" => 4,
    "FR" => 5,
    "SA" => 6
  }

  # Calculate day offset with WKST (Week Start) support
  # WKST changes the start of the week, affecting how we calculate relative day positions
  defp calculate_day_offset_with_wkst(target_day, current_date, wkst) do
    current_weekday = Date.day_of_week(current_date)
    target_weekday = Map.get(@weekday_to_number, target_day)
    wkst_weekday = Map.get(@weekday_to_number, wkst)

    # Convert to 0-6 range where week starts at wkst
    current_day_in_week = rem(current_weekday - wkst_weekday + 7, 7)
    target_day_in_week = rem(target_weekday - wkst_weekday + 7, 7)

    # Calculate offset within the current week
    offset = target_day_in_week - current_day_in_week

    offset
  end

  defp build_refernce_events_by_x_rule(
         %{rrule: %{bymonth: bymonths}} = event,
         :bymonth
       ) do
    logical_dtstart = get_logical_datetime(event)
    logical_dtend = get_logical_datetime(event, :dtend)

    # For BYMONTH, create reference events for all specified months
    # Include the original event if its month is in the bymonths list
    reference_events =
      bymonths
      |> Enum.map(fn bymonth ->
        month = String.to_integer(bymonth)

        if month >= 1 and month <= 12 do
          # For BYMONTH, we create events for each specified month in the original year
          year = logical_dtstart.year

          # Create new datetime with the target month, keeping the same day and time
          {:ok, reference_dtstart} =
            DateTime.new(
              Date.new!(year, month, logical_dtstart.day),
              Time.new!(logical_dtstart.hour, logical_dtstart.minute, logical_dtstart.second),
              logical_dtstart.time_zone
            )

          {:ok, reference_dtend} =
            DateTime.new(
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

                  original_dt_start =
                    DateTime.from_naive!(Timex.to_naive_datetime(original_date_start), timezone)

                  original_dt_end =
                    DateTime.from_naive!(Timex.to_naive_datetime(original_date_end), timezone)

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
    filtered_events =
      reference_events
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
      cond do
        # Handle simple weekday names like "TH", "FR", etc.
        byday in @valid_days ->
          build_simple_weekday_reference_event(event, byday, logical_dtstart, logical_dtend)

        # Handle nth weekday patterns like "3TH", "-1FR", etc.
        String.match?(byday, ~r/^-?\d+[A-Z]{2}$/) ->
          build_nth_weekday_reference_event(event, byday, logical_dtstart, logical_dtend)

        true ->
          # Ignore invalid byday values
          nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp build_refernce_events_by_x_rule(event, _unsupported_by_x) do
    # Return original event for unsupported by_x rules
    [event]
  end

  defp build_simple_weekday_reference_event(event, byday, logical_dtstart, logical_dtend) do
    # Get WKST (Week Start) from rrule, default to Monday
    wkst = Map.get(event.rrule, :wkst, "MO")

    # Calculate day offset considering WKST
    current_date = DateTime.to_date(logical_dtstart)
    base_offset = calculate_day_offset_with_wkst(byday, current_date, wkst)

    # Special handling for FREQ=WEEKLY with explicit WKST and multiple BYDAY values:
    # When we have multiple days and one matches the current day, we need to ensure
    # we generate a reference event that will create proper recurrence cycles
    day_offset_for_reference =
      case event.rrule do
        %{freq: "WEEKLY", wkst: wkst_val, byday: byday_list}
        when wkst_val != "MO" and length(byday_list) > 1 and base_offset == 0 ->
          # Next week's occurrence for WKST cases with multiple BYDAY
          7

        _ ->
          base_offset
      end

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
  end

  defp build_nth_weekday_reference_event(event, byday, logical_dtstart, logical_dtend) do
    # Parse patterns like "3TH", "-1FR", "2MO", etc.
    {nth, weekday} = parse_nth_weekday(byday)

    case event.rrule.freq do
      "MONTHLY" ->
        build_monthly_nth_weekday_reference_event(
          event,
          nth,
          weekday,
          logical_dtstart,
          logical_dtend
        )

      "YEARLY" ->
        build_yearly_nth_weekday_reference_event(
          event,
          nth,
          weekday,
          logical_dtstart,
          logical_dtend
        )

      _ ->
        # For other frequencies, ignore nth weekday patterns for now
        nil
    end
  end

  defp parse_nth_weekday(byday) do
    # Extract the number and weekday from patterns like "3TH", "-1FR"
    case Regex.run(~r/^(-?\d+)([A-Z]{2})$/, byday) do
      [_, nth_str, weekday] ->
        {String.to_integer(nth_str), weekday}

      _ ->
        {nil, nil}
    end
  end

  defp build_monthly_nth_weekday_reference_event(
         event,
         nth,
         weekday,
         logical_dtstart,
         logical_dtend
       ) do
    # For monthly recurrence with nth weekday (like "3TH" = 3rd Thursday of each month)
    # We need to find the nth occurrence of the weekday in the same month as the event

    # Get the base month and year from the logical start date
    base_date = DateTime.to_date(logical_dtstart)
    month_start = Date.beginning_of_month(base_date)

    target_date = find_nth_weekday_in_month(month_start, nth, weekday)

    case target_date do
      nil ->
        # No such weekday occurrence in this month
        nil

      date ->
        # Create new datetime with the target date, preserving time
        reference_dtstart = create_reference_datetime_for_date(date, logical_dtstart, event)

        # For dtend, use the same date plus the duration from the original event
        duration = DateTime.diff(logical_dtend, logical_dtstart, :second)
        reference_dtend = DateTime.add(reference_dtstart, duration, :second)

        Map.merge(event, %{
          dtstart: DateTime.truncate(reference_dtstart, :second),
          dtend: DateTime.truncate(reference_dtend, :second)
        })
    end
  end

  defp build_yearly_nth_weekday_reference_event(
         _event,
         _nth,
         _weekday,
         _logical_dtstart,
         _logical_dtend
       ) do
    # TODO: Implement yearly nth weekday logic if needed
    nil
  end

  defp find_nth_weekday_in_month(month_start, nth, weekday) do
    weekday_num = Map.get(@weekday_to_number, weekday)

    if is_nil(weekday_num) do
      nil
    else
      cond do
        nth > 0 ->
          # Find the nth occurrence from the beginning of the month
          find_nth_weekday_from_start(month_start, nth, weekday_num)

        nth < 0 ->
          # Find the nth occurrence from the end of the month
          find_nth_weekday_from_end(month_start, -nth, weekday_num)

        true ->
          nil
      end
    end
  end

  defp find_nth_weekday_from_start(month_start, nth, target_weekday) do
    days_in_month = Date.days_in_month(month_start)

    occurrences =
      1..days_in_month
      |> Enum.map(&Date.add(month_start, &1 - 1))
      |> Enum.filter(fn date ->
        # Sunday = 7, Monday = 1, ..., Saturday = 6
        weekday = Date.day_of_week(date)
        weekday == target_weekday
      end)

    # nth occurrence (1-indexed)
    Enum.at(occurrences, nth - 1)
  end

  defp find_nth_weekday_from_end(month_start, nth, target_weekday) do
    days_in_month = Date.days_in_month(month_start)

    occurrences =
      1..days_in_month
      |> Enum.map(&Date.add(month_start, &1 - 1))
      |> Enum.filter(fn date ->
        weekday = Date.day_of_week(date)
        weekday == target_weekday
      end)
      |> Enum.reverse()

    # nth occurrence from end (1-indexed)
    Enum.at(occurrences, nth - 1)
  end

  defp create_reference_datetime_for_date(target_date, reference_datetime, event) do
    # Create a new datetime using the target date and the time from reference_datetime
    case event.x_wr_timezone do
      nil ->
        # No X-WR-TIMEZONE, use the reference datetime's time
        {:ok, new_datetime} =
          DateTime.new(
            target_date,
            DateTime.to_time(reference_datetime),
            reference_datetime.time_zone
          )

        new_datetime

      timezone when is_binary(timezone) ->
        # Has X-WR-TIMEZONE, check if this is a date-only conversion case
        if is_likely_converted_date_only_value?(event.dtstart, timezone) do
          # For date-only conversions, create datetime in original timezone then convert to UTC
          naive_datetime = NaiveDateTime.new!(target_date, ~T[00:00:00])
          original_datetime = DateTime.from_naive!(naive_datetime, timezone)
          DateTime.shift_zone!(original_datetime, "Etc/UTC")
        else
          # Not a date-only conversion, use reference datetime's time
          {:ok, new_datetime} =
            DateTime.new(
              target_date,
              DateTime.to_time(reference_datetime),
              reference_datetime.time_zone
            )

          new_datetime
        end
    end
  end

  defp has_nth_weekday_byday_rule?(event) do
    case event.rrule do
      %{byday: bydays} when is_list(bydays) ->
        Enum.any?(bydays, &String.match?(&1, ~r/^-?\d+[A-Z]{2}$/))

      _ ->
        false
    end
  end

  # Check if this event has BYSETPOS with simple BYDAY rules (e.g., BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1)
  defp has_bysetpos_with_simple_byday_rule?(event) do
    case event.rrule do
      %{byday: bydays, bysetpos: bysetpos} when is_list(bydays) and is_list(bysetpos) ->
        # Has both BYDAY and BYSETPOS, and BYDAY contains only simple weekday names (no nth patterns)
        Enum.all?(bydays, fn byday ->
          byday in @valid_days
        end)

      _ ->
        false
    end
  end

  defp add_monthly_nth_weekday_recurring_events_count(original_event, count, interval) do
    # For COUNT-based recurrence, we generate exactly count-1 recurrences
    # (because the original event counts as the first occurrence)
    add_monthly_nth_weekday_recurring_events_until(original_event, nil, interval)
    |> Stream.take(count - 1)
  end

  defp add_monthly_nth_weekday_recurring_events_until(original_event, until, interval) do
    # Extract the nth weekday pattern from the BYDAY rule
    {nth, weekday} =
      case original_event.rrule.byday do
        [byday | _] when is_binary(byday) ->
          parse_nth_weekday(byday)

        _ ->
          {nil, nil}
      end

    if nth && weekday do
      logical_dtstart = get_logical_datetime(original_event)
      logical_dtend = get_logical_datetime(original_event, :dtend)

      Stream.resource(
        fn -> DateTime.to_date(logical_dtstart) end,
        fn current_date ->
          # Find the nth weekday of the current month
          month_start = Date.beginning_of_month(current_date)
          target_date = find_nth_weekday_in_month(month_start, nth, weekday)

          case target_date do
            nil ->
              # Skip this month if the nth weekday doesn't exist
              next_month =
                Date.add(Date.beginning_of_month(current_date), Date.days_in_month(current_date))

              {[], next_month}

            date ->
              # Create the event for this month
              reference_dtstart =
                create_reference_datetime_for_date(date, logical_dtstart, original_event)

              # For dtend, calculate based on the original duration
              duration = DateTime.diff(logical_dtend, logical_dtstart, :second)
              reference_dtend = DateTime.add(reference_dtstart, duration, :second)

              # Check if this event is within our time bounds
              if is_nil(until) or DateTime.compare(reference_dtstart, until) != :gt do
                new_event =
                  Map.merge(original_event, %{
                    dtstart: DateTime.truncate(reference_dtstart, :second),
                    dtend: DateTime.truncate(reference_dtend, :second),
                    rrule: Map.put(original_event.rrule, :is_recurrence, true)
                  })

                # Move to next month according to interval
                next_month =
                  month_start
                  |> Date.add(Date.days_in_month(month_start) * interval)
                  |> Date.beginning_of_month()

                {[new_event], next_month}
              else
                {:halt, current_date}
              end
          end
        end,
        fn _ -> nil end
      )
      |> Stream.filter(fn event ->
        # Remove events that fall on EXDATE or are before the original event
        !is_nil(event) and
          !(event.dtstart in event.exdates) and
          DateTime.compare(event.dtstart, original_event.dtstart) == :gt
      end)
    else
      # Fallback to regular recurrence if we can't parse the BYDAY rule
      Stream.map([], fn x -> x end)
    end
  end

  # Handle monthly recurrence with BYSETPOS and simple BYDAY rules
  defp add_monthly_bysetpos_recurring_events_count(original_event, count, interval) do
    # For COUNT-based recurrence, we generate exactly count-1 recurrences
    # (because the original event counts as the first occurrence)
    add_monthly_bysetpos_recurring_events_until(original_event, nil, interval)
    |> Stream.take(count - 1)
  end

  defp add_monthly_bysetpos_recurring_events_until(original_event, until, interval) do
    logical_dtstart = get_logical_datetime(original_event)
    logical_dtend = get_logical_datetime(original_event, :dtend)

    # Get the BYDAY and BYSETPOS rules
    byday_list = original_event.rrule.byday
    bysetpos_list = original_event.rrule.bysetpos

    Stream.resource(
      fn ->
        # Start from the month after the original event
        start_date = Date.beginning_of_month(logical_dtstart)
        next_month_start = Date.add(start_date, Date.days_in_month(start_date) * interval)
        next_month_start
      end,
      fn month_start ->
        until_date = if until, do: DateTime.to_date(until), else: nil

        if is_nil(until_date) or Date.compare(month_start, until_date) != :gt do
          # Generate all weekday candidates for this month
          month_candidates =
            generate_monthly_weekday_candidates(
              original_event,
              month_start,
              byday_list,
              logical_dtstart,
              logical_dtend
            )

          # Apply BYSETPOS filtering to select specific positions
          selected_events = apply_monthly_bysetpos_filter(month_candidates, bysetpos_list)

          # Filter by until date if specified
          filtered_events =
            if until do
              Enum.filter(selected_events, fn event ->
                DateTime.compare(event.dtstart, until) != :gt
              end)
            else
              selected_events
            end

          # Move to next month
          next_month_start = Date.add(month_start, Date.days_in_month(month_start) * interval)

          {filtered_events, next_month_start}
        else
          {:halt, month_start}
        end
      end,
      fn _ -> :ok end
    )
  end

  # Generate all weekday candidates for a given month based on BYDAY rules
  defp generate_monthly_weekday_candidates(
         original_event,
         month_start,
         byday_list,
         logical_dtstart,
         logical_dtend
       ) do
    duration = DateTime.diff(logical_dtend, logical_dtstart, :second)

    byday_list
    |> Enum.flat_map(fn weekday ->
      # Find all occurrences of this weekday in the month
      find_weekdays_in_month(month_start, weekday)
    end)
    # Sort the dates
    |> Enum.sort()
    |> Enum.map(fn date ->
      # Create event for this date
      reference_dtstart =
        create_reference_datetime_for_date(date, logical_dtstart, original_event)

      reference_dtend = DateTime.add(reference_dtstart, duration, :second)

      Map.merge(original_event, %{
        dtstart: DateTime.truncate(reference_dtstart, :second),
        dtend: DateTime.truncate(reference_dtend, :second),
        rrule: Map.put(original_event.rrule, :is_recurrence, true)
      })
    end)
  end

  # Find all dates in a month that fall on the specified weekday
  defp find_weekdays_in_month(month_start, weekday) do
    weekday_number = Map.get(@weekday_to_number, weekday)

    if weekday_number do
      month_end = Date.end_of_month(month_start)

      # Find the first occurrence of this weekday in the month
      first_occurrence = find_first_weekday_in_month(month_start, weekday_number)

      # Generate all occurrences by adding 7 days each time
      Stream.iterate(first_occurrence, &Date.add(&1, 7))
      |> Stream.take_while(&(Date.compare(&1, month_end) != :gt))
      |> Enum.to_list()
    else
      []
    end
  end

  # Find the first occurrence of a weekday (1=Monday, 7=Sunday) in a month
  defp find_first_weekday_in_month(month_start, target_weekday) do
    current_weekday = Date.day_of_week(month_start)

    # Calculate days to add to get to the target weekday
    # Convert Sunday from 7 to 0 for easier calculation
    target = if target_weekday == 7, do: 0, else: target_weekday
    current = if current_weekday == 7, do: 0, else: current_weekday

    days_to_add = rem(target - current + 7, 7)
    Date.add(month_start, days_to_add)
  end

  # Apply BYSETPOS filtering to monthly weekday candidates
  defp apply_monthly_bysetpos_filter(candidates, bysetpos_list) do
    # Sort candidates by date to ensure consistent ordering
    sorted_candidates = Enum.sort_by(candidates, & &1.dtstart, DateTime)

    bysetpos_list
    |> Enum.flat_map(fn position ->
      if position > 0 do
        # Positive positions: 1-based indexing from the start
        case Enum.at(sorted_candidates, position - 1) do
          nil -> []
          event -> [event]
        end
      else
        # Negative positions: -1 is last, -2 is second to last, etc.
        case Enum.at(sorted_candidates, position) do
          nil -> []
          event -> [event]
        end
      end
    end)
    # Remove duplicates if same position specified multiple times
    |> Enum.uniq_by(& &1.dtstart)
    # Keep events sorted
    |> Enum.sort_by(& &1.dtstart, DateTime)
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

  defp expand_by_rule(events, :byhour, rrule) do
    by_hour_values = rrule[:byhour] |> List.wrap() |> Enum.map(&String.to_integer/1)

    Enum.flat_map(events, fn event ->
      Enum.map(by_hour_values, fn hour ->
        # Create a new dtstart with the specified hour
        new_dtstart =
          event.dtstart
          |> DateTime.to_naive()
          |> Map.put(:hour, hour)
          |> Map.put(:minute, 0)
          |> Map.put(:second, 0)
          |> DateTime.from_naive!("Etc/UTC")

        # Preserve the original event's duration
        duration = Timex.diff(event.dtend, event.dtstart, :seconds)
        new_dtend = DateTime.add(new_dtstart, duration, :second)

        %{event | dtstart: new_dtstart, dtend: new_dtend}
      end)
    end)
  end

  defp expand_by_rule(events, :byday, _rrule) do
    # This is a simplified version of the original byday logic
    Enum.flat_map(events, fn event ->
      build_refernce_events_by_x_rule(event, :byday)
    end)
  end

  defp expand_by_rule(events, :bymonth, _rrule) do
    Enum.flat_map(events, fn event ->
      build_refernce_events_by_x_rule(event, :bymonth)
    end)
  end

  defp expand_by_rule(events, :bysetpos, _rrule) do
    # bysetpos is handled within the monthly frequency logic, not here
    events
  end

  defp get_reference_events(event) do
    # Start with the base event as the first reference
    initial_events = [event]

    # Sequentially apply each supported BY* rule to expand the event set
    @supported_by_x_rrules
    |> Enum.reduce(initial_events, fn by_rule, events ->
      if Map.has_key?(event.rrule, by_rule) do
        expand_by_rule(events, by_rule, event.rrule)
      else
        events
      end
    end)
    # Sort the resulting events by their start time, as BY* rules can create them out of order
    |> Enum.sort_by(& &1.dtstart)
  end
end

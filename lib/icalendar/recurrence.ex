defmodule ICalendar.Recurrence do
  @moduledoc """
  Adds support for recurring events.

  Events can recur by frequency, count, interval, and/or start/end date. To
  see the specific rules and examples, see `add_recurring_events/2` below.

  Credit to @fazibear for this module.
  """

  alias ICalendar.Event

  # Helper to get the logical start time for recurrence calculations,
  # which is important for date-only events that have been converted to UTC
  # from a different timezone.
  defp get_logical_datetime(event) do
    case event.x_wr_timezone do
      nil ->
        event.dtstart

      timezone when is_binary(timezone) ->
        if is_likely_converted_date_only_value?(event.dtstart, timezone) do
          original_datetime = Timex.to_datetime(event.dtstart, timezone)
          original_date = Timex.to_date(original_datetime)
          DateTime.from_naive!(Timex.to_naive_datetime(original_date), "Etc/UTC")
        else
          event.dtstart
        end
    end
  end

  # Heuristic to detect if a datetime is likely a converted date-only value.
  defp is_likely_converted_date_only_value?(datetime, timezone) do
    timezone_dt = Timex.to_datetime(datetime, timezone)
    timezone_dt.hour == 0 and timezone_dt.minute == 0 and timezone_dt.second == 0
  end

  @doc """
  Given an event, return a list of recurrences for that event.

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
  @spec get_recurrences(%Event{}) :: [%Event{}]
  @spec get_recurrences(%Event{}, %DateTime{}) :: [%Event{}]
  def get_recurrences(event, end_date \\ DateTime.utc_now()) do
    case event.rrule do
      nil ->
        []

      rrule ->
        {freq, opts} = parse_rrule(rrule)
        logical_dtstart = get_logical_datetime(event)

        cycle =
          ExCycle.new()
          |> ExCycle.add_rule(freq, opts)

        occurrences =
          cond do
            count = rrule[:count] ->
              ExCycle.occurrences(cycle, logical_dtstart)
              |> Stream.map(&to_utc/1)
              |> Stream.take(count)
              |> Enum.to_list()

            until = rrule[:until] ->
              ExCycle.occurrences(cycle, logical_dtstart)
              |> Stream.map(&to_utc/1)
              |> Stream.take_while(fn dt -> DateTime.compare(dt, to_utc(until)) != :gt end)
              |> Enum.to_list()

            true ->
              # iterate until the end date
              ExCycle.occurrences(cycle, logical_dtstart)
              |> Stream.map(&to_utc/1)
              |> Stream.take_while(&(DateTime.compare(&1, end_date) != :gt))
              |> Enum.to_list()
          end

        # check if the dtstart is included in the recurrences adding it if it's missing
        occurrences = if DateTime.compare(Enum.at(occurrences, 0), event.dtstart) == :eq do
          occurrences
        else
          [event.dtstart | occurrences]
        end

        occurrences
        |> Enum.map(&map_to_event(event, &1, logical_dtstart))
        |> remove_excluded_dates(event)
    end
  end

  defp parse_rrule(rrule) do
    freq = rrule[:freq] |> String.downcase() |> String.to_atom()

    opts = []
    opts = if interval = rrule[:interval], do: Keyword.put(opts, :interval, interval), else: opts

    opts =
      if wkst = rrule[:wkst],
        do: Keyword.put(opts, :week_start, wkst |> String.downcase() |> String.to_atom()),
        else: opts

    opts =
      if bymonth = rrule[:bymonth],
        do: Keyword.put(opts, :months, Enum.map(bymonth, &String.to_integer/1)),
        else: opts

    opts =
      if byhour = rrule[:byhour],
        do: Keyword.put(opts, :hours, Enum.map(byhour, &String.to_integer/1)),
        else: opts

    opts =
      if byminute = rrule[:byminute],
        do: Keyword.put(opts, :minutes, Enum.map(byminute, &String.to_integer/1)),
        else: opts

    opts = if bysetpos = rrule[:bysetpos], do: Keyword.put(opts, :setpos, bysetpos), else: opts

    opts =
      if byday = rrule[:byday] do
        weekdays = Enum.map(byday, &parse_byday/1)
        Keyword.put(opts, :weekdays, weekdays)
      else
        opts
      end

    {freq, opts}
  end

  defp parse_byday(byday_str) do
    case Regex.run(~r/^(-?\d+)?([A-Z]{2})$/, byday_str, capture: :all_but_first) do
      [nth, day] when nth != "" and not is_nil(nth) -> {day_to_atom(day), String.to_integer(nth)}
      [nil, day] -> day_to_atom(day)
      _ -> nil
    end
  end

  defp day_to_atom(day_str) do
    case day_str do
      "SU" -> :sunday
      "MO" -> :monday
      "TU" -> :tuesday
      "WE" -> :wednesday
      "TH" -> :thursday
      "FR" -> :friday
      "SA" -> :saturday
    end
  end

  defp to_utc(datetime) do
    case datetime do
      %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
      %DateTime{} -> datetime
    end
  end

  defp map_to_event(original_event, new_dtstart, logical_dtstart) do
    duration = DateTime.diff(original_event.dtend, original_event.dtstart, :second)
    offset = DateTime.diff(original_event.dtstart, logical_dtstart, :second)

    final_dtstart = DateTime.add(new_dtstart, offset, :second)
    final_dtend = DateTime.add(final_dtstart, duration, :second)

    %{
      original_event
      | dtstart: final_dtstart,
        dtend: final_dtend,
        rrule: Map.put(original_event.rrule, :is_recurrence, true)
    }
  end

  defp remove_excluded_dates(recurrences, original_event) do
    Enum.filter(recurrences, fn new_event ->
      # The exdates can be Date or DateTime, so we need to handle both.
      falls_on_exdate =
        Enum.any?(original_event.exdates, fn exdate ->
          case exdate do
            %Date{} ->
              Date.compare(DateTime.to_date(new_event.dtstart), exdate) == :eq

            %DateTime{} ->
              DateTime.compare(new_event.dtstart, exdate) == :eq
          end
        end)

      !falls_on_exdate
    end)
  end
end

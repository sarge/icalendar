defmodule ICalendar.Recurrence do
  @moduledoc """
  Adds support for recurring events.

  Events can recur by frequency, count, interval, and/or start/end date. To
  see the specific rules and examples, see `add_recurring_events/2` below.

  Credit to @fazibear for this module.
  """

  alias ICalendar.Event

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
  @spec get_recurrences(%Event{}, %DateTime{}, %DateTime{}) :: [%Event{}]
  def get_recurrences(
        event,
        %DateTime{} = start_date,
        %DateTime{} = end_date \\ DateTime.utc_now(),
        user_timezone \\ nil
      ) do
    # timezone fallback
    calendar_timezone =
      event.x_wr_timezone ||
        user_timezone ||
        "Etc/UTC"

    case event.rrule_str do
      nil ->
        []

      rrule ->
        # Append X-INCLUDE-DTSTART=TRUE for Google Calendar (detected via PRODID)
        is_google_calendar = is_google_calendar?(event.prodid)

        enhanced_rrule =
          if is_google_calendar do
            # Check if X-INCLUDE-DTSTART is already present to avoid duplicates
            if String.contains?(String.upcase(rrule), "X-INCLUDE-DTSTART") do
              rrule
            else
              # Find the RRULE line and append X-INCLUDE-DTSTART=TRUE to it
              rrule_lines = String.split(rrule, "\n")
              enhanced_lines = Enum.map(rrule_lines, fn line ->
                if String.starts_with?(String.upcase(line), "RRULE:") do
                  line <> ";X-INCLUDE-DTSTART=TRUE"
                else
                  line
                end
              end)
              Enum.join(enhanced_lines, "\n")
            end
          else
            rrule
          end

        rrule_upper = String.upcase(enhanced_rrule)
        if String.contains?(rrule_upper, "RRULE") or String.contains?(rrule_upper, "RDATE") do
          {:ok, {occurrences, _has_more}} =
            RRule.all_between(
              enhanced_rrule,
              start_date,
              end_date
            )

          occurrences
          |> Stream.map(&to_timezone(&1, calendar_timezone))
          |> Enum.map(&map_to_event(event, &1, calendar_timezone))
        else
          []
        end
    end
  end

  defp to_timezone(datetime, timezone) do
    case datetime do
      %NaiveDateTime{} ->
        DateTime.from_naive!(datetime, timezone)

      %DateTime{} ->
        datetime |> DateTime.shift_zone!(timezone)

      %Date{} ->
        # When a date is converted it will use the hour offset from
        # TODO: should be the start of the day in that timezone
        DateTime.from_naive!(
          NaiveDateTime.new(datetime, ~T[00:00:00]) |> elem(1),
          timezone
        )
    end
  end

  defp map_to_event(original_event, new_dtstart, calendar_timezone) do
    duration =
      cond do
        true ->
          DateTime.diff(
            to_timezone(original_event.dtend, calendar_timezone),
            to_timezone(original_event.dtstart, calendar_timezone),
            :second
          )
      end

    final_dtstart = to_timezone(new_dtstart, calendar_timezone)

    final_dtend =
      cond do
        true ->
          DateTime.add(final_dtstart, duration, :second)
      end

    %{
      original_event
      | dtstart: final_dtstart,
        dtend: final_dtend,
        rrule: original_event.rrule
    }
  end

  # Helper function to detect Google Calendar from PRODID
  defp is_google_calendar?(prodid) when is_binary(prodid) do
    prodid_upper = String.upcase(prodid)
    String.contains?(prodid_upper, "GOOGLE") and String.contains?(prodid_upper, "CALENDAR")
  end

  defp is_google_calendar?(nil), do: false
end

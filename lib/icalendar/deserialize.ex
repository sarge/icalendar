defprotocol ICalendar.Deserialize do
  def from_ics(ics)
end

alias ICalendar.Deserialize

defimpl ICalendar.Deserialize, for: BitString do
  alias ICalendar.Util.Deserialize

  def from_ics(ics) do
    calendar_lines = ics
    |> String.trim()
    |> adjust_wrapped_lines()
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.map(&String.replace(&1, ~S"\n", "\n"))

    # Extract X-WR-TIMEZONE from calendar level
    x_wr_timezone = extract_x_wr_timezone(calendar_lines)

    get_events(calendar_lines, [], [], x_wr_timezone)
  end

  # Copy approach from Ruby library to deal with Google Calendar's wrapping
  # https://github.com/icalendar/icalendar/blob/14db8fdd36f9007fa2627b2c10a9cdf3c9f8f35a/lib/icalendar/parser.rb#L9-L22
  # See https://github.com/lpil/icalendar/issues/53 for discussion
  defp adjust_wrapped_lines(body) do
    String.replace(body, ~r/\r?\n[ \t]/, "")
  end

  defp extract_x_wr_timezone(calendar_lines) do
    calendar_lines
    |> Enum.find(fn line ->
      String.starts_with?(line, "X-WR-TIMEZONE:")
    end)
    |> case do
      nil -> nil
      line ->
        [_, timezone] = String.split(line, ":", parts: 2)
        timezone
    end
  end

  defp get_events(calendar_data, event_collector, temp_collector, x_wr_timezone)

  defp get_events([head | calendar_data], event_collector, temp_collector, x_wr_timezone) do
    case head do
      "BEGIN:VEVENT" ->
        # start collecting event
        get_events(calendar_data, event_collector, [head], x_wr_timezone)

      "END:VEVENT" ->
        # finish collecting event
        event = Deserialize.build_event(temp_collector ++ [head], x_wr_timezone)
        get_events(calendar_data, [event] ++ event_collector, [], x_wr_timezone)

      event_property when temp_collector != [] ->
        get_events(calendar_data, event_collector, temp_collector ++ [event_property], x_wr_timezone)

      _unimportant_stuff ->
        get_events(calendar_data, event_collector, temp_collector, x_wr_timezone)
    end
  end

  defp get_events([], event_collector, _temp_collector, _x_wr_timezone), do: event_collector
end

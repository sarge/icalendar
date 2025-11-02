defmodule ICalendar.Util.Deserialize do
  @moduledoc """
  Deserialize ICalendar Strings into Event structs.
  """

  alias ICalendar.Event
  alias ICalendar.Property

  def build_event(lines) when is_list(lines) do
    build_event(lines, nil)
  end

  def build_event(lines, x_wr_timezone) when is_list(lines) do
    build_event(lines, x_wr_timezone, nil)
  end

  def build_event(lines, x_wr_timezone, prodid) when is_list(lines) do
    initial_event = %Event{
      rrule_str: extract_rrule_properties_from_ical(lines),
      x_wr_timezone: x_wr_timezone,
      prodid: prodid
    }

    lines
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&retrieve_kvs/1)
    |> Enum.reduce(initial_event, &parse_attr/2)
  end

  defp extract_rrule_properties_from_ical(lines) do
    lines
    |> Enum.filter(fn line ->
      String.starts_with?(line, "RRULE") or
        String.starts_with?(line, "EXRULE") or
        String.starts_with?(line, "DTSTART") or
        String.starts_with?(line, "RDATE") or
        String.starts_with?(line, "EXDATE")
    end)
    |> Enum.join("\n")
  end

  @doc ~S"""
  This function extracts the key and value parts from each line of a iCalendar
  string.

      iex> ICalendar.Util.Deserialize.retrieve_kvs("lorem:ipsum")
      %ICalendar.Property{key: "LOREM", params: %{}, value: "ipsum"}

  """
  def retrieve_kvs(line) do
    # Split Line up into key and value
    {key, value, params} =
      case String.split(line, ":", parts: 2, trim: true) do
        [key, value] ->
          [key, params] = retrieve_params(key)
          {key, value, params}

        [key] ->
          {key, nil, %{}}
      end

    %Property{key: String.upcase(key), value: value, params: params}
  end

  @doc ~S"""
  This function extracts parameter data from a key in an iCalendar string.

      iex> ICalendar.Util.Deserialize.retrieve_params(
      ...>   "DTSTART;TZID=America/Chicago")
      ["DTSTART", %{"TZID" => "America/Chicago"}]

  It should be able to handle multiple parameters per key:

      iex> ICalendar.Util.Deserialize.retrieve_params(
      ...>   "KEY;LOREM=ipsum;DOLOR=sit")
      ["KEY", %{"LOREM" => "ipsum", "DOLOR" => "sit"}]

  """
  def retrieve_params(key) do
    [key | params] = String.split(key, ";", trim: true)

    params =
      params
      |> Enum.reduce(%{}, fn param, acc ->
        case String.split(param, "=", parts: 2, trim: true) do
          [key, val] -> Map.merge(acc, %{key => val})
          [key] -> Map.merge(acc, %{key => nil})
          _ -> acc
        end
      end)

    [key, params]
  end

  def parse_attr(%Property{key: _, value: nil}, acc), do: acc

  def parse_attr(
        %Property{key: "DESCRIPTION", value: description},
        acc
      ) do
    %{acc | description: desanitized(description)}
  end

  def parse_attr(
        %Property{key: "DTSTART", value: dtstart, params: params},
        acc
      ) do
    {:ok, timestamp} = to_date(dtstart, params, acc.x_wr_timezone)
    %{acc | dtstart: timestamp}
  end

  def parse_attr(
        %Property{key: "DTEND", value: dtend, params: params},
        acc
      ) do
    {:ok, timestamp} = to_date(dtend, params, acc.x_wr_timezone)
    %{acc | dtend: timestamp}
  end

  def parse_attr(
        %Property{key: "RRULE", value: rrule},
        acc
      ) do
    # Value will have the format FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1
    # Defined here: https://icalendar.org/iCalendar-RFC-5545/3-3-10-recurrence-rule.html

    rrule = parse_rrule(rrule)

    %{acc | rrule: rrule}
  end

  def parse_attr(
        %Property{key: "EXDATE", value: exdate, params: params},
        acc
      ) do
    exdates = Map.get(acc, :exdates, [])
    {:ok, timestamp} = to_date(exdate, params, acc.x_wr_timezone)
    %{acc | exdates: [timestamp | exdates]}
  end

  def parse_attr(
        %Property{key: "SUMMARY", value: summary},
        acc
      ) do
    %{acc | summary: desanitized(summary)}
  end

  def parse_attr(
        %Property{key: "LOCATION", value: location},
        acc
      ) do
    %{acc | location: desanitized(location)}
  end

  def parse_attr(
        %Property{key: "COMMENT", value: comment},
        acc
      ) do
    %{acc | comment: desanitized(comment)}
  end

  def parse_attr(
        %Property{key: "STATUS", value: status},
        acc
      ) do
    %{acc | status: status |> desanitized() |> String.downcase()}
  end

  def parse_attr(
        %Property{key: "CATEGORIES", value: categories},
        acc
      ) do
    %{acc | categories: String.split(desanitized(categories), ",")}
  end

  def parse_attr(
        %Property{key: "CLASS", value: class},
        acc
      ) do
    %{acc | class: class |> desanitized() |> String.downcase()}
  end

  def parse_attr(
        %Property{key: "GEO", value: geo},
        acc
      ) do
    %{acc | geo: to_geo(geo)}
  end

  def parse_attr(
        %Property{key: "UID", value: uid},
        acc
      ) do
    %{acc | uid: uid}
  end

  def parse_attr(
        %Property{key: "LAST-MODIFIED", value: modified},
        acc
      ) do
    {:ok, timestamp} = to_date(modified, %{}, nil)
    %{acc | modified: timestamp}
  end

  def parse_attr(
        %Property{key: "ORGANIZER", params: _params, value: organizer},
        acc
      ) do
    %{acc | organizer: organizer}
  end

  def parse_attr(
        %Property{key: "ATTENDEE", params: params, value: value},
        acc
      ) do
    %{acc | attendees: [Map.put(params, :original_value, value)] ++ acc.attendees}
  end

  def parse_attr(
        %Property{key: "SEQUENCE", value: sequence},
        acc
      ) do
    %{acc | sequence: sequence}
  end

  def parse_attr(
        %Property{key: "URL", value: url},
        acc
      ) do
    %{acc | url: url |> desanitized() |> String.downcase()}
  end

  def parse_attr(_, acc), do: acc

  @doc ~S"""
  This function is designed to parse iCal datetime strings into erlang dates.

  It should be able to handle dates from the past:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("19930407T153022Z")
      ...> Timex.to_erl(date)
      {{1993, 4, 7}, {15, 30, 22}}

  As well as the future:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("39930407T153022Z")
      ...> Timex.to_erl(date)
      {{3993, 4, 7}, {15, 30, 22}}

  And should return error for incorrect dates:

      iex> ICalendar.Util.Deserialize.to_date("1993/04/07")
      {:error, "Expected `2 digit month` at line 1, column 5."}

  It should handle timezones from  the Olson Database:

      iex> {:ok, date} = ICalendar.Util.Deserialize.to_date("19980119T020000",
      ...> %{"TZID" => "America/Chicago"})
      ...> [Timex.to_erl(date), date.time_zone]
      [{{1998, 1, 19}, {2, 0, 0}}, "America/Chicago"]
  """

  # New overloads that handle X-WR-TIMEZONE
  def to_date(date_string, %{"VALUE" => "DATE"} = _params, _x_wr_timezone) do
    # When VALUE=DATE is present, always treat as date regardless of other parameters
    case Timex.parse(date_string, "{YYYY}{0M}{0D}") do
      {:ok, date} -> {:ok, Timex.to_date(date)}
      error -> error
    end
  end

  def to_date(date_string, %{"TZID" => timezone}, _x_wr_timezone) do
    to_date(date_string, %{"TZID" => timezone})
  end

  def to_date(date_string, params, x_wr_timezone) when is_binary(x_wr_timezone) do
    # Check if we have a hanging datetime (full datetime without timezone indicator)
    # Pattern: YYYYMMDDTHHMMSS (no Z suffix, no TZID param)
    if String.match?(date_string, ~r/^\d{8}T\d{6}$/) and not Map.has_key?(params, "TZID") do
      # Parse as naive datetime and interpret in X-WR-TIMEZONE
      case Timex.parse(date_string, "{YYYY}{0M}{0D}T{h24}{m}{s}") do
        {:ok, naive_datetime} ->
          # Treat as being in the X-WR-TIMEZONE and convert to UTC
          timezone_datetime = Timex.to_datetime(naive_datetime, x_wr_timezone)
          utc_datetime = Timex.to_datetime(timezone_datetime, "UTC")
          {:ok, utc_datetime}

        error ->
          error
      end
    else
      # For all other cases, ignore X-WR-TIMEZONE and use existing logic
      to_date(date_string, params)
    end
  end

  def to_date(date_string, params, _x_wr_timezone) do
    # For all other cases, ignore X-WR-TIMEZONE and use existing logic
    to_date(date_string, params)
  end

  # Original functions (keeping for backward compatibility)
  def to_date(date_string, %{"VALUE" => "DATE"} = _params) do
    # When VALUE=DATE is present, always treat as date regardless of other parameters
    case Timex.parse(date_string, "{YYYY}{0M}{0D}") do
      {:ok, date} -> {:ok, Timex.to_date(date)}
      error -> error
    end
  end

  def to_date(date_string, %{"TZID" => timezone}) do
    # Microsoft Outlook calendar .ICS files report times in Greenwich Standard Time (UTC +0)
    # so just convert this to UTC
    timezone =
      if Regex.match?(~r/\//, timezone) do
        timezone
      else
        Timex.Timezone.Utils.to_olson(timezone)
      end

    date_string =
      case String.last(date_string) do
        "Z" -> date_string
        _ -> date_string <> "Z"
      end

    Timex.parse(date_string <> timezone, "{YYYY}{0M}{0D}T{h24}{m}{s}Z{Zname}")
  end

  def to_date(date_string, %{}) do
    date_string =
      case String.last(date_string) do
        "Z" -> date_string
        _ -> date_string <> "Z"
      end

    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end

  def to_date(date_string) do
    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end

  defp to_geo(geo) do
    geo
    |> desanitized()
    |> String.split(";")
    |> Enum.map(fn x -> Float.parse(x) end)
    |> Enum.map(fn {x, _} -> x end)
    |> List.to_tuple()
  end

  @doc ~S"""

  This function should strip any sanitization that has been applied to content
  within an iCal string.

      iex> ICalendar.Util.Deserialize.desanitized(~s(lorem\\, ipsum))
      "lorem, ipsum"
  """
  def desanitized(string) do
    string
    |> String.replace(~s(\\), "")
  end

  @doc """
  This function builds an rrule struct.

  RRULE:FREQ=WEEKLY;WKST=SU;UNTIL=20201204T045959Z;INTERVAL=2;BYDAY=TH,WE;BYSETPOS=-1

  will get turned into:

  ```elixir
  %{
    byday: ["TH", "WE"],
    freq: "WEEKLY",
    bysetpos: [-1],
    interval: 2,
    until: ~U[2020-12-04 04:59:59Z]
  }
  ```
  """
  def parse_rrule(rrule) do
    rrule
    |> String.split(";")
    |> Enum.reduce(%{}, fn rule, hash ->
      [key, value] = rule |> String.split("=")

      case key |> String.downcase() |> String.to_atom() do
        :freq ->
          hash |> Map.put(:freq, value)

        :until ->
          hash |> Map.put(:until, ICalendar.Util.DateParser.parse(value))

        :count ->
          hash |> Map.put(:count, String.to_integer(value))

        :interval ->
          hash |> Map.put(:interval, String.to_integer(value))

        :bysecond ->
          hash |> Map.put(:bysecond, String.split(value, ","))

        :byminute ->
          hash |> Map.put(:byminute, String.split(value, ","))

        :byhour ->
          hash |> Map.put(:byhour, String.split(value, ","))

        :byday ->
          hash |> Map.put(:byday, String.split(value, ","))

        :bymonthday ->
          hash |> Map.put(:bymonthday, String.split(value, ","))

        :byyearday ->
          hash |> Map.put(:byyearday, String.split(value, ","))

        :byweekno ->
          hash |> Map.put(:byweekno, String.split(value, ","))

        :bymonth ->
          hash |> Map.put(:bymonth, String.split(value, ","))

        :bysetpos ->
          hash |> Map.put(:bysetpos, Enum.map(String.split(value, ","), &String.to_integer(&1)))

        :wkst ->
          hash |> Map.put(:wkst, value)

        _ ->
          hash
      end
    end)
  end
end

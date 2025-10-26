defmodule ICalendar.DeserializeTest do
  use ExUnit.Case

  alias ICalendar.Event

  describe "ICalendar.from_ics/1" do
    test "Single Event" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water.
      COMMENT:Don't forget to take something to eat !
      SUMMARY:Going fishing
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)

      assert event == %Event{
               dtstart: Timex.to_datetime({{2015, 12, 24}, {8, 30, 0}}),
               dtend: Timex.to_datetime({{2015, 12, 24}, {8, 45, 0}}),
               summary: "Going fishing",
               description: "Escape from the world. Stare at some water.",
               location: "123 Fun Street, Toronto ON, Canada",
               status: "tentative",
               categories: ["Fishing", "Nature"],
               comment: "Don't forget to take something to eat !",
               class: "private",
               rrule_str: "DTSTART:20151224T083000Z",
               geo: {43.6978819, -79.3810277}
             }
    end

    test "Single event with wrapped description and summary" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water. Maybe you'll even
        catch some fish!
      COMMENT:Don't forget to take something to eat !
      SUMMARY:Going fishing at the lake that happens to be in the middle of fun
        street.
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)

      assert event == %Event{
               dtstart: Timex.to_datetime({{2015, 12, 24}, {8, 30, 0}}),
               dtend: Timex.to_datetime({{2015, 12, 24}, {8, 45, 0}}),
               summary:
                 "Going fishing at the lake that happens to be in the middle of fun street.",
               description:
                 "Escape from the world. Stare at some water. Maybe you'll even catch some fish!",
               location: "123 Fun Street, Toronto ON, Canada",
               status: "tentative",
               categories: ["Fishing", "Nature"],
               comment: "Don't forget to take something to eat !",
               class: "private",
               rrule_str: "DTSTART:20151224T083000Z",
               geo: {43.6978819, -79.3810277}
             }
    end

    test "with Timezone" do
      ics = """
      BEGIN:VEVENT
      DTEND;TZID=America/Chicago:22221224T084500
      DTSTART;TZID=America/Chicago:22221224T083000
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart.time_zone == "America/Chicago"
      assert DateTime.to_string(event.dtstart) == "2222-12-24 08:30:00-06:00 CST America/Chicago"
      assert event.dtend.time_zone == "America/Chicago"
      assert DateTime.to_string(event.dtend) == "2222-12-24 08:45:00-06:00 CST America/Chicago"
    end

    test "with CR+LF line endings" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:CR+LF line endings\r\nSUMMARY:Going fishing\r
      DTEND:20151224T084500Z\r\nDTSTART:20151224T083000Z\r
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.description == "CR+LF line endings"
    end

    test "with URL" do
      ics = """
      BEGIN:VEVENT
      DESCRIPTION:Escape from the world. Stare at some water.
      COMMENT:Don't forget to take something to eat !
      URL:http://google.com
      SUMMARY:Going fishing
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      LOCATION:123 Fun Street\\, Toronto ON\\, Canada
      STATUS:TENTATIVE
      CATEGORIES:Fishing,Nature
      CLASS:PRIVATE
      GEO:43.6978819;-79.3810277
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.url == "http://google.com"
    end

    # floating date, returns a Date
    test "with Date (no time)" do
      ics = """
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
    end

    # hanging date with X-WR-TIMEZONE, will leave the Timezone conversion to a later step
    test "with Date (no time) with X-WR-TIMEZONE" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
    end

    test "with DateTime (UTC) with X-WR-TIMEZONE, the X-WR-TIMEZONE should be ignored" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTEND:20151224T084500Z
      DTSTART:20151224T083000Z
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~U[2015-12-24 08:30:00Z]
      assert event.dtend == ~U[2015-12-24 08:45:00Z]
    end

    test "with DateTime (hanging) with X-WR-TIMEZONE, the X-WR-TIMEZONE should be applied" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTEND:20151224T084500
      DTSTART:20151224T083000
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~U[2015-12-23 19:30:00Z]
      assert event.dtend == ~U[2015-12-23 19:45:00Z]
    end

    test "with DateTime (with TZID) and X-WR-TIMEZONE, the X-WR-TIMEZONE should be ignored" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      DTEND;TZID=America/Chicago:22221224T084500
      DTSTART;TZID=America/Chicago:22221224T083000
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart.time_zone == "America/Chicago"
      assert DateTime.to_string(event.dtstart) == "2222-12-24 08:30:00-06:00 CST America/Chicago"
      assert event.dtend.time_zone == "America/Chicago"
      assert DateTime.to_string(event.dtend) == "2222-12-24 08:45:00-06:00 CST America/Chicago"
    end

    test "recurring event with Date (no time) values" do
      ics = """
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=3
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:All day recurring event
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
      assert event.rrule.freq == "DAILY"
      assert event.rrule.count == 3
    end

    # TODO: review handling of X-WR-TIMEZONE
    test "recurring event with Date (no time) values and X-WR-TIMEZONE" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      RRULE:FREQ=WEEKLY;COUNT=2
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:All day recurring event with timezone
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      # Date should be interpreted as midnight in Pacific/Auckland and converted to UTC
      # November 2025: Pacific/Auckland is UTC+13 (daylight saving time)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
      assert event.rrule.freq == "WEEKLY"
      assert event.rrule.count == 2
    end

    test "recurring event with Date (no time) values and UNTIL as date" do
      ics = """
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;UNTIL=20251117
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      SUMMARY:All day recurring event with date until
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
      assert event.rrule.freq == "DAILY"
      # UNTIL should be parsed as a date (converted to DateTime at end of day)
      assert event.rrule.until == ~U[2025-11-17 00:00:00Z]
    end

    test "recurring event with Date (no time) values and EXDATE as date" do
      ics = """
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=5
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      EXDATE;VALUE=DATE:20251116
      SUMMARY:All day recurring event with exception date
      END:VEVENT
      """

      [event] = ICalendar.from_ics(ics)
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
      assert event.rrule.freq == "DAILY"
      assert event.rrule.count == 5
      # EXDATE should be parsed as date (midnight UTC)
      assert event.exdates == [~D[2025-11-16]]
    end

    test "recurring event with Date (no time) values, EXDATE and X-WR-TIMEZONE" do
      ics = """
      BEGIN:VCALENDAR
      X-WR-TIMEZONE:Pacific/Auckland
      BEGIN:VEVENT
      RRULE:FREQ=DAILY;COUNT=5
      DTSTART;VALUE=DATE:20251114
      DTEND;VALUE=DATE:20251115
      EXDATE;VALUE=DATE:20251116
      SUMMARY:All day recurring event with exception date and timezone
      END:VEVENT
      END:VCALENDAR
      """

      [event] = ICalendar.from_ics(ics)
      # Dates should be interpreted as midnight in Pacific/Auckland and converted to UTC
      assert event.dtstart == ~D[2025-11-14]
      assert event.dtend == ~D[2025-11-15]
      assert event.rrule.freq == "DAILY"
      assert event.rrule.count == 5
      # EXDATE should also be interpreted in the timezone and converted to UTC
      assert event.exdates == [~D[2025-11-16]]
    end
  end
end

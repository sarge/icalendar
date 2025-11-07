# ICalendar Recurrence Test Suite

This directory contains comprehensive tests for RRULE (recurrence rule) functionality in the ICalendar library.

## Test Organization

The tests are split across multiple files for better organization and maintainability:

### Core Test Files

1. **`recurrence_extended_test.exs`** - Basic working tests for currently supported features
2. **`recurrence_daily_test.exs`** - Comprehensive FREQ=DAILY tests
3. **`recurrence_weekly_test.exs`** - Comprehensive FREQ=WEEKLY tests  
4. **`recurrence_monthly_test.exs`** - Comprehensive FREQ=MONTHLY tests
5. **`recurrence_yearly_test.exs`** - Comprehensive FREQ=YEARLY tests
6. **`recurrence_high_frequency_test.exs`** - FREQ=HOURLY/MINUTELY/SECONDLY tests
7. **`recurrence_complex_test.exs`** - Complex BY* rule combinations
8. **`recurrence_edge_cases_test.exs`** - Boundary conditions and edge cases

## Current Implementation Status

### ✅ Currently Supported
- **Frequencies**: DAILY, WEEKLY, MONTHLY, YEARLY
- **Modifiers**: COUNT, UNTIL, INTERVAL
- **BY* Rules**: BYDAY (partial support for monthly nth weekday patterns like "2WE")

### ❌ Not Yet Supported (marked with `@tag :skip`)
- **Frequencies**: HOURLY, MINUTELY, SECONDLY
- **BY* Rules**: 
  - BYMONTH (partial support exists but many cases are skipped)
  - BYMONTHDAY
  - BYYEARDAY  
  - BYWEEKNO
  - BYHOUR
  - BYMINUTE
  - BYSECOND
  - BYSETPOS
- **Other**: WKST (week start)

## Test Verification

All test cases are designed to be verified against the reference implementation at:
https://kewisch.github.io/ical.js/recur-tester.html

Each test file includes this URL in the header for easy reference.

## Test Structure

Each test follows this pattern:

```elixir
test "FREQ=DAILY;COUNT=5" do
  results = create_ical_event(
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
```

The `create_ical_event/2` helper function:
1. Creates a complete iCalendar string with the given RRULE
2. Parses it using `ICalendar.from_ics/1`
3. Generates recurrences using `ICalendar.Recurrence.get_recurrences/1`
4. Returns the original event plus the first 5 recurrences

## Running Tests

### Run all tests:
```bash
mix test
# Shows: 200 tests, 0 failures, 88 skipped
```

### Run only supported tests (skip unsupported features):
```bash
mix test --exclude skip
# Shows: 112 tests, 0 failures
```

### Run specific test file:
```bash
mix test test/icalendar/recurrence_daily_test.exs
```

### Run specific test:
```bash
mix test test/icalendar/recurrence_daily_test.exs:42
```

## Adding New Tests

When adding support for new RRULE features:

1. Find the relevant test file
2. Remove the `@tag :skip` from the appropriate test
3. Update the test expectations if needed
4. Verify against https://kewisch.github.io/ical.js/recur-tester.html
5. Update this documentation

## RRULE Reference

For complete RRULE specification, see:
- [RFC 5545 Section 3.3.10](https://tools.ietf.org/html/rfc5545#section-3.3.10)
- [RFC 5545 Section 3.8.5.3](https://tools.ietf.org/html/rfc5545#section-3.8.5.3)

## Test Categories by Complexity

### Level 1: Basic Frequency (✅ Supported)
- FREQ=DAILY
- FREQ=WEEKLY  
- FREQ=MONTHLY
- FREQ=YEARLY

### Level 2: Modifiers (✅ Supported)
- COUNT
- UNTIL
- INTERVAL

### Level 3: Simple BY* Rules (⭕ Partially Supported)
- BYDAY (monthly nth weekday only)

### Level 4: Complex BY* Rules (❌ Not Supported)
- BYMONTH
- BYMONTHDAY
- BYYEARDAY
- BYWEEKNO
- BYHOUR, BYMINUTE, BYSECOND

### Level 5: Advanced Features (❌ Not Supported)
- BYSETPOS
- WKST
- High-frequency recurrence (HOURLY, MINUTELY, SECONDLY)

### Level 6: Edge Cases (⭕ Mixed Support)
- Leap year handling
- Month boundary conditions
- DST transitions
- Invalid/boundary values

## Test Dates Used

Most tests use dates in October 2025 for consistency:
- **Base date**: 2025-10-14 (Tuesday)
- **Week start**: 2025-10-13 (Monday)
- **Month start**: 2025-10-01 (Wednesday)
- **Leap year examples**: 2024-02-29, 2028-02-29

This provides a good mix of weekdays and is close to the current date context (October 2025).
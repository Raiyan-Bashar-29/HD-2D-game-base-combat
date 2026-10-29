extends TestCase
## World simulation: the clock and the weather state machine.
##
## OWNS: assertions about time and weather. MUST NOT: assert on lighting, which is the
## environment driver's job and needs a rendered frame to judge.


func run() -> void:
	plan(21)
	_clock()
	_weather()


func _clock() -> void:
	Clock.set_time(1, 6, 0)
	equal("clock hour", Clock.hour, 6)
	equal("clock minutes_today", Clock.minutes_today(), 360)
	equal("clock day_fraction", is_equal_approx(Clock.day_fraction(), 0.25), true)
	equal("clock phase at 06:00", Clock.phase(), GameEnums.DayPhase.DAWN)

	# Phase boundaries, which lighting and NPC schedules both key off.
	equal("phase 04:00 is deep night", Clock.phase_for_hour(4), GameEnums.DayPhase.DEEP_NIGHT)
	equal("phase 12:00 is midday", Clock.phase_for_hour(12), GameEnums.DayPhase.MIDDAY)
	equal("phase 23:00 is night", Clock.phase_for_hour(23), GameEnums.DayPhase.NIGHT)

	Clock.set_time(1, 6, 59)
	Clock.advance_minutes(1)
	equal("clock rolls the hour", Clock.hour, 7)
	equal("clock resets the minute", Clock.minute, 0)

	Clock.set_time(1, 23, 59)
	Clock.advance_minutes(1)
	equal("clock rolls the day", Clock.day, 2)
	equal("clock wraps to hour zero", Clock.hour, 0)

	# Sleeping until morning crosses midnight, the case that is easy to get wrong.
	Clock.set_time(2, 22, 0)
	equal("minutes until 06:00 from 22:00", Clock.minutes_until_hour(6), 480)
	Clock.set_time(2, 4, 0)
	equal("minutes until 06:00 from 04:00", Clock.minutes_until_hour(6), 120)

	Clock.set_time(1, 6, 0)


func _weather() -> void:
	Weather.force(GameEnums.WeatherKind.RAIN)
	equal("weather forced current", Weather.current(), GameEnums.WeatherKind.RAIN)
	equal("weather forced target", Weather.target(), GameEnums.WeatherKind.RAIN)
	equal("weather blend settled", is_equal_approx(Weather.blend(), 1.0), true)
	equal("weather is wet", Weather.is_wet(), true)

	# Shelter hides the weather without changing it, so stepping outside shows the same storm.
	Weather.sheltered = true
	equal("sheltered is not wet", Weather.is_wet(), false)
	equal("sheltered keeps the state", Weather.current(), GameEnums.WeatherKind.RAIN)
	Weather.sheltered = false

	Weather.force(GameEnums.WeatherKind.CLEAR)
	equal("clear is not wet", Weather.is_wet(), false)
	equal("clear intensity is zero", is_equal_approx(Weather.intensity(), 0.0), true)

# encoding: utf-8

require 'yahoo_weatherman'

# NOTE: yahoo_weatherman is using open-uri and nokogiri, it's clunky and it
# blocks, but it works fine!
Script :weather, includes: [Commands] do
  Author "Mikkel Kroman <mk@uplink.io>"
  Version "0.1"
  Description "Look up the weather in most cities around the world"

  ConditionCodes = [
    "Tornado", "Tropical Storm", "Hurricane", "Severe Thunderstorms",
    "Thunderstorms", "Mixed rain and snow", "Mixed rain and sleet",
    "Mixed snow and sleet", "Freezing drizzle", "Drizzle", "Freezing rain",
    "Showers", "Showers", "Snow flurries", "Light snow showers", "Blowing snow",
    "Snow", "Hail", "Sleet", "Dust", "Foggy", "Haze", "Smoky", "Blustery",
    "Windy", "Cold", "Cloudy", "Mostly cloudy (night)", "Mostly cloudy (day)",
    "Partly cloudy (night)", "Partly cloudy (day)", "Clear (night)", "Sunny",
    "Fair (night)", "Fair (day)", "Mixed rain and hail", "Hot",
    "Isolated thunderstorms", "Scattered thunderstorms", "Scattered thunderstorms",
    "Scattered showers", "Heavy snow", "Scattered snow showers", "Heavy snow",
    "Partly cloudy", "Thundershowers", "Snow showers", "Isolated thundershowers"
  ]

  def loaded
    @client = Weatherman::Client.new
  end

  command :weather do |user, channel, args|
    if args and weather = @client.lookup_by_location(args)
      location = "#{weather.location['city']}, #{weather.location['country']}"
      channel.say format format_condition(weather), location
    else
      channel.say format "Usage:\x0F .w <location>"
    end
  end

private

  def format message, subtitle = nil
    if subtitle
      "\x0310>\x0F\x02 Weather\x02\x0310 (\x0F#{subtitle}\x0310): #{message}"
    else
      "\x0310>\x0F\x02 Weather:\x02\x0310 #{message}"
    end
  end

  def format_condition weather
    wind = weather.wind
    condition = weather.condition
    "\x0F#{condition['temp']}\u00B0 C\x0310,\x0F #{ConditionCodes[condition['code']]}\x0310 with a wind speed of\x0F #{wind['speed']} kph\x0310."
  end
end
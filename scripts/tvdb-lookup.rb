# encoding: utf-8

require 'active_support/time'
require 'htmlentities'
require 'open-uri'
require 'nokogiri'

Script :tvdb_lookup, uses: %w{http}, includes: [Commands] do
  Author "Ole Bergmann <ole@ole.im>"
  Version "0.2"
  Description "Provides a method to search TVDB for a Show's previous and next episodes"

  # Script constants.
  APIKey      = '950C33BEABF4A965'           # API Key for TVDBApi
  APILanguage = 'en'                         # 2 char language code for API
  APITimeZone = 'Pacific Time (US & Canada)' # TimeZone for the TVDB API

  # String representation for how the air dates should be formatted
  DateFormat  = '%d/%m/%Y %H:%M'

  # Hardcoded path for API: http://thetvdb.com/wiki/index.php?title=API:mirrors.xml
  MirrorPath  = 'http://thetvdb.com/'

  SearchURI   = "#{MirrorPath}api/GetSeries.php?seriesname=%s"
  LookupURI   = "#{MirrorPath}api/#{APIKey}/series/%s/all/#{APILanguage}.xml"

  def loaded

    # Initialize the shows array for caching search results
    cache[:shows] ||= []

    # Set the timezone
    Time.zone = APITimeZone
  end

  command %w{next episode tvnext series} do |user, channel, args|
    unless args
      return channel.say format "Usage:\x0F .next <query>"
    end

    search args do |result|

      if result

        lookup result do |series|

          if series

            response = "#{ series[:name] }\x0F - "

            if series[:last_episode]

              response += "\x0310Latest:\x0F %s " % format_episode(series[:last_episode])
            end

            if series[:next_episode]

              response += "\x0310Next:\x0F %s " % format_episode(series[:next_episode])
            end

            if series[:status]
              response += "\x0310Status:\x0F #{ series[:status] }"
            end

            channel.say format response

          else
            channel.say format 'An error occured in the lookup'
          end
        end

      else
        channel.say format 'No Results'
      end
    end
  end
  
  def search_cache query
    cache[:shows].select {|s| s[:name].downcase.include? query.downcase }.first
  end

  def exists? id
    cache[:shows].select {|s| s[:id] == id}.first
  end
  
  def search query

    cached = search_cache query

    # if we found the show in the cache, we just return the id
    if cached

      yield cached[:id]

    # otherwise look it up on TVDBApi
    else

      search_uri = SearchURI % URI.escape(query)

      context = http.get search_uri

      context.success do 
        begin
          xml = Nokogiri::XML(context.response.to_s)

          results = xml.css('Series')

          if results.any?

            # get the first result in the list
            series = results.first

            # name is only used for caching purposes here
            name = series.css('SeriesName').first.text
            id   = series.css('seriesid').first.text

            # we gain nothing from caching multiple instances of the same show
            # and searching the cache might not be as reliable as searching tvdb
            # so we need to make sure the show doesnt exist in the cache
            unless exists? id
              # cache the result
              cache[:shows] << {:id => id, :name => name}
            end

            # we only need the id for search results
            # thus we just return the id
            yield id

          else
            yield nil
          end

        rescue Exception => e
          p "#{e.message} - #{e.class.to_s}"
          p e.backtrace

          yield nil
        end
      end

      context.error do
        yield nil
      end
    end
  end

  def lookup id
    lookup_uri = LookupURI % id

    context = http.get lookup_uri

    context.success do 
      begin
        xml = Nokogiri::XML(context.response.to_s)

        name    = xml.css('Data Series SeriesName').first.text
        runtime = xml.css('Data Series Runtime').first.text
        status  = xml.css('Data Series Status').first.text

        # The time at which the show airs
        clock  = xml.css('Data Series Airs_Time').first.text

        # Get the current time in the API TimeZone
        now    = Time.zone.now

        last_episode = nil
        next_episode = nil

        episodes = xml.css('Data Episode')

        episodes.each do |episode|

            # We dont care about specials
            next if episode.css('SeasonNumber').first.text == '0'

            aired = airtime episode, clock

            # just continue overriding while we havent got the latest episode
            if aired < now
                last_episode = episode
            end

            # no point in looking for next episode if the series have ended
            if status != 'Ended' and aired >= now
                next_episode = episode

                # break out of loop if we find the next episode
                break
            end
        end

        # return the result
        yield({
            :name         => name,
            :runtime      => runtime,
            :status       => status,
            :last_episode => parse_episode(last_episode, clock),
            :next_episode => parse_episode(next_episode, clock)
        })

      rescue Exception => e
        p "#{e.message} - #{e.class.to_s}"
        p e.backtrace

        yield nil
      end
    end

    context.error do
      yield nil
    end
  end

  def parse_episode episode, clock

    return unless episode

    name = episode.css('EpisodeName').first.text
    episode_number = episode.css('EpisodeNumber').first.text
    episode_season  = episode.css('SeasonNumber').first.text
    aired = airtime episode, clock

    # return the parsed information
    {
        :name => name,
        :episode => episode_number,
        :season  => episode_season,
        :airtime => aired
    }
  end

  def airtime episode, clock
    Time.zone.parse(episode.css('FirstAired').first.text + " #{clock}").getlocal
  end

  def format_episode episode

    aired = episode[:airtime].strftime(DateFormat)

    %{\x0310(\x0F#{episode[:season].rjust(2, '0')}x#{episode[:episode].rjust(2, '0')}\x0310)\x0F \x02#{aired}\x02}
  end
  
  def format message
    %{\x0310>\x0F \x02TV:\x02\x0310 #{message}}
  end
end

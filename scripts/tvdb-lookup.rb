# encoding: utf-8

require 'time'
require 'htmlentities'
require 'open-uri'
require 'nokogiri'

Script :tvdb_lookup, uses: %w{http}, includes: [Commands] do
  Author "Ole Bergmann <ole@ole.im>"
  Version "0.4"
  Description "Provides a method to search TVDB for a Show's previous and next episodes"

  # Script constants.
  APIKey      = '950C33BEABF4A965'           # API Key for TVDBApi
  APILanguage = 'en'                         # 2 char language code for API
  APITimeZone = 'EDT'                        # TimeZone for the TVDB API

  # String representation for how the air dates should be formatted
  DateFormat  = '%d/%m/%Y'
  HourFormat  = '%-l %P'

  # Hardcoded path for API: http://thetvdb.com/wiki/index.php?title=API:mirrors.xml
  MirrorPath  = 'http://thetvdb.com/'

  SearchURI   = "#{MirrorPath}api/GetSeries.php?seriesname=%s"
  SeriesURI   = "#{MirrorPath}api/#{APIKey}/series/%s/#{APILanguage}.xml"
  LookupURI   = "#{MirrorPath}api/#{APIKey}/series/%s/all/#{APILanguage}.xml"

  # Toggles whether commands can be used to modify the cached list of shows
  EnableEdit  = true

  def loaded
    # Initialize the shows array for caching search results
    cache[:shows] ||= []
  end

  command %w{next episode tvnext series} do |user, channel, args|
    unless args
      next channel.say format "Usage:\x0F .next <query>"
    end

    if EnableEdit

      arguments = args.split

      cmd = arguments.shift

      case cmd
      # List Shows
      when 'list' 

        # use the remaining arguments as a filter if given
        shows = arguments.empty? ? cache[:shows] : search_cache(arguments.join)

        # group lines by 8 shows each
        groups = shows.each_slice 8

        groups.each do |group|
          line = ""

          group.each do |show|
            line += " \x02#{show[:name]}\x02 \x0310(\x0F#{show[:id]}\x0310)\x0F"

            unless show.equal? group.last 
              line += "\x0310 -\x0F"
            end
          end

          channel.say format "Shows:\x0F#{line}"
        end

        next

      # Add Alias for show
      when 'add'
        if arguments.length < 2 or not /^\d+$/.match arguments.first
          next channel.say format "Usage:\x0F .next add <id> <alias>"
        end

        # first argument is the id, just shift it out of the array
        id = arguments.shift
 
        # alias is the remaining arguments
        show_alias = arguments.join

        # if the show is cached, just alter the entry
        if show = show_by_id(id)
          show[:alias] = show_alias

          channel.say format "Added:\x0F \"\x02#{show[:name]}\x0F\" with alias \"\x02#{show[:alias]}\x0F\""
         
        # otherwise look it up
        else

          context = http.get SeriesURI % id

          context.success do
            begin
              xml = Nokogiri::XML(context.response.to_s)

              show = parse_show(xml)

              if show
                show[:alias] = show_alias 

                cache[:shows] << show

                channel.say format "Added:\x0F \"\x02#{show[:name]}\x0F\" with alias \"\x02#{show[:alias]}\x0F\""
              else
                channel.say format "No show with that ID"
              end

            rescue Exception => e
              p "#{e.message} - #{e.class.to_s}"
              p e.backtrace

              channel.say format 'An error occured in the lookup'
            end
          end

          context.error do
            channel.say format 'An error occured in the lookup'
          end
        end

        next

      # remove show from the list
      when 'remove' 
        if arguments.empty? or not /^\d+$/.match arguments.first
          next channel.say format "Usage:\x0F .next remove <id>"
        end

        show = show_by_id arguments.first

        if show
          cache[:shows].delete show
          channel.say format "#{show[:name]}\x0F Removed from cache"
        end

        next
      end

    end

    search args do |result|

      if result
        lookup result do |series|

          if series
            response = "#{ series[:name] }\x0F - "

            if series[:last_episode]
              response += "\x0310Latest %s " % format_episode(series[:last_episode])
            end

            if series[:next_episode]
              response += "\x0310Next %s " % format_episode(series[:next_episode])
            end

            if series[:network]
              response += "\x0310Network:\x0F #{ series[:network] } "
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
    cache[:shows].select {|s| s[:name].downcase.include? query.downcase or s[:alias].downcase.include? query.downcase }
  end

  def show_by_id id
    cache[:shows].find {|s| s[:id] == id }
  end

  def exists? id
   show_by_id id
  end
  
  def search query

    shows = search_cache query

    # if we found the show in the cache, we just yield that here
    if shows.any?

      yield shows.first

    # otherwise look it up on TVDBApi
    else

      search_uri = SearchURI % URI.escape(query)
      context = http.get search_uri

      context.success do 
        begin
          xml = Nokogiri::XML(context.response.to_s)

          show = parse_show(xml)

          if show
         
            # we gain nothing from caching multiple instances of the same show
            # and searching the cache might not be as reliable as searching tvdb
            # so we need to make sure the show doesnt exist in the cache
            unless exists? show[:id]
              # cache the result
              cache[:shows] << show
            end

            yield show

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

  def lookup show
    lookup_uri = LookupURI % show[:id]

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
        now    = Time.now.utc + Time.zone_offset(APITimeZone)

        last_episode = nil
        next_episode = nil

        episodes = xml.css('Data Episode')

        # Reverse through the episode list to get the newest episodes first
        # This is due to some of the older entries in tvdb not having sufficient information
        episodes.reverse_each do |episode|

            # We dont care about specials
            next if episode.css('SeasonNumber').first.text == '0'

            aired = airtime episode, clock

            # no point in looking for next episode if the series have ended
            if status != 'Ended' and (not aired or aired >= now)
                next_episode = episode

                next
            end

            # just continue overriding while we havent got the last episode
            if aired and aired < now
                last_episode = episode

                # break out of loop if we find the last episode
                break
            end
        end

        # return the result
        yield({
            :name         => name,
            :runtime      => runtime,
            :status       => status,
            :network      => show[:network],
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

  def parse_show xml
    results = xml.css('Series')

    return nil if not results.any?

    # get the first result in the list
    series = results.first

    # information saved for caching purposes
    name = series.css('SeriesName').first.text
    id   = series.css('id').first.text
    network = series.css('Network').first.text

    {:id => id, :name => name, :network => network, :alias => ''}
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

  def time_since timestamp
    return [nil, nil] unless timestamp
    # get local time
    now = Time.now
    difference = now - timestamp
    future = difference < 0
    difference = difference.abs

    today = now.to_date

    day    = 24 * 60 * 60
    week   = 7  * day

    s = ""

    if timestamp.to_date == today.next_day
      s = "tomorrow"
    elsif timestamp.to_date == today.prev_day
      s = "yesterday"
    elsif timestamp.to_date == today
      s = "today"
    elsif difference > day and difference < week
      s = (future ? "" : "last ") + timestamp.strftime('%A').downcase
    else
      s = timestamp.strftime(DateFormat)
    end

    if future
      s += " at #{timestamp.strftime(HourFormat)}"
    end
    [s, future]
  end

  def airtime episode, clock
    aired = episode.css('FirstAired').first.text
    return if aired == ""
    Time.parse(aired + " #{clock} #{APITimeZone}").getlocal
  end

  def format_episode episode

    aired, future = time_since episode[:airtime]

    "\x0310(\x0F#{episode[:season].rjust(2, '0')}x#{episode[:episode].rjust(2, '0')}\x0310):\x0F #{episode[:name]}" + (aired ? ", \x0310#{future ? 'airs' : 'aired'}\x0F #{aired}" : "")
  end
  
  def format message
    %{\x0310>\x0F \x02TV:\x02\x0310 #{message}}
  end
end

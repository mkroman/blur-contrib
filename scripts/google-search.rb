# encoding: utf-8

require 'oj'
require 'multi_json'
require 'htmlentities'

Script :google_search, uses: %w{http}, includes: [Commands] do
  Author "Mikkel Kroman <mk@uplink.io>"
  Version "0.1"
  Description "Provides a method to search google"

  # Script constants.
  SearchURI = "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=%s&rsz=1"

  def loaded
    # Initialize the HTML entities decoder
    @decoder = HTMLEntities.new
  end

  command %w{g google} do |user, channel, args|
    unless args
      return channel.say format "Usage:\x0F .g <query>"
    end

    search args do |title, uri|
      if title
        channel.say format "#{@decoder.decode title}\x0F - #{uri}"
      else
        channel.say format "No results"
      end
    end    
  end
  
  def search query
    search_uri = SearchURI % URI.escape(query)
    context = http.get search_uri, format: :json

    context.success do
      begin
        if context.response['responseStatus'] != 200
          return yield nil
        end

        results = context.response['responseData']['results']

        if results.any?
          result = results.first

          yield result['titleNoFormatting'], result['unescapedUrl']
        else
          yield nil
        end
      rescue Exception => e
        yield e.message, e.class.to_s
        p e.backtrace
      end
    end

    context.error do
      yield nil
    end
  end
  
  def format message
    %{\x0310>\x0F \x02Google:\x02\x0310 #{message}}
  end
end

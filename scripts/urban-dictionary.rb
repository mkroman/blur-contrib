# encoding: utf-8

Script :urban_dictionary, uses: %w{http}, includes: [Commands] do
  Author "Mikkel Kroman <mk@uplink.io>"
  Version "0.1"
  Description "Search for definitions on urbandictionary.com"

  # The search URI.
  ServiceURI = "http://api.urbandictionary.com/v0/define?term=%s"

  command :urban do |user, channel, args|
    search args do |results|
      if results
        result = results.first 

        output = "Term:\x0F #{result['word']}\x0310 "
        output << "Definition:\x0F #{result['definition'].gsub(/\n/, ' ')}\x0310 " if result['definition']
        output << "Example:\x0F #{result['example'].gsub(/\n/, ' ')}\x0310" if result['example']

        channel.say format output
      else
        channel.say format 'No results'
      end
    end
  end

  def search query
    uri = ServiceURI % URI.escape(query)
    context = http.get uri, format: :json

    context.success do
      if context.response['result_type'] == 'exact'
        yield context.response['list']
      else
        yield false
      end
    end

    context.error do
      yield false
    end
  end

  def format message
    %{\x0310>\x0F\x02 Urban Dictionary:\x02\x0310 #{message}}
  end
end

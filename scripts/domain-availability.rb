# encoding: utf-8

require 'oj'
require 'multi_json'
require 'htmlentities'

Script :domain_availability, using: %w{http}, includes: [Commands] do
  Author "Ole Bergmann <ole@ole.im>"
  Version "0.1"
  Description "Search for domain availability"

  # Script constants.
  API_KEY   = "" # FreeDomainAPI.com API Key
  LookupURI = "http://freedomainapi.com/?key=#{API_KEY}&domain=%s"
  DomainTaken = "\x034Taken\x0F"
  DomainAvailable = "\x033Available\x0F"

  # Register the .taken command.
  command %w{taken} do |user, channel, args|
    unless args
      return channel.say format "Usage:\x0F .taken <domain>"
    end

    lookup args do |domain, available|

      channel.say format "#{domain}\x0F - #{available ? DomainAvailable : DomainTaken}"
    end    
  end

  # Lookup a domain.
  #
  # @yields [Domain, Available] or nil
  def lookup domain
    lookup_uri = LookupURI % URI.escape(domain)
    context = http.get lookup_uri, format: :json

    context.success do
      begin

        if context.response['status'] == 'success'
          yield context.response['domain'], context.response['available']
        else
          return yield nil
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
    %{\x0310>\x0F \x02\x0310#{message}}
  end
end

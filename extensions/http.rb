# encoding: utf-8

require 'em-http-request'
require 'em-http/middleware/json_response'

# The +http extension+ is a simple event-driven HTTP interface for scripts
#
# @example
#   context = http.get "http://www.google.com/"
#
#   context.success do
#     puts "#{context.response}"
#   end
#   
#   context.error do
#     puts "Connection failed"
#   end
Extension :http do
  Author "Mikkel Kroman <mk@uplink.io>"
  Version "0.1"
  Description "Provides a simple event-driven HTTP interface for scripts"

  # +HTTPContext+ is a DSL wrapper around em-http.
  class HTTPContext
    # Initialize the wrapper.
    def initialize client
      @client = client
    end

    # Set the request callback proc.
    def success &block
      @client.callback do
        if response_header.successful?
          begin
            block.call
          rescue Exception => exception
            p exception
          end
        else
          @client.fail "expected response code 200"
        end
      end
    end

    # Set the request error proc.
    def error &block
      @client.errback do
        begin
          block.call
        rescue Exception => exception
          p exception
        end
      end
    end

    # @returns The HTTP response.
    def response
      @client.response
    end

    # @returns The HTTP response header.
    def response_header
      @client.response_header
    end
  end

  # Return a new http context with a newly initiated get request.
  #
  # @option options [optional, Symbol] :format The response format, can be :json.
  def get uri, *params, &block
    options    = params.last.is_a?(Hash) ? params.pop : {}
    connection = create_connection uri, options
    request    = connection.get *params

    HTTPContext.new(request).tap do |context|
      context.instance_eval &block if block_given?
    end
  rescue => exception
    p exception
  end

  # Return a new http context with a newly initiated post request.
  #
  # @option params [optional, String] :body The POST data.
  # @option options [optional, Symbol] :format The response format, can be :json.
  def post uri, *params, &block
    options    = params.last.is_a?(Hash) ? params.pop : {}
    connection = create_connection uri, options
    request    = connection.post *params
    
    HTTPContext.new(request).tap do |context|
      context.instance_eval &block if block_given?
    end

  rescue => exception
    p exception
  end

  def create_connection uri, options
    connection = EM::HttpRequest.new uri

    case options[:format]
    when :json
      connection.use EM::Middleware::JSONResponse
    end

    connection
  rescue => exception
    p exception
  end
end
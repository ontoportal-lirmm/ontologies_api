module Rack
  class ContentNegotiation
    DEFAULT_CONTENT_TYPE = "application/n-triples" # N-Triples
    VARY = { 'Vary' => 'Accept' }.freeze

    # @return [#call]
    attr_reader :app

    # @return [Hash{Symbol => Object}]
    attr_reader :options

    ##
    # @param  [#call]                  app
    # @param  [Hash{Symbol => Object}] options
    #   Other options passed to writer.
    # @option options [String] :default (DEFAULT_CONTENT_TYPE) Specific content type
    # @option options [RDF::Format, #to_sym] :format Specific RDF writer format to use
    def initialize(app, options = {})
      @app, @options = app, options
      @options[:default] = (@options[:default] || DEFAULT_CONTENT_TYPE).to_s
    end

    ##
    # Handles a Rack protocol request.
    # Parses Accept header to find appropriate mime-type and sets content_type accordingly.
    #
    # Inserts ordered content types into the environment as `ORDERED_CONTENT_TYPES` if an Accept header is present
    #
    # @param  [Hash{String => String}] env
    # @return [Array(Integer, Hash, #each)] Status, Headers and Body
    # @see    https://rubydoc.info/github/rack/rack/file/SPEC
    def call(env)
      if env['PATH_INFO'].match?(%r{^/ontologies/[^/]+/resolve/[^/]+$})
        if env.has_key?('HTTP_ACCEPT')
          accepted_headers = parse_accept_header(env['HTTP_ACCEPT'])
          if !accepted_headers.empty?
            env["format"] = accepted_headers[0]
            response = app.call(env)
            response[1] = response[1].merge(VARY).merge('Content-Type' => accepted_headers[0])
            response
          else
            not_acceptable
          end
        else
          env["format"] = @options[:default]
          response = app.call(env)
          response[1] = response[1].merge(VARY).merge('Content-Type' => "application/n-triples")
          response
        end
      else
        app.call(env)
      end
    end

    protected

    ##
    # Parses an HTTP `Accept` header, returning an array of MIME content
    # types ordered by the precedence rules defined in HTTP/1.1 §14.1.
    #
    # @param  [String, #to_s] header
    # @return [Array<String>]
    # @see    https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
    def parse_accept_header(header)
      entries = header.to_s.split(',')
      entries = entries.map { |e| accept_entry(e) }.sort_by(&:last).map(&:first)
      entries.map { |e| find_content_type_for_media_range(e) }.flatten.compact
    end

    # Returns pair of content_type (including non-'q' parameters)
    # and array of quality, number of '*' in content-type, and number of non-'q' parameters
    def accept_entry(entry)
      type, *options = entry.split(';').map(&:strip)
      quality = 0 # we sort smallest first
      options.delete_if { |e| quality = 1 - e[2..-1].to_f if e.start_with? 'q=' }
      [options.unshift(type).join(';'), [quality, type.count('*'), 1 - options.size]]
    end

    ##
    # Returns a content type appropriate for the given `media_range`,
    # returns `nil` if `media_range` contains a wildcard subtype
    # that is not mapped.
    #
    # @param  [String, #to_s] media_range
    # @return [String, nil]
    def find_content_type_for_media_range(media_range)
      case media_range.to_s
      when '*/*'
        options[:default]

      when 'text/*'
        options[:default]

      when 'application/n-triples'
        'application/n-triples'

      when 'text/turtle'
        'text/turtle'

      when 'application/*'
        'application/ld+json'

      when 'application/json'
        'application/ld+json'

      when 'application/ld+json'
        'application/ld+json'

      when 'application/xml'
        'application/rdf+xml'

      when 'application/rdf+xml'
        'application/rdf+xml'

      when 'text/xml'
        'application/rdf+xml'

      when 'text/rdf+xml'
        'application/rdf+xml'

      else
        nil
      end
    end

    ##
    # Outputs an HTTP `406 Not Acceptable` response.
    #
    # @param  [String, #to_s] message
    # @return [Array(Integer, Hash, #each)]
    def not_acceptable(message = nil)
      http_error(406, message, VARY)
    end

    ##
    # Outputs an HTTP `4xx` or `5xx` response.
    #
    # @param  [Integer, #to_i]         code
    # @param  [String, #to_s]          message
    # @param  [Hash{String => String}] headers
    # @return [Array(Integer, Hash, #each)]
    def http_error(code, message = nil, headers = {})
      message = http_status(code) + (message.nil? ? "\n" : " (#{message})\n")
      [code, { 'Content-Type' => "text/plain" }.merge(headers), [message]]
    end

    ##
    # Returns the standard HTTP status message for the given status `code`.
    #
    # @param  [Integer, #to_i] code
    # @return [String]
    def http_status(code)
      [code, Rack::Utils::HTTP_STATUS_CODES[code]].join(' ')
    end
  end
end

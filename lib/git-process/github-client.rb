require 'octokit'

module Octokit

  module Connection

    #
    # Unfortunately, there's no way to change the URL except by completely replacing
    # this method.
    #
    def connection(authenticate=true, raw=false, version=3, force_urlencoded=false)
      if site
        url = site
      else
        case version
        when 2
          url = "https://github.com"
        when 3
          url = "https://api.github.com"
        end
      end

      options = {
        :proxy => proxy,
        :ssl => { :verify => false },
        :url => url,
      }

      options.merge!(:params => {:access_token => oauth_token}) if oauthed? && !authenticated?

      connection = Faraday.new(options) do |builder|
        if version >= 3 && !force_urlencoded
          builder.request :json
        else
          builder.request :url_encoded
        end
        builder.use Faraday::Response::RaiseOctokitError
        unless raw
          builder.use FaradayMiddleware::Mashify
          builder.use FaradayMiddleware::ParseJson
        end
        builder.adapter(adapter)
      end
      connection.basic_auth authentication[:login], authentication[:password] if authenticate and authenticated?
      connection
    end
  end

end


class GitHubClient < Octokit::Client

  def site
    @site
  end


  def site=(new_site)
    @site = new_site
  end


  alias :old_request :request

  def request(method, path, options, version, authenticate, raw, force_urlencoded)
    if site
      path = "/api/v3#{path}"
    end
    old_request(method, path, options, version, authenticate, raw, force_urlencoded)
  end

end

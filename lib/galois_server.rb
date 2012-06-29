require 'rack'
require 'rack_monkey'
require 'sinatra/base'

module GaloisServer
  class HTTPConnection < Sinatra::Base
    get '/' do
      "Rock On!"
    end
  end
end

module GaloisServer
  extend self
  
  def start(options = {})
    @app = Rack::Builder.new {
      use Rack::Lint
      use Rack::ShowExceptions
      run Rack::Cascade.new([GaloisServer::HTTPConnection])
    }.to_app
    
    Rack::Handler::Unicorn.run(@app, options)
  end
end

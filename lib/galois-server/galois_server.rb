require 'rack'
require 'rack_monkey'
require 'sinatra/base'
require 'redis'

module GaloisServer
  class HTTPConnection < Sinatra::Base
    
    get '/hosts' do
      Redis.current.smembers("galois:hosts")
    end
    
    get '/increment' do
      Redis.current.set("counter", Redis.current.get("counter").to_i + 1)
      Redis.current.get("counter")
    end
    
    get '/print' do
      Redis.current.get("counter")
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

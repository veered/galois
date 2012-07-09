require 'rack'
require 'rack_monkey'
require 'sinatra/base'
require 'redis'
require 'redis-namespace'
require 'json'
require 'v8'

module GaloisServer
  class HTTPConnection < Sinatra::Base
    rd = Redis::Namespace.new(:galois, :redis => Redis.current)
    cxt = V8::Context.new
    
    get /\/([^\/]*)/ do begin
      params[:filter] ||= "true"
      entity_name = params["captures"].first
    
      collection = []
      rd.hget("entities", entity_name).to_i.times do |index|
        cxt['fields'] = fields = rd.hgetall("#{entity_name}::#{index}")
        collection << fields if cxt.eval(params[:filter])
      end
      
      collection.to_json
      
    rescue V8::JSError
      { :error => "Invalid filter:\n#{$!}" } }.to_json
    end end
    
  end
end

module GaloisServer
  extend self
  
  def start(config = {})
    @app = Rack::Builder.new {
      use Rack::Lint
      use Rack::ShowExceptions
      run Rack::Cascade.new([GaloisServer::HTTPConnection])
    }.to_app
    
    Rack::Handler::Unicorn.run(@app, config)
  end
  
end

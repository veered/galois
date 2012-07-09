require 'redis'
require 'redis-namespace'
require 'eventmachine'
require 'json'
require 'logger'

class GaloisScraper
  attr_accessor :config, :logger, :redis, :icinga_status, :prd
  
  def initialize(config, logger = Logger.new(nil))
    @config = {
        :host_fields  => [],
        :service_fields  => []
      }.merge config
    
    @logger = logger
    
    @redis = {
      :fd => Redis.current,
      :ns => Redis::Namespace.new(:galois, :redis => Redis.current)
    }
    
    File.open(@config[:icinga_config]).each{ |line| @icinga_status = $1 if line.match(/status_file=(.*)/) }.close
    File.open(@config[:prd]) {|file| @prd = JSON.parse(file.read)}
    
  rescue
    @logger.error("Had some trouble with initialization:\n#{$!}")
  end
  
  def start
    parse
    EM.run { EM.add_periodic_timer(@config[:refresh]) {parse} }
  end
  
  def parse
    status = File.open(@icinga_status) {|file| file.read}
    
    @redis[:ns].del("entities")
    parse_entity(status, "hoststatus", @config[:host_fields], &method(:add_prd))
    parse_entity(status, "servicestatus", @config[:service_fields], &method(:add_prd))
    
  rescue
    @logger.error("There were some issues with parsing and persisting the status data:\n#{$!}\n#{$@}")
  end
  
  def parse_entity(source, entity_name, fields)    
    source.scan(/#{entity_name} {(.*?)}/m).flatten.each do |entity|
      index = @redis[:ns].hincrby("entities", "#{entity_name}", 1) - 1
      key = "#{entity_name}::#{index}"
          
      @redis[:ns].del(key)
      fields.each { |field| if value = parse_field(entity, field) then @redis[:ns].hmset(key, field, value) end }
      
      yield key if block_given?
    end
  end
  
  def parse_field(entity, field)
    field_name = entity.match(/#{field}=(.*)/) {$1}
    
  ensure
    @logger.warn("Found no field named #{field} in entity:\n#{entity}") if field_name.nil?
  end
  
  def add_prd(key)
    @redis[:ns].hset(key, "isPrd?", @prd.include?(@redis[:ns].hget(key, "host_name")))
  end
  
end
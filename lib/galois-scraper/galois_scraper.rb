require 'redis'
require 'redis-namespace'
require 'eventmachine'
require 'ruby-debug'

class Scraper
  attr_accessor :redis, :config, :icinga_status
  
  def initialize(config)
    @config = config
    
    # Initialize redis
    @redis = {
      :fd => Redis.current,
      :ns => Redis::Namespace.new(:galois, :redis => Redis.current)
    }
  
    # Locate status.dat
    File.open(@config[:icinga_config]).each do |line|
      if line.match(/status_file=(.*)/)
        @icinga_status = $1
      end
    end.close

  end
  
  def start
    EM.run {
      EM.add_periodic_timer(@config[:refresh]) {parse}
    }
  end
  
  def parse
    status_string = File.open(@icinga_status) {|file| file.read}
    
    status_string.scan(/servicestatus {(.*?)}/m).flatten.each do |service|
      # Parse host_name
      host_name = service.match(/host_name=(.*)/) {$1}
      # next unless `knife node show #{host_name} -a chef_environment` =~ /chef_environment: stg/
      @redis[:ns].sadd("hosts", host_name)
      @redis[:ns].expire("hosts", @config[:refresh])
    
      # Parse service_name
      service_name = service.match(/service_description=(.*)/) {$1}
      @redis[:ns].sadd("#{host_name}#services", service_name)
      @redis[:ns].expire("#{host_name}#services", @config[:refresh])
    
      # Parse @config[:fields]
      @config[:fields].each do |field|
        if service.match(/#{field}=(.*)/)
          @redis[:ns].hmset("#{host_name}::#{service_name}", field, $1)
          @redis[:ns].expire("#{host_name}::#{service_name}", @config[:refresh])
        end
      end
      
    end
      
  end
  
end

if __FILE__ == $0
  config = {:icinga_config  => "/galois/icinga.cfg", 
            :refresh  => 10, 
            :fields  => ["current_state"]}
  Scraper.new(config).start
end
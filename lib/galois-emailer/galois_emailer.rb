require 'action_mailer'
require 'eventmachine'
require 'logger'
require 'net/http'
require 'json'

class GaloisEmailer
  attr_accessor :config, :logger
  
  def initialize(config, logger = nil)
    @config = config
    @logger = logger || Logger.new(nil)
    
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = @config[:smtp_settings]
    
    ActionMailer::Base.view_paths = File.dirname(__FILE__)
  end
  
  def start
    EM.run {
      time = @config[:time] - Time.now
      time += 15 if time < 0
      
      run_me = proc {
        notify
        EM.add_timer(15, run_me)
      }
      
      EM.add_timer(time, run_me)
    }
  end
  
  class Notifier < ActionMailer::Base
    def deploy_notification(sender, recipient, hosts, services)
      @hosts = hosts
      @services = services
      mail(
        :from  => sender,
        :to  => recipient,
        :subject  => "Icinga Services w/ Disabled Notifications",
        :template_path  => '',
        :template_name  => 'notification'
      )
    end
  end
  
  def get_entity(entity_name)
    uri = URI(@config[:server] + "/#{entity_name}")
    uri.query = URI.encode_www_form({:filter  => "fields['isPrd?']=='true' && fields['notifications_enabled']=='0'"})
    
    result = Net::HTTP.get_response(uri)
    raise Exception("The request to #{uri} failed.") unless result.is_a?(Net::HTTPSuccess)
    
    JSON.parse(result.body)
    
  rescue
    @logger.error("Unable to retrieve entity:\n$!")
    []
  end
  
  def notify    
    hosts = get_entity("hoststatus")
    services = get_entity("servicestatus")
    
    unless hosts.empty? and services.empty?
      @config[:subscribers].each do
        email = Notifier.deploy_notification(@config[:smtp_settings][:user_name], "lucashansen@gmail.com", hosts, services)
        email.deliver
      end
    else
      @logger.info("No hosts or services were found.")
    end
  end
  
end
require 'action_mailer'
require 'eventmachine'
require 'logger'
require 'net/http'
require 'json'

# Sends out periodic emails about hosts and services which pass some configurable filter.
class GaloisEmailer
  attr_accessor :config, :logger
  
  # @param [Hash] config
  # @option config [String] :server The http address of the REST service provided by galois-server.
  # @option config [String] :filter A boolean javascript expression which determines which hosts and filters are in the notification.
  # @option config [Array] :subscribers A list of email addresses to notify.
  # @option config [Integer] :time The time of day that the notification should be sent.
  # @option config [String] :subject The text that should appear in the subject line of the notification.
  # @option config [String] :template The name of the template in the conf folder that should be used to render the email.
  # @option config [Hash] :smtp_settings Settings needed to connect galois-emailer to an SMTP server from which it can send email. See the ActionMailer documentation for more information.
  # @param [Logger] logger An instance of Logger which GaloisEmailer will write to.
  def initialize(config, logger = nil)
    @config = config
    @logger = logger || Logger.new(nil)
    
    @config[:filter] ||= "fields['isPrd?']=='true' && fields['notifications_enabled']=='0'"
    
    ActionMailer::Base.raise_delivery_errors = true
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = @config[:smtp_settings]
    
    ActionMailer::Base.view_paths = File.dirname(__FILE__)
  end

  # Sends an email at config[:time] every day
  def start
    EM.run {
      time = @config[:time] - (Time.now.hour*60*60 + Time.now.min*60 + Time.now.sec)
      time += 86000 if time < 0
      
      run_me = proc {
        notify
        EM.add_timer(86000, run_me)
      }
      
      EM.add_timer(time, run_me)
    }
  end
  
  class Notifier < ActionMailer::Base
    # Sends out the notification
    def deploy_notification(config = {})
      @hosts = config[:hosts]
      @services = config[:services]
      mail(config[:mail])
    end
  end
  
  # Queries the server for entities which pass the filter
  def get_entity(entity_name)
    uri = URI(@config[:server] + "/#{entity_name}")
    uri.query = URI.encode_www_form({:filter  => @config[:filter]})
    
    result = Net::HTTP.get_response(uri)
    raise Exception("The request to #{uri} failed.") unless result.is_a?(Net::HTTPSuccess)
    
    JSON.parse(result.body)
    
  rescue
    @logger.error("Unable to retrieve entity:\n#{$!}")
    []
  end
  
  # Retrieves the list of hosts and services which pass the filter, and sends out this list in an email.
  def notify    
    hosts = get_entity("hoststatus")
    services = get_entity("servicestatus")
    
    unless hosts.empty? and services.empty?
      @config[:subscribers].each do |subscriber|
        email = Notifier.deploy_notification({
          :hosts   => hosts,
          :services  => services,
          :email  => {
            :from  => @config[:smtp_settings][:user_name],
            :to  => subscriber,
            :subject  => @config[:subject],
            :template_path  => @config[:conf_dir],
            :template_name  => @config[:template]
          }
        })

        email.deliver
      end
    else
      @logger.info("No hosts or services were found.")
    end
  end
  
end
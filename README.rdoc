= galois

A set of simple utilities that make interacting with Icinga a bit simpler.

== Basics

There are three main parts to galois:
1. *galois-scraper* - Periodically parses Icinga's status logs and stores this information in Redis.
2. *galois-server* - A REST service for searching the information scraped from Icinga by galois-scraper.
3. *galois-emailer* - An example client of galois-server which sends out a daily reminder of the Icinga hosts and services whose notifications are currently disabled.
	
In order for any of these services to work, an instance of Redis must be running.
	
There are two directories that are important to the operation of galois.
1. *conf* - This directory must be passed as the only argument to galois-scraper, galois-server, and galois-emailer. It must contain three files: galois.config, production-machines, notification.html.erb.
2. *log* - This is the directory where galois places its logs. Configured in galois.config.
		
For examples of these files see the config folder.		

== galois-scraper

    $ galois-scraper galois-conf-dir

Requires production-machines in the conf folder. This should be a JSON list of the host-names of production machines.

*Properties*:
* host_fields - A list containing the names of fields about a host that should be scraped from the log file.
* service_fields - Same as above, but for services rather than hosts.
* icinga_config - An absolute path to Icinga's "icinga.cfg" file. Usually located at "/etc/icinga/icinga.cfg".
* refresh - The amount of time, in seconds, between log scrapings.
	
== galois-server
	
    $ galois-server galois-conf-dir
	
*Properties*:
* host - The hostname on which the service will be hosted.
* port - The port on which the service will be hosted.
	
== galois-emailer

    $ galois-server galois-conf-dir

Requires notification.html.erb in the conf folder. This should just be a standard ERB template, with access to the variables @hosts and @services which contain the hosts and services with disabled notifications.

*Properties*:
* server - The http address of the REST service provided by galois-server.
* subscribers - A list of email addresses to notify.
* time - The time of day that the notification should be sent.
* subject - The text that should appear in the subject line of the notification.
* template - The name of the template in the conf folder that should be used to render the email. Above referenced as notification.html.erb, but this need not be the name.
* smtp_settings - Settings needed to connect galois-emailer to an SMTP server from which it can send email. See the ActionMailer documentation for more information.

== Copyright

Copyright (c) 2012 Lucas Hansen. See LICENSE.txt for
further details.


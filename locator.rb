#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'beanstalk-client'
require 'mysql2'
require 'choice'
require 'geoip'

Choice.options do
  header ''
  header 'Specific options:'

  option :mysql_host do
    short '-h'
    long '--mysql_host=HOST'
    desc 'Hostname or ip of the mysql server. The default is 127.0.0.1'
    default '127.0.0.1'
  end

  option :mysql_port do
    short '-p'
    long '--mysql_port=PORT'
    desc 'The port the mysql server listens to of the mysql server. The default is 3306'
    cast Integer
    default 3306
  end

  option :mysql_uname do
    short '-u'
    long '--mysql_username=USERNAME'
    desc 'The username  for the mysql database, default is infologger'
    default 'infologger'
  end

  option :mysql_password do
    short '-P'
    long '--mysql_password=PASSWORD'
    desc 'The password for the mysql database. The default is infologger123'
    default 'infologger123'
  end

  option :mysql_database do
    short '-d'
    long '--mysql_db=dbname'
    desc 'The port the mysql server listens to of the mysql server. The default is LOGINFO'
    default 'LOGINFO'
  end

  option :beanstalk_port do
    short '-B'
    long '--beanstalk_port=PORT'
    desc 'The port the beanstalk server listens to'
    cast Integer
    default 11300
  end

  option :beanstalk_host do
    short '-H'
    long '--beanstalk_host=HOST'
    desc 'The host address the beanstalkd server listens to. The default is 127.0.0.1'
    default '127.0.0.1'
  end

  option :mail_from do
    short '-m'
    long '--mail_from=MAIL'
    desc 'The from address for the alert.The default mail from address is admin@test.in '
    default 'admin@test.in'
  end


end
pwd = File.expand_path File.dirname(__FILE__)

@geoip ||= GeoIP.new("#{pwd}/GeoLiteCity.dat")
#@con = Mysql2::Client.new(:host=>'192.168.1.98', :username=>'testuser', :password=>'test123', :database=>'testdb')
@con = Mysql2::Client.new(:host=>"#{Choice[:mysql_host]}", :port=>Choice[:mysql_port], :username=>"#{Choice[:mysql_host]}", :password=>"#{Choice[:mysql_password]}", :database=>"#{Choice[:mysql_databse]}")
@beanstalk = Beanstalk::Pool.new(["#{Choice[:beanstalk_host]}:#{Choice[:beanstalk_port]}"])
@beanstalk.watch('locationtube')

loop do
  job = @beanstalk.reserve # waits for a job

  data_json = JSON.parse(job.body)

  ip = "#{data_json['ip']}" 
  username = "#{data_json['username']}" 
  llt = data_json['time_logged']
  service = data_json['service']
  location = @geoip.city("#{ip}").city_name

  @con.query("CREATE TABLE IF NOT EXISTS \
               LOGINFO1(Id INT PRIMARY KEY AUTO_INCREMENT, Ipaddress  VARCHAR(25), Username  VARCHAR(25), LoginTime VARCHAR(25), Service VARCHAR(25), Location VARCHAR(25))")

  @con.query("INSERT INTO LOGINFO1(Ipaddress,Username,LoginTime,Service, Location) VALUES('#{ip}','#{username}','#{llt}','#{service}','#{location}')")


  @beanstalk1 = Beanstalk::Pool.new(["#{Choice[:beanstalk_host]}:#{Choice[:beanstalk_port]}"])
  @beanstalk1.use 'alerttube'
  @beanstalk1.put "#{username}" 

  job.delete # remove job after processing
end



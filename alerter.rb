#!/usr/bin/env ruby

require 'rubygems'
require 'beanstalk-client'
require 'mysql2'
require 'net/ldap'
require 'mail'
require 'choice'

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

@con = Mysql2::Client.new(:host=>"#{Choice[:mysql_host]}", :port=>Choice[:mysql_port], :username=>"#{Choice[:mysql_host]}", :password=>"#{Choice[:mysql_password]}", :database=>"#{Choice[:mysql_databse]}")
@beanstalk = Beanstalk::Pool.new(["#{Choice[:beanstalk_host]}:#{Choice[:beanstalk_port]}"])
@beanstalk.watch('alerttube')

def ldap_look(uid_user)
  ldap = Net::LDAP.new
  ldap.host = "localhost"
  ldap.port = "389"
  bdn   = File.open('/var/qmail/control/ldaplogin') {|f| f.readline}
  bpass =  File.open('/var/qmail/control/ldappassword') {|f| f.readline}
  base  =  File.open('/var/qmail/control/ldapbasedn') {|f| f.readline}
 
  bdn = bdn.chomp
  bpass = bpass.chomp
  base = base.chomp
  ldap.auth bdn, bpass

  filter = Net::LDAP::Filter.eq( "uid", "#{uid_user}" )
  ldap.search( :base => base,  :filter => filter, :return_result => true ) do |entry|
    return entry.mail
    end
  end

def send_alert(mail_id,mail_from,message_string)
  mail = Mail.new do
    from    "#{mail_from}"
    to      "#{mail_id}"
    subject  "ALERT LOGIN FROM UNUSUAL LOCATION"
    body     "#{message_string}"
  end
  mail.delivery_method :sendmail 

  mail.deliver!
  end


loop do
  job = @beanstalk.reserve # waits for a job

  username = job.body
    
  rs = @con.query("SELECT Location from LOGINFO1 where Username='#{username}' ORDER BY Id DESC limit 5")

  counts = Hash.new(0)
  rs.each do |row|
    loc = "#{row['Location']}"
    counts[loc] += 1
  end
#  puts "#{counts.inspect}"
  common_loc = counts.max_by { |k, v| v }[0]

  rs1 = @con.query("SELECT Location from LOGINFO1 where Username='#{username}' ORDER BY Id DESC limit 1")
  counts_new = Hash.new(0)
  rs1.each do |row|
    loc = "#{row['Location']}"
    counts_new[loc] += 1
  end
#  puts "#{counts.inspect}"
  last_loc = counts_new.max_by { |k, v| v }[0]

  if    common_loc.casecmp last_loc
    lr = ldap_look(username)
    lrs ='none'
    unless lr[0].nil? 
    lrs = lr[0].chomp
    end
    mail_from = Config[:mail_from]
    message_string = "Username #{username} has logged in from unusual location #{last_loc}"
    send_alert(lrs,Choice[:mail_from],message_string)
  end 

  job.delete # remove job after processing
end



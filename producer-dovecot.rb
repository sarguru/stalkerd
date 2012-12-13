#!/usr/bin/env ruby
require 'rubygems'
require 'beanstalk-client'
require 'json'
require 'choice'

Choice.options do
  header ''
  header 'Specific options:'

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

end

rip = ENV['IP']

user= ENV['user']
curr_time = Time.now.to_i
service = 'dovecot'


data = { 'ip' => "#{rip}", 'username' =>"#{user}", 'time_logged'=> curr_time, 'service' => "#{service}" }

data_json = data.to_json


@beanstalk = Beanstalk::Pool.new(["#{Choice[:beanstalk_host]}:#{Choice[:beanstalk_port]}"])
@beanstalk.use "locationtube"

@beanstalk.put "#{data_json}"


#ENV['GEM_PATH'] = "/usr/local/bundle"

require "bunny"
require "json"
require "date"
require "optparse"
require 'csv'


conn = Bunny.new("amqp://guest:guest@rabbit:5672")
conn.start
ch = conn.create_channel
q  = ch.queue("neubot",:durable => true)

options = {:repeat => nil, :millis => nil}

parser = OptionParser.new do|opts|
	opts.banner = "Usage: nuevo_producer.rb [options]"

	opts.on('-r', '--repeat repeat', 'Repeat') do |repeat|
		options[:repeat] = repeat.to_i;
	end

	opts.on('-m', '--millis millis', 'Millis') do |millis|
		options[:millis] = millis.to_i;
	end

	opts.on('-i', '--random_initial millis', 'Millis') do |millis|
		options[:initial] = millis.to_i;
	end

	opts.on('-f', '--random_final millis', 'Millis') do |millis|
		options[:final] = millis.to_i;
	end

	opts.on('-x', '--multiplier multiplier', 'Multiplier') do |multi|
		options[:multiplier] = multi.to_i;
	end

	opts.on('-n', '--noprint', 'NoPrint') do
		options[:noprint] = true;
	end

	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end

parser.parse!

if options[:repeat] == nil
	puts 'Repeat not given, defaulting to 1'
  options[:repeat] = 1
end

if options[:millis] == nil
	puts 'Millis not given, defaulting to 1000'
  options[:millis] = 1000
end

if options[:noprint] == nil
	puts 'Printing by default'
  options[:noprint] = false
else
	puts "--noprint set, not printing every line"
end

if ( (options[:initial] != nil && options[:final] == nil) ||
     (options[:final]   != nil && options[:initial] == nil) )
	puts 'ERROR: -i or -f not provided'
  exit
end

vez = 0

experimental_anterior = 0
n = Time.now.to_i

File.open('data/neubot_producer.csv').each do |line|
  begin
    campos = CSV.parse(line)[0]
  rescue
    puts "failed to write a point"
    next
  end
  objeto = {}
	
	if( options[:initial] )
		sleep_time = rand( options[:final]-options[:initial] ) + options[:initial]
		puts "sleeping randomly #{sleep_time}"
		sleep sleep_time / 1000.0
	elsif( options[:multiplier] )
		sleep_time = ((experimental - experimental_anterior)*options[:multiplier])
		puts "going to sleep #{sleep_time} seconds"
	  sleep sleep_time
	else
		sleep (options[:millis]) / 1000.0
	end

	timestamp = DateTime.now.strftime('%Q').to_i
	time_cassandra = Time.now

  objeto["creation_timestamp"] = timestamp
	#objeto["download_speed"] = campos[7].to_f
	objeto["download_speed"] = (campos[7].to_f/100).round(0)

  objeto_json = objeto.to_json
  ch.default_exchange.publish(objeto_json, :routing_key => q.name)
  vez = vez+1

	#experimental_anterior = experimental
  if options[:noprint]==false
		puts "#{vez}. '#{objeto_json}'"
	end

  break if( vez >= options[:repeat] )
end
puts "FINISHED!"

conn.close

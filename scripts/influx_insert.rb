#!/usr/bin/ruby
# encoding: utf-8

require "date"
require "optparse"
require 'influxdb'
require 'csv'

file = 	   '/root/data/neubot_influx.csv'
host = 	   'influx'
database = 'example'

influxdb = InfluxDB::Client.new database, host:host
influxdb.create_database(database)

puts "Connected to InfluxDB"

total = 0
failed_write = 0
data = Array.new

puts "Deleting from database example"
influxdb.query 'DELETE FROM speedtests'

# get current time
# puts "Waiting for second 45:"

# while ((Time.now.to_i)-45) % 120 != 0
# 	print 120 - (((Time.now.to_i)-45) % 120)
# 	sleep(1)
# end
# puts

exec_time = Time.now.to_i

File.open(file).each do |line|

	begin
		campos = CSV.parse(line)[0]
	rescue
		next
	end
	#puts "#{campos}"

	#if( total % 100 == 0)
	if( total == 360)
		if( total > 0 )
			begin
				influxdb.write_points(data)
        puts "INSERTED in DB example: information for the last hour"
				# puts "RUN PRODUCER NOW!"
				# sleep 15
				# puts "STARTING JAR"
				exit 0
			rescue => error
				puts error
			end
		end
		data = Array.new
	end

	begin
		data.push ({
			series: "speedtests",
		    values: {
					lon: campos[2].to_f,
					lat: campos[3].to_f,
					download_speed: (campos[7].to_f/100).round(0),
					upload_speed: (campos[13].to_f/100).round(0)
				},
				tags: {
					client_country: campos[1]
				},
		  	timestamp: (exec_time - (total*10))
			}
		)

	rescue => exception
    puts "caught exception #{exception}! "
		failed_write += 1
	end

	total += 1

end

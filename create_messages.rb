require 'bunny'
require 'json'

connection = Bunny.new(host: 'localhost')
connection.start

channel = connection.create_channel
channel.confirm_select

exchange = channel.topic('email_processing', durable: true)
routing_key = 'email.low'

msg = {
  'subject' => 'Welcome!!!',
  'from' => 'me@example.com',
  'to' => 'foo@example.com',
  'cc' => '',
  'bcc' => '',
  'html' => "<h1>#{Time.now}</h1>"
}.to_json

exchange.publish(msg, routing_key: routing_key)
if exchange.wait_for_confirms
  puts " [x] Sent #{routing_key}:#{msg}"
else
  puts " [x] Failed #{routing_key}:#{msg}"
end

# cleanup
channel.close
connection.close

require 'bunny'
require 'json'

connection = Bunny.new('amqp://guest:guest@10.0.2.2:5672')
connection.start

channel = connection.create_channel
channel.confirm_select

exchange = channel.topic('email_processing', durable: true)
routing_key = 'email.low'

10.times do
  mail = {
    'subject' => Time.now.to_s,
    'from' => 'me@example.com',
    'to' => 'foo@example.com',
    'cc' => '',
    'bcc' => '',
    'html' => "<h1>#{Time.now}</h1>"
  }

  msg = {
    'attributes' => mail,
    'email_recipient_id' => 1,
    'org_id' => 'd0283e01-b15a-40fc-a426-7aa729ed7697'
  }.to_json

  exchange.publish(msg, routing_key: routing_key, persistent: true)
  if exchange.wait_for_confirms
    puts " [x] Sent #{routing_key}:#{msg}"
  else
    puts " [x] Failed #{routing_key}:#{msg}"
  end
end

# cleanup
channel.close
connection.close

# ERFID: a rfid
# Copyright (C) 2015 Wesley Ellis
require 'json'
require 'faraday'
require 'nfc'
require "pi_piper"

## ERROR CODES
NO_TAG = -90
DISCONNECTED = -1

def read_config
  JSON.parse(File.read(File.join(File.dirname(__FILE__),"./config.json")))
end

def get_reader
  reader = NFC::Context.new.open(nil)
  log("Connected to #{reader.name}")
  return reader
rescue RuntimeError => e
  error(e)
end

def read_card(reader)
  tag = reader.poll(10,1)
  if tag == NO_TAG
    return nil
  elsif tag == DISCONNECTED
    error("Card reader error, shutting down")
  else
    return tag.to_s
  end
end

def send_card(card_number, config)
  Faraday.post(
    config["url"],
    { rfid: card_number }
  )
end

def log(message)
  puts "#{Time.now} | #{message}"
end

def error(message)
  log("ERROR: " + message)
  exit(-1)
end

def display_success
  @green_led ||= PiPiper::Pin.new(:pin => 23, :direction => :out)
  3.times do
    @green_led.on
    sleep(0.5)
    @green_led.off
  end
end

def display_error
  @red_led ||= PiPiper::Pin.new(:pin => 24, :direction => :out)
  3.times do
    @red_led.on
    sleep(0.5)
    @red_led.off
  end
end

#catch interupt and log shutdown
trap('INT') {
  log("Shutting down")
  exit
}

#######################################
#######################################
#                                     #
#             MAIN STUFF HERE         #
#                   |                 #
#                   |                 #
#                   V                 #
#                                     #
#######################################
#######################################

def main
  log("Staring up!")
  config = read_config()
  reader = get_reader()

  loop do
    begin
      card = read_card(reader)

      next unless card #failed to read card

      log("Read card: #{card}")

      response = send_card(card, config)

      if response.success?
        log("Successfully sent #{card}")
        display_success() #takes 1.5 seconds
      else
        log("ERROR: got #{response.status} sending #{card}: #{response.body}")
        display_error() #takes 1.5 seconds
      end
    rescue Faraday::ConnectionFailed
      log("ERROR: No network connection")
    end
  end
end

# IT'S GO TIME
main()

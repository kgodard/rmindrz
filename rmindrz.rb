#!/usr/bin/env ruby
require 'rubygems'
require 'dm-core'
require 'dm-migrations'
require 'twilio-ruby'

DataMapper.setup( :default, "sqlite3://#{Dir.pwd}/test1.db" )

class Reminder
  include DataMapper::Resource

  Reminder.property(:id, Serial)
  Reminder.property(:what, String, :required => true)
  Reminder.property(:when, Integer, :required => true)
  Reminder.property(:for, String, :required => true)
end

DataMapper.finalize
DataMapper.auto_upgrade!

def twilio_number
  '+17203585401'
end

def account_sid
  'ACf48a3e426c050c011e66cd788e217354'
end

def auth_token
  '65fb78ac166dad6b82698324259aa3bb'
end

def twilio_client
  Twilio::REST::Client.new account_sid, auth_token
end

def twilio_messages
  twilio_client.account.messages.list
end

def incoming_messages
  twilio_messages.select {|m| m.direction == 'inbound'}
end

def set_new_reminders
  # read message list and add any new reminders
  incoming_messages.each do |message|
    create_reminder(message)
  end
end

def create_reminder(message)
  Reminder.create(reminder_params(message)) unless existing_reminder?(message)
end

def reminder_params(message)
  text, day = message.body.strip.split(/ on /)
  day = day.to_i
  day += 1 if day == 0
  {what: text, when: day, for: message.from}
end

def existing_reminder?(message)
  Reminder.first(reminder_params(message))
end

def todays_reminders
  today = Time.now.utc.day
  Reminder.all(when: today)
end

def send_reminder(reminder)
  twilio_client.account.messages.create(
    from: twilio_number,
    to: reminder.for,
    body: reminder.what
  )
end

def send_reminders
  todays_reminders.each do |reminder|
    send_reminder(reminder)
  end
end

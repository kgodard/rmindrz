#!/usr/bin/env ruby
require 'rubygems'
require 'dm-core'
require 'dm-migrations'
require 'twilio-ruby'

DataMapper.setup( :default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/rmindrz_dev.db" )

class Reminder
  include DataMapper::Resource

  property :id, Serial
  property :what, String, :required => true
  property :when, Integer, :required => true
  property :for, String, :required => true
  property :dead, Boolean, :default => false
  property :updated_at, DateTime
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

def incoming_messages(since = last_reminder_time)
  inbound_messages = twilio_messages.select {|m| m.direction == 'inbound'}
  since ? inbound_messages.select {|m| DateTime.parse(m.date_created) > since} : inbound_messages
end

def last_reminder_time
  last = Reminder.all(order: :updated_at).last
  last ? last.updated_at : nil
end

def process_messages
  incoming_messages.each do |message|
    process_message(message)
  end
end

def process_message(message)
  if kill_message?(message)
    kill_reminder(message)
  else
    create_reminder(message)
  end
end

def kill_reminder(message)
  reminder_id = message.body.strip.split.last.to_i
  if reminder_id > 0 && reminder = Reminder.get(reminder_id)
    puts "reminder found: #{reminder_id}"
    reminder.update(dead: true, updated_at: Time.now.utc)
  else
    puts "No reminder found for id: #{reminder_id}"
  end
end

def kill_message?(message)
  message.body =~ /^kill/i
end

def create_reminder(message)
  Reminder.create(new_reminder_params(message)) unless existing_reminder?(message)
end

def new_reminder_params(message)
  reminder_params(message).merge(updated_at: Time.now.utc)
end

def reminder_params(message)
  text, day = message.body.strip.split(/ on /)
  day = day.to_i
  day += 1 if day == 0
  {what: text, when: day, for: message.from}
end

def existing_reminder?(message)
  Reminder.first(reminder_params(message).merge(dead: false))
end

def todays_reminders
  today = Time.now.day
  Reminder.all(when: today, dead: false)
end

def send_reminder(reminder)
  twilio_client.account.messages.create(
    from: twilio_number,
    to: reminder.for,
    body: "[#{reminder.id}] #{reminder.what}"
  )
end

def send_reminders
  todays_reminders.each do |reminder|
    send_reminder(reminder)
  end
end

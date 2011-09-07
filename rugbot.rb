#encoding: utf-8
require 'rubygems'
require "bundler/setup"

# Why yes, let's be astonishingly lazy
Bundler.require :default

BOT_NAME = 'rugbot'
BOT_REPO = 'caius/Rugbot'
SEEN_LIST = {}
IMGUR_API_KEY = "4cdab1b0d1c8831232d477302a981363"
LAST_FM_API_KEY = "2a8aef209656ecfce46639a6dabe3e5e"
LAST_FM_API_SECRET = "d1c4dd174709fc65343471f9696a02b3"
LAST_FM_USERNAME_MAP = {
  /caius/i => "CaiusD",
  "tomb" => "tom0bell",
  "djgraham" => "davidistesting"
}
TASCHE = /(?:mus)?tas?ch(?:e|ify)/

require File.expand_path("rugbot_helper", File.dirname(__FILE__))

configure do |c|
  c.nick    = BOT_NAME
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#nwrug"
end

on :channel, /^(help|commands)$/i do
  log_user_seen(nick)

  msg channel, "roll, nextmeet, artme <string>, stab <nick>, seen <nick>, ram, uptime, 37status, boobs, trollface, dywj, dance, mustachify, stats, last"
end

on :channel, /^stats?$/ do
  msg channel, "http://dev.hentan.eu/irc/nwrug.html"
end

on :channel, /^last ?(\w*)$/ do |username|
  username ||= nick
  if (( n = LAST_FM_USERNAME_MAP.each {|match, name| break(name) if (match.is_a?(Regexp) ? username[match] : username == match) } ))
    username = n
  end
  msg channel, LastFM.latest_track_for(username)
end

on :channel, /^dance$/i do
  case [0,1,2].shuffle.first
  when 0
    msg channel, "EVERYBODY DANCE NOW!"
    action channel, "does the funky chicken"
  when 1
    msg channel, "http://no.gd/caiusboogie.gif"
  when 2
    msg channel, "http://i.imgur.com/rDDjz.gif"
  end
end

on :channel, /^meme/i do
  log_user_seen(nick)
  # There are no decent meme web services, nor gems wrapping the shitty ones.
  # -- Caius, 20th Aug 2011
  msg channel, "Y U NO FIX MEME?!"
end

on :channel, /^troll(face)?$/i do
  log_user_seen(nick)
  msg channel, ["http://no.gd/troll.png", "http://no.gd/trolldance.gif", "http://caius.name/images/phone_troll.jpg"].shuffle.first
end

on :channel, /^boner/i do
  log_user_seen(nick)
  msg channel, ["http://files.myopera.com/coxy/albums/106123/trex-boner.jpg", "http://no.gd/badger.gif"].shuffle.first
end

on :channel, /^badger/i do
  log_user_seen(nick)
  msg channel, "http://no.gd/badger2.gif"
end

on :channel, /dywj/i do
  log_user_seen(nick)

  msg channel, "DAMN YOU WILL JESSOP!!!"
end

on :channel, /^roll ([0-9]*)$/i do |sides|
  log_user_seen(nick)
  sides = 6 unless sides
  msg channel, "#{nick} rolls a #{sides} sided die and gets #{rand(sides) +1}"
end

on :channel, /ACTION(.*)pokes #{Regexp.escape(BOT_NAME)}/i do
  log_user_seen(nick)

    action channel, "giggles at #{nick}"
end

on :channel, /^37status$/i do
  log_user_seen(nick)

   doc = JSON.parse(Curl::Easy.perform('http://status.37signals.com/status.json').body_str)
   msg channel, "#{doc['status']['mood']}: #{doc['status']['description']}"
end

on :channel, /^nextmeet/i do
  log_user_seen(nick)

  # Setup vars we need
  nwrug = nil
  details = nil

  begin
    # Grab ze string from ze website
    event = Nokogiri::HTML(Curl::Easy.perform("http://nwrug.org/events/").body_str).css('.first_entry h3').first
    entry_url = "http://nwrug.org#{event.css('a').first.attributes['href'].value}"
    entry_title = event.content.gsub("\342\200\223", "-").strip

    # Figure out the details we want to return
    meeting_date, *meeting_title = entry_title.split(" - ")
    meeting_title = meeting_title.join(" - ")

    if (d = Date.parse(meeting_date)) && d >= Date.today
      nwrug = d
      details = [meeting_title, entry_url]
    end
  rescue
  end

  # In case we couldn't parse a current time from the website
  nwrug ||= nwrug_meet_for Time.now.year, Time.now.month

  date_string = case nwrug
  when Date.today
    "Today"
  when (Date.today + 1)
    "Tomorrow"
  else
    nwrug.strftime("%A, #{ordinalize(nwrug.day)} %B")
  end

  # compact makes sure we don't end up with "Today - ", but "Today" instead.
  msg channel, [date_string, details].compact.join(" - ")
end

on :channel, /^nextmeat/i do
  msg channel, "BACNOM"
end

on :channel, /^.* st[aа]bs/i do
  log_user_seen(nick)

  action channel, "stabs #{nick}" unless nick == "rugbot"
end

on :channel, /^stab (.*?)$/i do |user|
  log_user_seen(nick)
  user = nick if %w(rugbot self yourself).include?(user)

  action channel, "stabs #{user}"
end

on :channel, /^b(oo|ew)bs$/i do |user|
  log_user_seen(nick)

  msg channel, ["(.)(.)", "http://no.gd/boobs.gif"].shuffle.first
end

on :channel, /^artme (.*?)$/i do |phrase|
  log_user_seen(nick)

  response = image_for(phrase)
  msg channel, (response ? response : "Nothing found")
end

# 'tache an existing URL
on :channel, /^#{TASCHE} (http.*)$/ do |url|
  log_user_seen(nick)

  msg channel, tasche(url)
end

# 'tache the artme image for a given phrase
on :channel, /^#{TASCHE} (.*)$/ do |phrase|
  log_user_seen(nick)

  img = image_for(phrase)
  msg channel, (img ? tasche(img) : "Nothing found")
end

on :channel, /^seen (\w+)$/i do |user|
  log_user_seen(nick)

  user = user.downcase
  msg channel, if SEEN_LIST.has_key?(user)
    "#{nick}: I last saw #{user.inspect} speak at #{SEEN_LIST[user].strftime("%H:%M:%S on %d-%m-%y")}"
  else
    "#{nick}: not seen #{user.inspect} yet, sorry"
  end
end

# Replies with the current ram usage of this bot
on :channel, /^ram\s*$/i do
  log_user_seen(nick)

  usage = `ps -p #{Process.pid} -o rss=`.strip.chomp.to_i
  msg channel, ( "#{nick}: current usage is %.2f MB" % (usage/1024.0))
end

# Replies with the current uptime of this bot
on :channel, /^uptime\s*$/i do
  log_user_seen(nick)

  start_time = Time.parse(`ps -p #{Process.pid} -o lstart=`.strip.chomp)
  msg channel, "#{nick}: I've been running for #{(Time.now - start_time).to_time_length}"
end

# http://twitter.com/stealthygecko/status/20892091689
# http://twitter.com/#!/stealthygecko/status/20892091689
# And https | trailing /
on :channel, /https?:\/\/twitter.com(?:\/#!)?\/[\w-]+\/status(?:es)?\/(\d+)/i do |tweet_id|
  log_user_seen(nick)

  begin
    tweet = Twitter.status(tweet_id)
    user = tweet.user
  rescue Twitter::Error => e
    puts "Caught #{e}"
  end
  msg channel, "#{CGI.unescapeHTML(tweet.text.gsub(/\n+/m, " \\n "))} - #{user.name} (#{user.screen_name})" if tweet
end

# http://twitter.com/stealthygecko
# http://twitter.com/#!/stealthygecko
# And https | trailing /
on :channel, /https?:\/\/twitter\.com(?:\/#!)?\/([^\/]+?)(?:$|\s)/i do |user|
  log_user_seen(nick)

  begin
   u = Twitter.user(user)
   msg channel, "#{u.name} (#{u.screen_name}) - #{u.description} #{u.profile_image_url}"
   msg channel, "Last status: #{CGI.unescapeHTML(u.status.text.gsub(/\n+/m, " \\n "))}"
  rescue => e
   puts "Caught #{e}"
  end
end

# http://heello.com/caius/168024
# https://heello.com/caius/168024
# and trailing /
on :channel, %r{(https?://heello.com/[^/]+/\d+)} do |heello|
  begin
    req = Curl::Easy.perform(heello) do |curl|
      curl.follow_location = true
    end

    doc = Nokogiri::HTML(req.body_str)
    body = doc.css("#single-ping").first.content
    username = doc.css("#name").first.content
    msg channel, "#{username}: #{body}"
  rescue StandardError => e
    puts "Got error fetching heello status: #{e}"
  end

end

on :channel, /(https?:\/\/\S+)/i do |url|
  log_user_seen(nick)

  begin
    easy = Curl::Easy.perform(url) do |easy|
      easy.follow_location = true # follow redirects
    end

    title = Nokogiri::HTML(easy.body_str).css('title').first.content
    msg channel, "#{title.gsub(/\s+/m, " ").strip}"
  rescue StandardError => e
    puts "general http link got error: #{e}"
  end
end

on :channel, /who broke rugbot/i do
  log_user_seen(nick)
  
  msg channel, "tomb broke me"
=begin
  url = "https://api.github.com/repos/#{BOT_REPO}/commits?per_page=1"

  begin
    commit = JSON.parse(Curl::Easy.perform(url).body_str).first["commit"]
    author = commit["author"]["name"]
    date = DateTime.parse(commit["author"]["date"]).strftime("%e %b %Y at %H:%m")
    message = commit["message"]
    msg channel, "#{author} broke me on #{date} with '#{message}'"
  rescue StandardError => e
    puts "Bugger! Couldn't find out who broke me: #{e}"
    msg channel, "Couldn't find who to blame, so I'm blaming…"
    action channel, "points at #{SEEN_LIST.keys.shuffle.first}"
  end
=end
end

# Catchall for seen
on :channel, /.*/ do
  log_user_seen(nick)
end

def log_user_seen nick
  SEEN_LIST[nick.downcase] = Time.now
end

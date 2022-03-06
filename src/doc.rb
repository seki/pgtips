require 'json'
require_relative 'bucket'
require_relative 'pg-tips'

module PGTips
  Store = Bucket.new
  Name = "tea.json"
  class Doc
    def self.load
      begin
        it = Store.get_object(Name)
        hash = JSON.parse(it.body.read)
      rescue
        hash = {}
      end
      self.new(hash)
    end

    def initialize(hash)
      @hash = hash
      @log = hash.dig('log') || {}
    end
    attr_reader :hash, :log

    def latest
      @log.dig(@log.keys.max)
    end

    def amazon?
      latest['merchant'] == 'Amazon.co.jp'
    end

    def update
      it = PGTips.pg_tips
      li = it.listings.first

      last = latest

      today = {
        "merchant" => li.merchant, 
        "price" => li.get(%w(Price Amount))
      }

      @log[Time.now.strftime("%Y-%m-%d")] = today

      @hash = {
        "title" => it.title, 
        "url" => it.detail_url, 
        "image" => it.image_url, 
        "log" => @log
      }

      last == today ? nil : today
    end

    def save
      Store.put_object(Name, @hash.to_json)
    end

    def url
      @hash['url']
    end
  end

  module_function
  def twitter_client
    Twitter::REST::Client.new(
      :consumer_key    => ENV['TWITTER_API_KEY'],
      :consumer_secret => ENV['TWITTER_API_SECRET'],
      :access_token    => ENV['TWITTER_ACCESS_TOKEN'],
      :access_token_secret => ENV['TWITTER_ACCESS_TOKEN_SECRET']
    )
  end
end

if __FILE__ == $0
  doc = PGTips::Doc.load
  changes = doc.update
  doc.save

  text = if doc.amazon?
    if changes
      "amazonから#{changes['price']}円です！"
    else
      "いつも通りです。"
    end
  else
    "販売者がamazonじゃないので注意です〜"
  end

  puts ['[bot☕️]', '@miwa719', text, doc.url].join(" ")
end


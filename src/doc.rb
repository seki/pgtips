require 'json'
require 'twitter'
require_relative 'bucket'
require_relative 'pg-tips'

module PGTips
  Store = Bucket.new
  Name = "tea.json"

  class Doc
    Docs = {}

    def self.load
      begin
        it = Store.get_object(Name)
        hash = JSON.parse(it.body.read)
      rescue
        hash = {}
      end
      hash.each do |k, v|
        Docs[k] = self.new(v)
      end
      Docs
    end

    def self.update
      ids = Docs.keys
      PGTips.get_items(ids).each do |it|
        Docs[it.hash['ASIN']].update(it)
      end
      hash = {}
      Docs.each do |k, v|
        hash[k] = v.hash
      end
      Store.put_object(Name, hash.to_json)
    end

    def initialize(hash)
      @hash = hash
      @log = hash.dig('log') || {}
      @changes = nil
    end
    attr_reader :hash, :log, :changes

    def latest
      @log.dig(@log.keys.max)
    end

    def amazon?
      latest['merchant'] == 'Amazon.co.jp'
    end

    def price
      latest['price'] rescue nil
    end

    def update(it)
      begin
        li = it.listings.first
      rescue
        pp [:empty, it.asin]
        return
      end

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
        "latest" => @log.keys.max,
        "log" => @log
      }

      @changes = (last == today ? nil : today)
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
  doc = PGTips::Doc.load['B0001LQKBQ']
  PGTips::Doc.update

  changes = doc.changes

  text = if doc.amazon?
    if changes
      "amazonから#{changes['price']}円です！"
    else
      "いつも通りです。"
    end
  else
    "最安値の販売者がamazonではないです！送料に注意して！"
  end

  unless ENV['DYNO']
    pp [:not_heroku, text]
    exit
  end
  PGTips::twitter_client.update(['[bot☕️]', '@miwa719', text, doc.url, 'https://pgtips.druby.work/app'].join(" "))
end


require 'json'
require_relative 'bucket'
require_relative 'pg-tips'

module PGTips
  Store = Bucket.new
  Name = "tea.json"
  class Doc
    def self.load
      begin
        it = Store.get_object('tea.json')
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

    def update
      it = PGTips.pg_tips
      li = it.listings.first

      last = @log.dig(@log.keys.max)

      today = {
        "merchant" => li.merchant, 
        "price" => li.get(%w(Price Amount))
      }
      pp [:last, last, last == today]

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
      body = @hash.to_json
      Store.put_object('tea.json', body)
      body
    end
  end
end

if __FILE__ == $0
  doc = PGTips::Doc.load
  pp [:update, doc.update]
  puts doc.save
end


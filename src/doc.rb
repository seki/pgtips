require 'json'
require_relative 'bucket'
require_relative 'pg-tips'

module PGTips
  Store = Bucket.new
  Name = "tea.json"
  class Doc
    def self.load
      it = Store.get_object('tea.json') rescue {}
      self.new(it)
    end

    def initialize(hash)
      @hash = hash
      @log = hash.dig('log') || {}
    end
    attr_reader :hash, :log

    def update
      it = PGTips.pg_tips
      li = it.listings.first

      @log[Time.now.strftime("%Y-%m-%d")] = {
        "merchant" => li.merchant, 
        "price" => li.get(%w(Price Amount))
      }

      @hash = {
        "title" => it.title, 
        "url" => it.detail_url, 
        "image" => it.image_url, 
        "log" => @log
      }
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
  doc.update
  pp doc.hash
  puts doc.save
end


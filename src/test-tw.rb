require 'twitter'
require 'net/http'
require 'uri'
require 'date'
require 'open-uri'

class MyTwitter
  def auth
    @twitter = Twitter::REST::Client.new(
      :consumer_key    => ENV['TWITTER_API_KEY'],
      :consumer_secret => ENV['TWITTER_API_SECRET'],
      :access_token    => ENV['TWITTER_ACCESS_TOKEN'],
      :access_token_secret => ENV['TWITTER_ACCESS_TOKEN_SECRET']
    )
  end
  attr_reader :twitter
end

if __FILE__ == $0
  tw = MyTwitter.new
  tw.auth
  # tw.twitter.update('[bot] herokuからテスト')
  tw.twitter.search("to:m_seki", result_type: "recent").take(3).each do |x|
    puts x.text
  end
end
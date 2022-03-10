require 'twitter'
require 'oauth'
require 'csv'

module PGTips
  module Twitter

    module_function
    def credential_via_file
      csv = CSV.read(File.expand_path('pgtips-tw-credential.csv'), headers: true)
      return csv[0][0], csv[0][1]
    end

    def consumer
      consumer_key, consumer_secret = credential_via_file
      OAuth::Consumer.new(
        consumer_key, 
        consumer_secret, 
        :site => 'https://api.twitter.com'
      )
    end
  end
end

if __FILE__ == $0
  consumer = PGTips::Twitter::consumer
  request_token = consumer.get_request_token(:oauth_callback => 'http://localhost:8000/auth/twitter/callback')
  pp request_token
end
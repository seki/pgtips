require 'paapi'
require 'csv'
require 'json'

module PGTips
  PartnerTag = 'ilikeruby-22'
  module_function
  def credential_via_file
    csv = CSV.read(File.expand_path('~/.PAAPICredentials.csv'), headers: true)
    return csv[0][0], csv[0][1], PartnerTag
  end

  def credential_via_env
    raise 'unset env' unless (ENV['PAAPI_ACCESS'] && ENV['PAAPI_SECRET'])
    return ENV['PAAPI_ACCESS'], ENV['PAAPI_SECRET'], PartnerTag
  end

  def setup_client
    access_key, secret_key, partner_tag = credential_via_env rescue credential_via_file
    Paapi::Client.new(
      access_key: access_key,
      secret_key: secret_key,
      partner_tag: partner_tag,
      market: :jp
    )
  end

  Client = setup_client

  def for_tea
    Client.get_items(item_ids: ['B0001LQKBQ'], Merchant: 'Amazon').hash.dig(
      'ItemsResult', 'Items', 0, 'Offers', 'Listings', 0, 'Price', 'Amount'
    )
  end

  def pg_tips
    Client.get_items(item_ids: ['B0001LQKBQ']).items.first
  end
end

if __FILE__ == $0
  it = PGTips.pg_tips
  li = it.listings.first
  hash = {
    "title" => it.title, 
    "url" => it.detail_url, 
    "image" => it.image_url, 
    "merchant" => li.merchant, 
    "price" => li.get(%w(Price Amount))
  }
  pp hash
end
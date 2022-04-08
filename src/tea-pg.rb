require "pg"
require "monitor"
require "pp"
require 'json'

class TeaPG
  include MonitorMixin

  def self.instance
    @instance = self.new unless @instance
    @instance.synchronize do
      @instance = self.new unless @instance.ping
    end
    return @instance
  rescue
    nil
  end

  def initialize
    super()
    url = ENV['DATABASE_URL'] || 'postgres:///tea'
    @conn = PG.connect(url)
    @conn.type_map_for_results = PG::BasicTypeMapForResults.new(@conn)
  end
  attr :conn

  def ping
    @conn.exec("select 1")
    true
  rescue
    false
  end

  def create_table
    sql =<<EOB
create table drip (
tag text
, at timestamp(6)
, value jsonb
, primary key(tag, at));
EOB
    @conn.transaction do |c|
      c.exec(sql)
    end
  end

  def create_table_shop
    sql =<<EOB
create table shop (
id text
, status integer
, at timestamp(6)
, value jsonb
, primary key(id));
EOB
    @conn.transaction do |c|
      c.exec(sql)
    end
  end

  def create_view
    sql =<<EOB
CREATE VIEW
  latest
AS SELECT
    a.tag,
    a.at,
    a.value
FROM
    drip AS a
    INNER JOIN (SELECT
                    tag,
                    MAX(at) AS max_at
                FROM
                    drip
                GROUP BY
                    tag) AS b
    ON a.tag = b.tag
    AND a.at = b.max_at;
EOB
    @conn.transaction do |c|
      c.exec(sql)
    end
  end

  def last(tag)
    synchronize do
      sql = "select value from drip where tag=$1 order by at desc limit 1"
      @conn.exec_params(sql, [tag]).to_a.dig(0, 'value')
    end
  end

  def history(tag, n=10)
    synchronize do
      sql = "select value, at from drip where tag=$1 order by at desc limit $2"
      @conn.exec_params(sql, [tag, n]).to_a
    end
  end

  def write(tag, value)
    @conn.transaction do
      at = write_entry(tag, value).first['at']
      shop_update(value.dig('Offers', 'Listings', 0, 'MerchantInfo'), at)
    end
  end

  def write_entry(tag, value)
    sql = <<EOB
insert into drip (tag, value, at) values ($1, $2, now()) returning at
EOB
    synchronize do
      @conn.exec_params(sql, [tag, value.to_json]).to_a
    end
  end

  def search_by_title(str)
    synchronize do
      sql = "select tag, at, value->'ItemInfo'->'Title'->>'DisplayValue' as title from latest where value->'ItemInfo'->'Title'->>'DisplayValue' like $1;"
      @conn.exec_params(sql, ["%#{str}%"]).to_a
    end
  end

  def price(tag, n=1)
    synchronize do
      sql = "select value->'Offers'->'Listings'->0->'Price'->'Amount' as price, at from drip where tag=$1 order by at desc limit $2"
      @conn.exec_params(sql, [tag, n]).to_a
    end
  end

  def shop
    synchronize do
      sql = "select * from shop order by status desc, value->'Name';"
      @conn.exec_params(sql, []).to_a
    end
  end

  def shop_update_status(shop_id, status)
    sql = <<EOB
update shop set status=$2 where id=$1;
EOB
    synchronize do
      @conn.exec_params(sql, [shop_id, status])
    end
  end

  def shop_update(value, at)
    sql = <<EOB
insert into shop (id, at, value) values ($1, $2, $3)
ON CONFLICT ON CONSTRAINT shop_pkey do update set
  at = $2,
  value = $3
EOB
    synchronize do
      @conn.exec_params(sql, [value['Id'], at, value.to_json])
    end
  end

  def foo
    sql = <<EOB
insert into shop (id, value, at) 
select value #>> '{Offers,Listings,0,MerchantInfo,Id}', value #> '{Offers,Listings,0,MerchantInfo}' as shop, at from drip where value #> '{Offers,Listings,0,MerchantInfo,Id}' is not null order by at desc
on conflict do nothing
EOB
    @conn.exec(sql)
  end

end

if __FILE__ == $0
  require 'paapi'
  db = TeaPG.instance

=begin
  it = db.last('B09TFDHPT6')
  pp it.dig('ItemInfo', 'Title', 'DisplayValue')

  item = Paapi::Item.new(it)
  pp item.listings

  pp db.search_by_title('ガッツのつるはし')
  pp db.search_by_title('紅茶')

  pp db.price('B0001LQKBQ', 10)

  pp db.search_by_title('アルセウスVSTAR')

  pp db.shop.sort_by {|x| x['Id']}
=end
  pp db.foo.to_a
end

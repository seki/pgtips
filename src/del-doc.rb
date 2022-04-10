require_relative 'doc'

ids = ARGV.to_a

PGTips::Doc.load
ids.each do |asin|
  PGTips::Doc::Docs.delete(asin)
end
PGTips::Doc.update
require 'webrick'
require 'tofu'
require_relative 'src/app'

port = Integer(ENV['PORT']) rescue 8000
server = WEBrick::HTTPServer.new({
  :Port => port,
  :FancyIndexing => false
})

tofu = Tofu::Bartender.new(PGTips::Session, 'pgtips')
server.mount('/', Tofu::Tofulet, tofu)

server.mount_proc('/auth/twitter/callback') do |req, res|
  _, secret, session_id = PGTips::WaitingOAuth.take([req.query['oauth_token'], nil, nil], 0)
  if session = tofu.instance_variable_get('@bar').fetch(session_id) rescue nil
    session.oauth_callback(req.query['oauth_token'], req.query['oauth_verifier'])
  else
    pp [:session_id, session_id]
  end
  res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, '/')
end

trap(:INT){exit!}
server.start

# -*- coding: utf-8 -*-
require 'tofu'
require 'pathname'
require 'pp'
require_relative 'my-oauth'
require 'rinda/tuplespace'

module Tofu
  class Tofu
    def normalize_string(str_or_param)
      str ,= str_or_param
      return '' unless str
      str.force_encoding('utf-8').strip
    end
  end
end

module PGTips
  WaitingOAuth = Rinda::TupleSpace.new

  class Session < Tofu::Session
    def initialize(bartender, hint='')
      super
      @base = BaseTofu.new(self)
      @oauth = OAuthTofu.new(self)
      @user = nil
    end
    attr_reader :user, :oauth
    
    def do_GET(context)
      context.res_header('cache-control', 'no-store')
      super(context)
    end

    def redirect_to(context, path)
      context.res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, 
                               path.to_s)
      context.done
    end

    def lookup_view(context)
      case context.req.path_info
      when '/auth/twitter/callback'
        @oauth
      else
        @base
      end
    end

    def oauth_start(context)
      url = context.req.request_uri + '/auth/twitter/callback'
      pp [:do_login, session_id, context.req, url]
      url = 'https://pg-tips.herokuapp.com/auth/twitter/callback'
      consumer = PGTips::Twitter::consumer
      request_token = consumer.get_request_token(:oauth_callback => url.to_s)
      WaitingOAuth.write([request_token.token, request_token.secret, session_id])
      redirect_to(context, request_token.authorize_url)
    end

    def oauth_callback(token, verifier)
      consumer = PGTips::Twitter::consumer
      request_token = OAuth::RequestToken.new(consumer, token, verifier)
      access_token = consumer.get_access_token(request_token, :oauth_verifier => verifier)
      pp [session_id, access_token.params]

      @tw_user_id = access_token.params[:user_id]
      @tw_screen_name = access_token.params[:screen_name]
      @tw_secret = access_token.secret
      @tw_token = access_token.token
    end
  end

  class OAuthTofu < Tofu::Tofu
    @erb_method = []
    def to_html(context)
      pp @session.session_id
      @session.oauth_callback(context.req.query['oauth_token'], context.req.query['oauth_verifier'])
      @session.redirect_to(context, '/')
    end

    def tofu_id
      'api'
    end
  end

  class BaseTofu < Tofu::Tofu
    set_erb(__dir__ + '/base.html')

    def initialize(session)
      super(session)
    end

    def tofu_id
      'base'
    end

    def pathname(context)
      script_name = context.req_script_name
      script_name = '/' if script_name.empty?
      Pathname.new(script_name)
    end

    def do_login(context, params)
      @session.oauth_start(context)
    end

    def do_logout(context, params)
      @session
    end
  end
end
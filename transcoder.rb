require 'sinatra'
require 'sinatra/reloader'
require 'haml'

require './lib/transcode'

TRANSCODER_HOST = '10.65.6.104'
TRANSCODER_PORT = 14530

configure do
  set :show_exceptions, false
end

get '/' do
  haml :page
end

post '/perform' do
  start = Time.now
  @result = eval "Transcode.new(host: '#{params[:host].empty? ? TRANSCODER_HOST : params[:host]}', port: #{params[:port].empty? ? TRANSCODER_PORT : params[:port]}) { #{params[:q]}  }"
  duration = Time.now - start
  headers 'X-Runtime-Seconds' => duration.to_s
  haml :ajax
end

get '/ticks' do
  stream(:keep_open) do |out|
    1000000.times {
      out << Time.now.to_s << '<br/>'
      sleep 1
    }
    # store connection for later on
    #connections << out
    # remove connection when closed properly
    #out.callback { connections.delete(out) }
    # remove connection when closed due to an error
    #out.errback do
    #  logger.warn 'we just lost a connection!'
    #  connections.delete(out)
    #end
  end
end

get '/*' do
  haml :page
end


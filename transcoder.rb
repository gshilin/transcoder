require 'sinatra'
require 'haml'

require './lib/transcode'

TRANSCODER_HOST = '10.65.6.104'
TRANSCODER_PORT = 14530

get '/' do
  haml :form
end

post '/perform' do
  @result = eval "Transcode.new(host: '#{params[:host]}', port: #{params[:port].to_i}) { #{params[:q].gsub(/\r\n/, "\;")}  }"
  haml :ajax
end



require 'sinatra'
require 'haml'

require './lib/transcode'

TRANSCODER_HOST = '10.65.6.104'
TRANSCODER_PORT = 14530

get '/' do
  haml :form
end

post '/perform' do
  transcoder = Transcode.new(host: params[:host], port: params[:port])
  @result = transcoder.instance_eval(params[:q])
  haml :form
end

def show(json)
  command = json.delete(:command)
  response = json.delete(:response)
  output = "Error: #{json[:error]}<br/>" + "Message: #{json[:message]}<br/>"
  (json[:result] || []).each {|h, v|
    output += "#{h}: #{v}<br/>"
  }
  output
end
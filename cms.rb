require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__)

configure do
  enable :sessions
  set :session_secret, 'secret'
end

get '/' do
  @filenames = Dir['./data/*'].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

get '/:filename' do |filename|
  path = "#{root}/data/#{filename}"
  if File.file?(path)
    headers['Content-Type'] = 'text/plain'
    File.read(path)
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

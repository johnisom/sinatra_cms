require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

get '/' do
  @filenames = Dir['./data/*'].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

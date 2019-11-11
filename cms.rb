require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path('..', __FILE__)

get '/' do
  @filenames = Dir['./data/*'].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

get '/:filename' do |filename|
  headers['Content-Type'] = 'text/plain'
  File.read("#{root}/data/#{filename}")
end

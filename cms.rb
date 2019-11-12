require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

root = File.expand_path('..', __FILE__)
markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

configure do
  enable :sessions
  set :session_secret, 'secret'
end

# Loads header for content type and returns correctly
# formatted file content
def file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.md', '.markdown'
    headers['Content-Type'] = 'text/html;charset=utf-8'
    markdown(content)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  end
end

get '/' do
  @filenames = Dir['./data/*'].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

get '/:filename' do |filename|
  path = "#{root}/data/#{filename}"
  if File.file?(path)
    file_content(path)
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

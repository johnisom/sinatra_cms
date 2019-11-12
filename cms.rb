require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def markdown(text)
  Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(text)
end

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
    erb markdown(content), layout: false
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  else
    headers['Content-Type'] = 'text/plain'
    content
  end
end

get '/' do
  pattern = File.join(data_path, '*')
  @filenames = Dir[pattern].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

get '/new' do
  erb :new, layout: :layout
end

post '/create' do
  name = params[:name].strip
  unless name =~ /\A\w+\.\w+\z/
    session[:error] = 'A name with extension is required.'
    status 422
    erb :new, layout: :layout
  else
    File.write(File.join(data_path, name), '')
    session[:success] = "#{name} was created."
    redirect '/'
  end
end

get '/:filename' do |filename|
  path = "#{data_path}/#{filename}"
  if File.file?(path)
    file_content(path)
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do |filename|
  @content = File.read(File.join(data_path, filename))
  erb :edit, layout: :layout
end

post '/:filename' do |filename|
  File.write(File.join(data_path, filename), params[:content])
  session[:success] = "#{filename} has been updated."
  redirect '/'
end

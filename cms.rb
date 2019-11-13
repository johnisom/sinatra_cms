require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

# Gives path for data depending on if its
# in testing or production
def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

# Convert markdown to html
def markdown(text)
  Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(text)
end

# Allow us to use flash messages and login
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
    erb markdown(content), layout: :layout
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  else
    headers['Content-Type'] = 'text/plain'
    content
  end
end


# Check if user is authorized
def authorized?
  session.key?(:uname)
end

# Make sure user is authorized and redirect
# if not
def check_authorization
  unless authorized?
    session[:error] = 'You must be signed in to do that.'
    redirect '/'
  end
end

# Main page. Loads either list of files + extras or
# Sign in button if user is not authorized
get '/' do
  pattern = File.join(data_path, '*')
  @filenames = Dir[pattern].map { |path| File.basename(path) }
  erb :index, layout: :layout
end

# Loads sign in form for users to get authorized
get '/users/signin' do
  erb :signin, layout: :layout
end

# Authorizes user or asks user to try again
post '/users/signin' do
  uname = params[:uname]
  psswd = params[:psswd]
  if uname == 'admin' && psswd == 'secret'
    session[:uname] = 'admin'
    session[:success] = 'Welcome!'
    redirect '/'
  else
    session[:error] = 'Invalid credentials. Please try again.'
    status 422
    erb :signin, layout: :layout
  end
end

# Signs user out
post '/users/signout' do
  session.delete(:uname)
  session[:success] = 'You have been signed out.'
  redirect '/'
end

# Renders template form for creating new file
get '/new' do
  check_authorization

  erb :new, layout: :layout
end

# Handles submission of form rendered above
# Creates file if valid filename
post '/create' do
  check_authorization

  name = params[:name].strip
  unless name =~ /\A[\s\w\-]+\.[\s\w\-]+\z/
    session[:error] = 'A proper filename is required.'
    status 422
    erb :new, layout: :layout
  else
    File.write(File.join(data_path, name), '')
    session[:success] = "#{name} has been created."
    redirect '/'
  end
end

# Displays file content if file exists
get '/:filename' do |filename|
  path = "#{data_path}/#{filename}"
  if File.file?(path)
    file_content(path)
  else
    session[:error] = "#{filename} does not exist."
    redirect '/'
  end
end

# Displays form for editing files
# Content is preloaded into the textarea
get '/:filename/edit' do |filename|
  check_authorization

  @content = File.read(File.join(data_path, filename))
  erb :edit, layout: :layout
end

# Updates the file with what is in form from above
post '/:filename' do |filename|
  check_authorization

  File.write(File.join(data_path, filename), params[:content])
  session[:success] = "#{filename} has been updated."
  redirect '/'
end

# Deletes a file
post '/:filename/delete' do |filename|
  check_authorization

  File.delete(File.join(data_path, filename))
  session[:success] = "#{filename} has been deleted."
  redirect '/'
end

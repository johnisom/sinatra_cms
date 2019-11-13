require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

ACCEPTABLE_EXTENSIONS = %w[.txt .md .jpg .jpeg .png].freeze

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

# Tests if extension is image
def image?(filename)
  %w[.jpg .jpeg .png].include? File.extname(filename)
end

# Allow us to use flash messages and login
configure do
  enable :sessions
  set :session_secret, 'secret'
end

# Loads header for content type and returns correctly
# formatted file contentn
def file_content(path)
  content = File.read(path)
  case File.extname(path).downcase
  when '.md'
    headers['Content-Type'] = 'text/html;charset=utf-8'
    erb markdown(content), layout: :layout
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  when '.jpg', '.jpeg'
    headers['Content-Type'] = 'image/jpeg'
    content
  when '.png'
    headers['Content-Type'] = 'image/png'
    content
  end
end

# Credentials from users.yml file
def credentials
  Psych.load_file(File.expand_path('../users.yml', data_path))
end

# Check credentials for username and password match
def valid_user?(username, password)
  credentials.key?(username) &&
    BCrypt::Password.new(credentials[username]) == password
end

# List of all usernames
def usernames
  credentials.keys
end

# Check if user is authorized
def authorized?
  session.key?(:uname)
end

# Make sure user is authorized and redirect
# if not
def check_authorization
  return if authorized?

  session[:error] = 'You must be signed in to do that.'
  redirect '/'
end

# List of all filenames in CMS
def filenames
  pattern = File.join(data_path, '*')
  Dir[pattern].map { |path| File.basename(path) }
end

# Generates error for filename or nil if no error
def error_for_filename(name)
  extname = File.extname(name)
  if !(name =~ /\A[\s\w\-]+\.[\s\w\-]+\z/)
    'A proper filename is required.'
  elsif !ACCEPTABLE_EXTENSIONS.include? extname
    joined_extensions = ACCEPTABLE_EXTENSIONS.join(', ')
    "File extension must be one of: #{joined_extensions}."
  elsif filenames.include? name
    'Filename must be unique.'
  end
end

# Generates error for username or nil if no error
def error_for_credentials(username, password)
  if !(4..16).cover? username.size
    'Username must be between 4 and 16 characters.'
  elsif !(username =~ /\A\w+\z/)
    'Usernameame must only alphanumeric characters.'
  elsif usernames.include? username
    "Sorry, #{username} is already taken."
  elsif !(8..16).cover? password.size
    'Password must be between 8 and 16 characters.'
  end
end

# Generates error for image filename or nil if no error
def error_for_image(name, type)
  if !%w[image/jpeg image/png].include? type
    "File must be one of: #{IMAGE_EXTENSIONS.join(', ')}"
  elsif (error = error_for_filename(name))
    error
  end
end

# Adds user to users.yml
def add_user(username, password)
  File.open(File.expand_path('../users.yml', data_path), 'a') do |file|
    encrypted_password = BCrypt::Password.create(password)
    file.write("#{username}: #{encrypted_password}\n")
  end
end

# Main page. Loads either list of files + extras or
# Sign in button if user is not authorized
get '/' do
  @filenames = filenames
  erb :index, layout: :layout
end

# Loads sign in form for users to get authorized
get '/users/signin' do
  redirect '/' if authorized?

  erb :signin, layout: :layout
end

# Authorizes user or asks user to try again
post '/users/signin' do
  redirect '/' if authorized?

  uname = params[:uname]
  psswd = params[:psswd]
  if valid_user?(uname, psswd)
    session[:uname] = uname
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

# Renders signup form
get '/users/signup' do
  redirect '/' if authorized?

  erb :signup, layout: :layout
end

# Creates new user
post '/users/signup' do
  redirect '/' if authorized?

  uname = params[:uname].strip
  psswd = params[:psswd].strip
  if (error = error_for_credentials(uname, psswd))
    session[:error] = error
    status 422
    erb :signup, layout: :layout
  else
    add_user(uname, psswd)
    session[:uname] = uname
    session[:success] = "Welcome to the CMS, #{uname}!"
    redirect '/'
  end
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
  if (error = error_for_filename(name))
    session[:error] = error
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

  if image?(filename)
    session[:error] = 'Cannot edit image file.'
    redirect '/'
  end

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

# Renders form for duplicating file
get '/:filename/duplicate' do
  check_authorization

  erb :duplicate, layout: :layout
end

# Handles file duplication
post '/:filename/duplicate' do |filename|
  check_authorization

  if (error = error_for_filename(params[:name]))
    session[:error] = error
    status 422
    erb :duplicate, layout: :layout
  else
    content = File.read(File.join(data_path, filename))
    File.write(File.join(data_path, params[:name]), content)
    session[:success] = "#{filename} has been duplicated into #{params[:name]}"
    redirect '/'
  end
end

# Handles image uploading
post '/upload/image' do
  check_authorization

  name = params[:file_upload][:filename]
  content = params[:file_upload][:tempfile]
  if (error = error_for_image(name, params[:file_upload][:type]))
    session[:error] = error
    redirect '/new'
  else
    File.write(File.join(data_path, name), content.read)
    session[:success] = 'Image successfully uploaded.'
    redirect '/'
  end
end

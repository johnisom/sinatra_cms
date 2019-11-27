ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

Minitest::Reporters.use!

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    path_to_users = File.expand_path('../../users.yml', data_path)
    path_to_test_users = File.expand_path('../users.yml', data_path)
    FileUtils.cp(path_to_users, path_to_test_users)
  end

  def teardown
    FileUtils.rm_rf(File.expand_path('..', data_path))
  end

  def create_document(name, content = '')
    File.write(File.join(data_path, name), content)
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => { uname: 'admin' } }
  end

  def invalid_extension_message
    joined_extensions = ACCEPTABLE_EXTENSIONS.join(', ')
    "File extension must be one of: #{joined_extensions}."
  end

  def test_about_md
    body = <<-BODY
<h1>Ruby is..</h1>

<p>A dynamic, open source programming language with a focus on simplicity and
productivity. It has an elegant syntax that is natural to read and easy to write.</p>
    BODY

    content = <<-CONTENT
# Ruby is..

A dynamic, open source programming language with a focus on simplicity and
productivity. It has an elegant syntax that is natural to read and easy to write.
    CONTENT

    create_document 'about.md', content

    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, body
  end

  def test_changes_txt
    body = <<-BODY
So far, no changes are on here.
    BODY

    create_document 'changes.txt', body

    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal last_response.body, body
  end

  def test_index
    create_document 'about.md'
    create_document 'changes.txt'

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_not_exist
    get '/nonexistent.file'
    assert_equal 302, last_response.status

    assert_equal 'nonexistent.file does not exist.', session[:error]

    get last_response['Location']
    assert_equal 200, last_response.status
    refute_equal 'nonexistent.file does not exist.', session[:error]

    get '/'
    assert_equal 200, last_response.status
  end

  def test_about_edit
    body = <<-BODY.chomp
# Ruby is..

A dynamic, open source programming language with a focus on
    BODY

    create_document 'about.md', body

    get '/about.md/edit'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/about.md/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, body
  end

  def test_general_edit
    create_document 'test.txt'

    get '/test.txt/edit'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/test.txt/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<p>Edit content of test.txt:</p>'
    assert_includes last_response.body, '<textarea'
  end

  def test_update_general
    create_document 'test.txt', 'old content'

    post '/test.txt', content: 'new content'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/test.txt', { content: 'new content' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test.txt has been updated.', session[:success]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    get '/test.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal 'new content', last_response.body
    refute_equal 'old content', last_response.body
  end

  def test_new_form
    get '/new'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Add a new document:'
    assert_includes last_response.body, '<form action="/create"'
  end

  def test_file_created
    post '/create', name: 'just_a_test.txt'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/create', { name: 'just_a_test.txt' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'just_a_test.txt has been created.', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<a href="/just_a_test.txt">just_a_test.txt'
    assert_includes last_response.body, '<a href="/just_a_test.txt/edit">edit</a>'
  end

  def test_file_duplication_form
    get '/history.txt/duplicate'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/history.txt/duplicate', {}, admin_session

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, 'Enter name for duplicated history.txt:'
    assert_includes last_response.body, '<button>Create</button>'
    assert_includes last_response.body, 'action="/history.txt/duplicate" method="POST"'
  end

  def test_file_duplication_not_unique_filename
    post '/create', { name: 'hello.txt' }, admin_session
    post '/hello.txt/duplicate', name: 'hello.txt'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Filename must be unique.'
  end

  def test_bad_filename_extension
    post '/create', name: 'hello.txt'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/create', { name: 'hello.yaml' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, invalid_extension_message
  end

  def test_bad_filename_creation
    post '/create', name: ' '

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/create', { name: ' ' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A proper filename is required.'

    post '/create', name: 'file-without-extension'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A proper filename is required.'
  end

  def test_file_deletion
    create_document 'hello.txt', 'hello world'

    post '/hello.txt/delete'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/hello.txt/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_equal 'hello.txt has been deleted.', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    refute_includes last_response.body, '<a href="/hello.txt">hello.txt</a>'
  end

  def test_signout
    get '/', {}, admin_session

    post '/users/signout'

    assert_equal 302, last_response.status
    assert_equal 'You have been signed out.', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<button>Sign In</button>'
  end

  def test_bad_signin_attempt
    post '/users/signin', uname: 'invalid', psswd: 'also invalid'

    assert_equal 422, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Invalid credentials. Please try again.'
    assert_includes last_response.body, 'Username:'
    assert_nil session[:uname]
  end

  def test_signin
    post '/users/signin', uname: 'admin', psswd: 'secret'

    assert_equal 302, last_response.status
    assert_equal session[:success], 'Welcome!'
    assert_equal session[:uname], 'admin'

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Signed in as'
    assert_includes last_response.body, 'New Document'
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<button>Sign In</button>'
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, 'Username: '
  end

  def test_signup_form
    get '/users/signup'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<button>Sign Up</button>'
    assert_includes last_response.body, '<form action="/users/signup" method="POST">'
  end

  def test_signup_user
    post '/users/signup', uname: 'hello', psswd: '12345678'

    assert_equal 302, last_response.status
    assert_equal 'Welcome to the CMS, hello!', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Signed in as hello'
    assert_includes last_response.body, '<button>Sign Out</button>'
  end

  def test_taken_username
    post '/users/signup', uname: 'admin', psswd: 'secret123'
    post '/users/signout'
    post '/users/signup', uname: 'admin', psswd: 'abc123456'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Sorry, admin is already taken.'
    assert_nil session[:uname]
  end
end

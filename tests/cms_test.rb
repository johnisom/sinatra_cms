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
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.write(File.join(data_path, name), content)
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
    assert_equal body, last_response.body
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

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'nonexistent.file does not exist.'

    get '/'
    assert_equal 200, last_response.status
    refute_includes last_response.body, 'nonexistent.file does not exist.'
  end

  def test_about_edit
    body = <<-BODY.chomp
# Ruby is..

A dynamic, open source programming language with a focus on
    BODY

    create_document 'about.md', body
    
    get '/about.md/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, body
  end

  def test_general_edit
    create_document 'test.txt'

    get "/test.txt/edit"

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<p>Edit content of test.txt:</p>'
    assert_includes last_response.body, '<textarea'
  end

  def test_update_general
    create_document 'test.txt', 'old content'
    
    post '/test.txt', content: 'new content'
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'test.txt has been updated'

    get '/test.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_equal 'new content', last_response.body
    refute_equal 'old content', last_response.body
  end

  def test_new_form
    get '/new'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Add a new document:'
    assert_includes last_response.body, '<form action="/create"'
  end

  def test_file_created
    post '/create', name: 'just_a_test.txt'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'just_a_test.txt was created.'
    assert_includes last_response.body, '<a href="/just_a_test.txt">just_a_test.txt'
    assert_includes last_response.body, '<a href="/just_a_test.txt/edit">edit</a>'
  end
end
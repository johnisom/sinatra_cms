ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'

require_relative '../cms'

Minitest::Reporters.use!

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_history_txt
    body = <<-BODY
2007 - Ruby 1.9 released.
2013 - Ruby 2.0 released.
    BODY
    get '/history.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, body
  end

  def test_about_md
    body = <<-BODY
<h1>Ruby is..</h1>

<p>A dynamic, open source programming language with a focus on simplicity and
productivity. It has an elegant syntax that is natural to read and easy to write.</p>
    BODY
    get '/about.md'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_equal body, last_response.body
  end

  def test_changes_txt
    body = <<-BODY
So far, no changes are on here.
    BODY
    get '/changes.txt'
    assert_equal 200, last_response.status
    assert_equal 'text/plain', last_response['Content-Type']
    assert_includes last_response.body, body
  end

  def test_index
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
    assert_includes last_response.body, 'history.txt'
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
end

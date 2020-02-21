# thankyou_test.rb
require 'coveralls'
Coveralls.wear!

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"
require "date"

require_relative "../thankyou_app"
require_relative "../lib/thankyou_manager"
require_relative "../lib/card_collection"


class ThankyouTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    FileUtils.mkdir_p(File.join(data_path, "user_data"))
    ["users.yml", "html_text.yml"].each { |doc| copy_doc_to_data_folder(doc) }
  end

  def copy_doc_to_data_folder(doc_name)
    folderpath = data_path[0..-(("/data").size + 1)]
    src = File.join(folderpath, doc_name)
    dst = File.join(data_path, doc_name)
    FileUtils.cp(src, dst)
  end

  def create_document(doc_name, content="")
    filepath = File.join(data_path, doc_name)
    File.open(filepath, "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session(manager=nil)
    manager ||= create_app_manager("admin")
    { "rack.session" => {username: "admin", manager: manager}}
  end

  def create_card_list
    card_data = [{to: "Somebody", from: "Me", id: 0, sender: "dorey.edinger@gmail.com", recipient: "dorey.edinger@gmail.com",
      item: "candy", message_type: "tons", sent: false, date_sent: nil}, {to: "Another",
      from: "You", id: 1, sender: "dorey.edinger@gmail.com", recipient: "dorey.edinger@gmail.com", 
      item: "candy", message_type: "not", sent: false, date_sent: nil}]
  end

  def create_app_manager(username)
    ThankyouManager.new(username)
  end

  def create_manager_with_cards
    card_list = create_card_list
    manager = create_app_manager("admin")
    card_list.each { |card_data| manager.create_new_card(card_data)}
    manager
  end

  def test_index_without_signin
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "In order to use this site, you must login."
  end

  def test_index_with_signin_no_cards
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_index_with_cards
    manager = create_manager_with_cards

    get "/", {}, admin_session(manager)

    assert_equal 200, last_response.status
    assert_includes last_response.body.encode("UTF-8"), "Signed in as admin"
    assert_includes last_response.body.encode("UTF-8"), "Somebody / candy"
    assert_includes last_response.body.encode("UTF-8"), "Another / candy"
  end

  def test_signup_view
    get "/signup"

    assert_equal 200, last_response.status
    assert_includes last_response.body.encode("UTF-8"), '<label for="username">Username:'
  end

  def test_signup_submit
    post "/signup", {username: "sampleuser", password: "somepass"}

    assert_equal 302, last_response.status
    assert_equal "sampleuser", session[:username]
    assert_equal "Welcome sampleuser.", session[:message]

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), "Signed in as sampleuser"
    refute_includes last_response.body.encode("UTF-8"), '<div id="card-list">'
  end

  def test_signout
    post "/signup", {username: "sampleuser", password: "somepass"}

    assert_equal "sampleuser", session[:username]

    post "/signout"

    assert_equal 302, last_response.status
    refute_equal "sampleuser", session[:username]
    assert_equal "You have signed out.", session[:message]

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), "Welcome to the Thank You Note Generator"
  end

  def test_signin
    post "/signup", {username: "sampleuser", password: "somepass"}

    assert_equal 302, last_response.status

    post "/signout", {}

    assert_equal 302, last_response.status
    
    post "/signin", {username: "sampleuser", password: "somepass"}

    assert_equal 302, last_response.status
    assert_equal "sampleuser", session[:username]

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), "Signed in as sampleuser"
  end

  def test_new_card_form_view
    get "/new-card", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body.encode("UTF-8"), '<form id="new_card_form"'
    assert_includes last_response.body.encode("UTF-8"), "<input type='radio' id='tons'"
  end

  def test_new_card_post
    card_data = create_card_list[0]
    post "/new-card", card_data, admin_session

    assert_equal 302, last_response.status
    assert_equal "You have created a new thank you card!", session[:message]

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), '<p>Dear Somebody'
    assert_includes last_response.body.encode("UTF-8"), '<p>Thank you so much for the candy'
    assert_includes last_response.body.encode("UTF-8"), '<p>Me'
  end

  def test_edit_new_card
    manager = create_manager_with_cards

    get "edit/0", {}, admin_session(manager)

    assert_equal 200, last_response.status
    assert_includes last_response.body.encode("UTF-8"), '<input type="text" name="to" id="to" value="Somebody">'
    assert_includes last_response.body.encode("UTF-8"), "<input type='radio' id='tons' name='message_type' value='tons' checked>"

    card_data = create_card_list[0]
    card_data[:to] = 'Frank'
    card_data[:item] = 'cotton'

    post "edit/0", card_data, admin_session(manager)

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), 'Dear Frank'
    assert_includes last_response.body.encode("UTF-8"), 'Thank you so much for the cotton!'
  end

  def test_create_new_card_without_send
    manager = create_manager_with_cards

    get "/", {}, admin_session(manager)

    assert_equal 200, last_response.status
    assert_includes last_response.body.encode("UTF-8"), 'Somebody / candy'
    assert_includes last_response.body.encode("UTF-8"), 'Another / candy'
  end

  def test_send_created_card
    manager = create_manager_with_cards

    post "/send/1", {}, admin_session(manager)

    assert_equal 302, last_response.status
    assert_equal "Eventually, the email functionality will work, but nothing has been sent.", session[:message]

    get last_response["Location"]

    assert_includes last_response.body.encode("UTF-8"), 'Another / candy'
  end


  def teardown
    FileUtils.rm_rf(data_path)
  end

end
# frozen_string_literal: false

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'
require 'psych'
require 'securerandom'
require 'uri'

require_relative 'lib/thankyou_manager'


def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

configure do |config|
  enable :sessions
  set :session_secret, development? ? 'secret' : SecureRandom.hex(100)
  config.also_reload 'lib/*.rb' if development?
end

helpers do
  def logged_in?
    !!session[:username]
  end

  def log_out
    session.delete(:username)
  end

  def valid_route?(id)
    logged_in? && valid_card_id?(id)
  end

  def valid_credentials?(username, password)
    credentials = load_credentials

    if credentials.key?(username)
      bcrypt_password = BCrypt::Password.new(credentials[username])
      bcrypt_password == password
    else
      false
    end
  end

  def valid_email?(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end

  def error_for_password(password)
    if !(8..16).cover?(password.size)
      'Password must be between 8 and 16 characters.'
    elsif password.match(/\s/)
      'Password must not contain any spaces.'
    end
  end

  def error_for_username(username)
    if load_credentials.key?(username) || username == 'username'
      'That username is taken.'
    elsif !(3..12).cover?(username.size) || username.match(/\s/)
      'Your username must be at least 3 characters and cannot ' /
        'contain any spaces.'
    end
  end

  def error_for_signup(username, password)
    error_for_username(username) || error_for_password(password)
  end

  def error_for_card_data(card_data)
    card_data.each do |k, v|
      if email_input_field?(k)
        return "Invalid email for #{k}" unless valid_email?(v)
      elsif text_input_field?(k)
        return "Invalid input for #{k} field." if v.empty?
      end
    end

    nil
  end

  def edit_mode?
    request.path_info != '/new-card'
  end

  def text_input_field?(field_name)
    %i[to from item].include?(field_name)
  end

  def email_input_field?(field_name)
    %i[sender recipient].include?(field_name)
  end

  def load_messages
    Psych.load_file(File.join(data_path, 'html_text.yml'))
  end

  def load_credentials
    Psych.load_file(File.join(data_path, 'users.yml'))
  end

  def create_new_user(username, password)
    credentials = load_credentials
    credentials[username] = BCrypt::Password.create(password)

    new_credentials = Psych.dump(credentials)

    file_path = File.join(data_path, 'users.yml')
    File.write(file_path, new_credentials)
  end

  def load_cards
    session[:manager]&.retrieve_cards
  end

  def form_value(input_name, card)
    card.var_value(input_name)
  end

  def successful_signin(username)
    session[:username] = username
    session[:message] = "Welcome #{username}."
    session[:manager] = ThankyouManager.new(username)
    redirect '/'
  end

  def valid_card_id?(card_id)
    session[:manager].valid_card_id?(card_id)
  end

  def card_data_from_params(params)
    id = if params[:card_id]
           params[:card_id].to_i
         else
           session[:manager].next_card_id
         end
    { to: params[:to], from: params[:from], sender: params[:sender],
      recipient: params[:recipient], item: params[:item],
      message_type: params[:message_type], id: id, sent: false,
      date_sent: nil }
  end

  def html_for_message_radio_button(message_type, card)
    if (card && card.message_type == message_type) ||
       (card.nil? && message_type == 'tons')
      "<input type='radio' id='#{message_type}' name='message_type'" \
        " value='#{message_type}' checked>"
    else
      "<input type='radio' id='#{message_type}' name='message_type'" \
        " value='#{message_type}'>"
    end
  end

  def clear_session
    session.delete(:manager)
    session.delete(:username)
  end

  def process_card_data(card_data)
    error = error_for_card_data(card_data)

    if error
      flash_message(error)
      view_modified_card(card_data)
      erb :new
    else
      update_card(card_data)
      redirect "/preview/#{card_data[:id]}"
    end
  end

  def update_card(card_data)
    if edit_mode?
      edit_card(card_data)
    else
      create_new_card(card_data)
    end
  end

  def edit_card(card_data)
    session[:manager].edit_card(card_data)
    flash_message('You have edited your thank you card.')
  end

  def create_new_card(card_data)
    session[:manager].create_new_card(card_data)
    flash_message('You have created a new thank you card!')
  end

  def view_saved_card(id)
    @card = session[:manager].retrieve_card(id)
    @message = message_for_card(@card)
  end

  def view_sample_card
    @card = session[:manager].create_sample_card
    @message = message_for_card(@card)
  end

  def view_modified_card(card_data)
    if edit_mode?
      view_modified_saved_card(card_data)
    else
      view_modified_sample_card(card_data)
    end
  end

  def view_modified_saved_card(card_data)
    edit_card(card_data)
    view_saved_card(card_data[:id])
  end

  def view_modified_sample_card(card_data)
    # edit this method when ajax functionality works so that the sample
    # card reflects the saved inputs
    @card = session[:manager].edit_sample_card(card_data)
    @message = message_for_card(@card)
  end

  def message_for_card(card)
    session[:manager].personalize_message_for_card(card)
  end

  def flash_message(msg)
    session[:message] = msg
  end

  def ajax_request?
    env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
  end

  def update_card_with_ajax(saved_inputs)
    view_modified_card(saved_inputs)
    status 204
    erb :new
  end

  def email_card(id)
    session[:manager].send_card(id)
  end

  def sort_cards(cards, &block)
    incomplete_cards, complete_cards = cards.partition { |card| !card.sent }
    incomplete_cards.each(&block)
    complete_cards.each(&block)
  end
end

get '/' do
  if logged_in?
    @card_list = load_cards
  else
    messages = load_messages
    @welcome = messages['welcome']
  end
  erb :index
end

post '/signin' do
  username = params[:username]
  password = params[:password]

  if valid_credentials?(username, password)
    successful_signin(username)
  else
    flash_message('Invalid login.')
    status 422
    erb :index
  end
end

get '/signup' do
  erb :signup
end

post '/signup' do
  username = params[:username]
  password = params[:password]

  error = error_for_signup(username, password)

  if error
    flash_message(error)
    status 422
    erb :signup
  else
    create_new_user(username, password)
    successful_signin(username)
  end
end

post '/signout' do
  log_out
  flash_message('You have signed out.')
  clear_session
  redirect '/'
end

get '/new-card' do
  view_sample_card
  erb :new
end

post '/new-card' do
  saved_inputs = card_data_from_params(params)

  if ajax_request?
    update_card_with_ajax(saved_inputs)
  else
    process_card_data(saved_inputs)
  end
end

get '/preview/:card_id' do
  id = params[:card_id].to_i
  redirect '/' unless valid_route?(id)
  view_saved_card(id)
  erb :preview
end

get '/edit/:card_id' do
  id = params[:card_id].to_i
  redirect '/' unless valid_route?(id)
  view_saved_card(id)
  erb :new
end

post '/edit/:card_id' do
  saved_inputs = card_data_from_params(params)

  if ajax_request?
    update_card_with_ajax(saved_inputs)
  else
    process_card_data(saved_inputs)
  end
end

post '/send/:card_id' do
  flash_message('Eventually, the email functionality will work, ' \
    'but nothing has been sent.')
  id = params[:card_id].to_i
  email_card(id)
  redirect '/'
end

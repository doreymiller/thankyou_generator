# thankyou_manager.rb

require 'fileutils'
require 'psych'
require 'yaml'
require 'pry'
require 'pry-remote'
require 'pry-nav'

require_relative 'user'
require_relative 'card'

class ThankyouManager
  attr_accessor :user, :username, :messages

  def initialize(username)
    @messages = load_messages
    @username = username

    if user_data_exists?
      @user = load_data
    else
      @user = User.new(username)

      create_file
      update_file
    end
  end

  def create_file
    FileUtils.touch(user_filepath)
  end

  def update_file
    user_yml = Psych.dump(user)
    File.write(user_filepath, user_yml)
  end

  def user_filepath
    File.join(data_path, 'user_data', "#{username}.yml")
  end

  def user_data_exists?
    File.exist?(user_filepath)
  end

  def load_data
    filepath = user_filepath
    Psych.load_file(filepath)
  end

  def load_messages
    filepath = File.join(data_path, 'html_text.yml')
    Psych.load_file(filepath)
  end

  def retrieve_cards
    user.retrieve_cards
  end

  def next_card_id
    user.next_card_id
  end

  def create_new_card(card_data)
    user.add_card(card_data)
    update_file
  end

  def create_sample_card
    card_data = { to: 'Somebody', from: 'Me', sender: '', recipient: '',
                  item: 'gift', message_type: 'tons', id: next_card_id }
    Card.new(card_data)
  end

  def edit_sample_card(card_data)
    Card.new(card_data)
  end

  def edit_card(card_data)
    card_id = card_data[:id]
    edited_card = retrieve_card(card_id)
    edited_card.edit(card_data)
    update_file
  end

  def valid_card_id?(card_id)
    card = retrieve_card(card_id)
    !card.nil? && !card.sent
  end

  def retrieve_card(card_id)
    cards = user.retrieve_cards
    cards.find { |card| card.id == card_id }
  end

  def personalize_message_for_card(card)
    message_type = card.message_type
    item = card.item
    message = generic_message(message_type)
    message.sub(/\[(item)\]/, item)
  end

  def generic_message(message_type)
    @messages['messages'][message_type]
  end

  def send_card(id)
    card = retrieve_card(id)
    card.update_sent_status
    update_file
  end
end

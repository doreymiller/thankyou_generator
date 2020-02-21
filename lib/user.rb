# user.rb

require 'pry'
require 'pry-remote'
require 'pry-nav'

require_relative 'card'

class User
  attr_accessor :card_list, :id, :username

  def initialize(username)
    @username = username
    @card_list = []
  end

  def retrieve_cards
    card_list
  end

  def next_card_id
    return 0 if card_list.empty?

    sorted = card_list.sort_by(&:id)
    sorted.last.id + 1
  end

  def add_card(card_data)
    new_card = Card.new(card_data)
    card_list << new_card
  end
end

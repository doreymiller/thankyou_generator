# user.rb

require 'pry'
require 'pry-remote'
require 'pry-nav'

require_relative 'card_collection'

class User
  attr_accessor :card_list, :id, :username

  def initialize(username)
    @username = username
    @card_list = CardCollection.new
  end

  def retrieve_cards
    card_list.cards
  end

  def next_card_id
    return 0 if card_list.empty?

    sorted = card_list.cards.sort_by(&:id)
    sorted.last.id + 1
  end
end

# card_collection.rb

require 'pry'
require 'pry-remote'
require 'pry-nav'

require_relative 'card'

class CardCollection
  attr_accessor :cards

  def initialize
    @cards = []
  end

  def add_card(card_data)
    new_card = Card.new(card_data)
    @cards << new_card
  end

  def empty?
    @cards.empty?
  end
end

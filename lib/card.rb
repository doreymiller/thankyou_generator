# card.rb

require 'date'

class Card
  attr_accessor :to, :from, :message_type, :sender, :recipient, :item, :id,
                :sent, :date_sent

  def initialize(card_data = {})
    edit(card_data)
  end

  def var_value(val_type)
    instance_variable_get("@#{val_type}")
  end

  def edit(card_data)
    @to = card_data[:to]
    @from = card_data[:from]
    @item = card_data[:item]
    @message_type = card_data[:message_type]
    @sender = card_data[:sender]
    @recipient = card_data[:recipient]
    @id = card_data[:id].to_i
    @sent = card_data[:sent]
    @date_sent = card_data[:date_sent]
  end

  def update_sent_status
    self.sent = true
    self.date_sent = DateTime.now
  end

  def date_sent_str
    date_format = '%D %H:%M'
    date_sent.strftime(date_format)
  end
end

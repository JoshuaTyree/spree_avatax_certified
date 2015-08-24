require 'logger'

Spree::Order.class_eval do
  has_one :avalara_transaction, dependent: :destroy

  # self.state_machine.after_transition to: :complete,
  #                                     do: :avalara_capture_finalize,
  #                                     if: :avalara_eligible

 self.state_machine.before_transition to: :canceled,
                                      do: :cancel_status,
                                      if: :avalara_eligible

  def avalara_eligible
    Spree::Config.avatax_iseligible
  end

  def avalara_lookup
    logger.debug 'avalara lookup'
    create_avalara_transaction_order
    :lookup_avatax
  end

  def cancel_status
    return nil unless avalara_transaction.present?
    avalara_transaction.check_status(self)
  end

  def avalara_capture
    logger.debug 'avalara capture'

    begin
      create_avalara_transaction_order
      line_items.reload

      @rtn_tax = avalara_transaction.commit_avatax(line_items, self, number.to_s, Date.today.strftime('%F'), transaction_doc_type)

      logger.info 'tax amount'
      logger.debug @rtn_tax
      @rtn_tax
    rescue => e
      logger.debug e
      logger.debug 'error in avalara capture'
    end
  end

  def avalara_capture_finalize
    logger.debug 'avalara capture finalize'
    begin
      create_avalara_transaction_order
      line_items.reload
      @rtn_tax = avalara_transaction.commit_avatax_final(line_items, self, number.to_s, Date.today.strftime('%F'), transaction_doc_type)

      logger.info 'tax amount'
      logger.debug @rtn_tax
      @rtn_tax
    rescue => e
      logger.debug e
      logger.debug 'error in avalara capture finalize'
    end
  end

  def avatax_cache_key
    key = ['Spree::Order']
    key << number
    key << promo_total
    key.join('-')
  end

  private

  def transaction_doc_type
    if self.payment? || self.confirm? || self.completed?
      'SalesInvoice'
    else
      'SalesOrder'
    end
  end

  def create_avalara_transaction_order
    Spree::AvalaraTransaction.create(order_id: self.id)
  end

  def assign_avalara_transaction
    if avalara_eligible
      if self.avalara_transaction.nil?
        create_avalara_transaction_order
      else
        Spree::AvalaraTransaction.find_by_order_id(self.id).update_attributes(order_id: self.id)
      end
    end
  end

  def logger
    @logger ||= AvataxHelper::AvataxLog.new('avalara_order', 'order class', 'start order processing')
  end
end

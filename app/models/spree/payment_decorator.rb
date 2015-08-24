Spree::Payment.class_eval do
  self.state_machine.after_transition to: :completed,
                                      do: :avalara_finalize

  def avalara_finalize
    binding.pry
    order.avalara_capture_finalize if Spree::Config.avatax_iseligible
  end
end
Spree::CheckoutController.class_eval do
  helper Spree::AddressesHelper
  
  after_filter :normalize_addresses, :only => :update
  before_filter :set_addresses, :only => :update
  
  protected
  
  def set_addresses
    return unless params[:order] && params[:state] == "address"

    @bill_address = current_user.addresses.build(permit_address_params(params[:order][:bill_address_attributes])).check
    unless @bill_address.save
      flash[:error] = @bill_address.errors.full_messages.join("\n")
      redirect_to(checkout_state_path(@order.state)) && return
    end
    params[:order][:bill_address_id] = @bill_address.id

    if params[:order][:use_billing]
      params[:order][:ship_address_id] = @bill_address.id
    else
      @ship_address = current_user.addresses.build(permit_address_params(params[:order][:ship_address_attributes])).check
      unless @ship_address.save
        flash[:error] = @ship_address.errors.full_messages.join("\n")
        redirect_to(checkout_state_path(@order.state)) && return
      end
      params[:order][:ship_address_id] = @ship_address.id
    end

    if params[:order][:ship_address_id].to_i > 0
      params[:order].delete(:ship_address_attributes)

      Spree::Address.find(params[:order][:ship_address_id]).user_id != current_user.id && raise("Frontend address forging")
    else
      params[:order].delete(:ship_address_id)
    end
    
    if params[:order][:bill_address_id].to_i > 0
      params[:order].delete(:bill_address_attributes)

      Spree::Address.find(params[:order][:bill_address_id]).user_id != current_user.id && raise("Frontend address forging")
    else
      params[:order].delete(:bill_address_id)
    end
    
  end

  def normalize_addresses
    return unless params[:state] == "address" && @order.bill_address_id && @order.ship_address_id

    # ensure that there is no validation errors and addresses were saved
    return unless @order.bill_address and @order.ship_address
    
    bill_address = @order.bill_address
    ship_address = @order.ship_address
    if @order.bill_address_id != @order.ship_address_id && bill_address.same_as?(ship_address)
      @order.update_column(:bill_address_id, ship_address.id)
      bill_address.destroy
    else
      bill_address.update_attribute(:user_id, spree_current_user.try(:id))
    end

    ship_address.update_attribute(:user_id, spree_current_user.try(:id))
  end

  private

  def permit_address_params(params)
    params.permit(:address,
                  :firstname,
                  :lastname,
                  :address1,
                  :address2,
                  :city,
                  :state_id,
                  :zipcode,
                  :country_id,
                  :phone)
  end
end

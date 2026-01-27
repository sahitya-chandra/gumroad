# frozen_string_literal: true

module Products
  module Edit
    class ReceiptController < BaseController
      def edit
        @title = @product.name

        render inertia: "Products/Edit/Receipt", props: Products::Edit::ReceiptTabPresenter.new(product: @product, pundit_user:).props
      end

      def update
        begin
          ActiveRecord::Base.transaction do
            update_receipt_attributes
          end
        rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
          error_message = @product.errors.full_messages.first || e.message
          flash[:error] = error_message
          return redirect_back fallback_location: products_edit_receipt_path(@product.external_id)
        end

        flash[:notice] = "Your changes have been saved!"
        check_offer_codes_validity

        if request.inertia?
          redirect_to products_edit_receipt_path(id: @product.unique_permalink)
        else
          render json: { success: true }
        end
      end

      private

        def update_receipt_attributes
          @product.assign_attributes(product_permitted_params.except(:custom_domain))
          @product.save!
        end

        def product_permitted_params
          scope = params[:product].present? ? params.require(:product) : params
          scope.permit(policy(@product).receipt_tab_permitted_attributes)
        end
    end
  end
end

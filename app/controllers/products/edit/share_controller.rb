# frozen_string_literal: true

module Products
  module Edit
    class ShareController < BaseController
      def edit
        @title = @product.name

        render inertia: "Products/Edit/Share", props: Products::Edit::ShareTabPresenter.new(product: @product, pundit_user:).props
      end

      def update
        begin
          ActiveRecord::Base.transaction do
            update_share_attributes
          end
        rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
          error_message = @product.errors.full_messages.first || e.message
          flash[:error] = error_message
          return redirect_back fallback_location: products_edit_share_path(@product.external_id)
        end

        flash[:notice] = "Your changes have been saved!"
        check_offer_codes_validity

        if request.inertia?
          redirect_to products_edit_share_path(id: @product.unique_permalink)
        else
          render json: { success: true }
        end
      end

      private

        def update_share_attributes
          @product.assign_attributes(product_permitted_params.except(:tags))
          @product.save_tags!(product_permitted_params[:tags] || [])
          update_custom_domain if product_permitted_params.key?(:custom_domain)
          @product.save!
        end

        def update_custom_domain
          if product_permitted_params[:custom_domain].present?
            custom_domain = @product.custom_domain || @product.build_custom_domain
            custom_domain.domain = product_permitted_params[:custom_domain]
            custom_domain.verify(allow_incrementing_failed_verification_attempts_count: false)
            custom_domain.save!
          elsif product_permitted_params[:custom_domain] == "" && @product.custom_domain.present?
            @product.custom_domain.mark_deleted!
          end
        end

        def product_permitted_params
          scope = params[:product].present? ? params.require(:product) : params
          scope.permit(policy(@product).share_tab_permitted_attributes)
        end
    end
  end
end

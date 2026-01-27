# frozen_string_literal: true

module Products
  module Edit
    class ContentController < BaseController
      def edit
        @title = @product.name

        render inertia: "Products/Edit/Content", props: Products::Edit::ContentTabPresenter.new(product: @product, pundit_user:).props
      end

      def update
        begin
          ActiveRecord::Base.transaction do
            update_content_attributes
          end
        rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid, Link::LinkInvalid => e
          error_message = @product.errors.full_messages.first || e.message
          flash[:error] = error_message
          return redirect_back fallback_location: products_edit_content_path(@product.external_id)
        end

        flash[:notice] = "Your changes have been saved!"
        check_offer_codes_validity

        if request.inertia?
          redirect_to products_edit_content_path(id: @product.unique_permalink)
        else
          render json: { success: true }
        end
      end

      private
        def update_content_attributes
          @product.assign_attributes(product_permitted_params.except(:files, :variants, :custom_domain, :rich_content))
          SaveFilesService.perform(@product, product_permitted_params, rich_content_params)
          update_rich_content
          @product.save!
          @product.generate_product_files_archives!
        end

        def update_rich_content
          rich_content = product_permitted_params[:rich_content] || []
          existing_rich_contents = @product.alive_rich_contents.to_a
          rich_contents_to_keep = []

          rich_content.each.with_index do |product_rich_content, index|
            rc = existing_rich_contents.find { |c| c.external_id === product_rich_content[:id] } || @product.alive_rich_contents.build
            description = product_rich_content[:description].to_h[:content]
            product_rich_content[:description] = SaveContentUpsellsService.new(
              seller: @product.user,
              content: description,
              old_content: rc.description || []
            ).from_rich_content
            rc.update!(title: product_rich_content[:title].presence, description: product_rich_content[:description].presence || [], position: index)
            rich_contents_to_keep << rc
          end

          (existing_rich_contents - rich_contents_to_keep).each(&:mark_deleted!)
        end

        def rich_content_params
          rich_content = product_permitted_params[:rich_content] || []
          rich_content_params = [*rich_content]
          product_permitted_params[:variants]&.each { rich_content_params.push(*_1[:rich_content]) }
          rich_content_params.flat_map { _1[:description] = _1.dig(:description, :content) }
        end

        def product_permitted_params
          scope = params[:product].present? ? params.require(:product) : params
          scope.permit(policy(@product).content_tab_permitted_attributes)
        end
    end
  end
end

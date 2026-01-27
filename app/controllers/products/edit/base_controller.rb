# frozen_string_literal: true

module Products
  module Edit
    class BaseController < Sellers::BaseController
      before_action :fetch_product
      before_action :authorize_product

      layout "inertia"

      private
        def fetch_product
          @product = Link.fetch_leniently(params[:id], user: current_seller) || Link.fetch_leniently(params[:id])
          raise(ActiveRecord::RecordNotFound) if @product.nil? || @product.archived? || @product.deleted_at.present?
        end

        def authorize_product
          authorize @product
        end

        def presenter
          @presenter ||= ProductPresenter.new(product: @product, pundit_user:)
        end

        def base_props
          {
            id: @product.external_id,
            unique_permalink: @product.unique_permalink,
            product: {
              name: @product.name,
              is_published: !@product.draft && @product.alive?,
              native_type: @product.native_type,
            },
            seller: UserPresenter.new(user: @product.user).author_byline_props,
          }
        end

        def product_permitted_params
          params.permit(policy(@product).product_permitted_attributes)
        end

        def check_offer_codes_validity
          invalid_currency_offer_codes = @product.product_and_universal_offer_codes.reject do |offer_code|
            offer_code.is_currency_valid?(@product)
          end.map(&:code)
          invalid_amount_offer_codes = @product.product_and_universal_offer_codes.reject { _1.is_amount_valid?(@product) }.map(&:code)

          all_invalid_offer_codes = (invalid_currency_offer_codes + invalid_amount_offer_codes).uniq

          if all_invalid_offer_codes.any?
            has_currency_issues = invalid_currency_offer_codes.any?
            has_amount_issues = invalid_amount_offer_codes.any?

            if has_currency_issues && has_amount_issues
              issue_description = "#{"has".pluralize(all_invalid_offer_codes.count)} currency mismatches or would discount this product below #{@product.min_price_formatted}"
            elsif has_currency_issues
              issue_description = "#{"has".pluralize(all_invalid_offer_codes.count)} currency #{"mismatch".pluralize(all_invalid_offer_codes.count)} with this product"
            else
              issue_description = "#{all_invalid_offer_codes.count > 1 ? "discount" : "discounts"} this product below #{@product.min_price_formatted}, but not to #{MoneyFormatter.format(0, @product.price_currency_type.to_sym, no_cents_if_whole: true, symbol: true)}"
            end

            flash[:warning] = "The following offer #{"code".pluralize(all_invalid_offer_codes.count)} #{issue_description}: #{all_invalid_offer_codes.join(", ")}. Please update #{all_invalid_offer_codes.length > 1 ? "them or they" : "it or it"} will not work at checkout."
          end
        end
    end
  end
end

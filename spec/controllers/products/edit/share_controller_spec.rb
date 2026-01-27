# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorize_called"
require "inertia_rails/rspec"

describe Products::Edit::ShareController, inertia: true do
  let(:seller) { create(:named_seller) }
  let(:product) { create(:product, user: seller) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    it "renders the Products/Edit/Share component" do
      get :edit, params: { id: product.unique_permalink }

      expect(response).to be_successful
      expect(inertia).to render_component("Products/Edit/Share")
      expect(inertia.props).to include(:product, :id, :unique_permalink)
    end
  end

  describe "PATCH update" do
    let(:params) do
      {
        id: product.unique_permalink,
        is_adult: true,
        display_product_reviews: false
      }
    end

    context "with Inertia request" do
      before { request.headers["X-Inertia"] = "true" }

      it "updates the share info and redirects" do
        patch :update, params: params

        expect(response).to redirect_to(products_edit_share_path(id: product.unique_permalink))
        expect(flash[:notice]).to eq("Your changes have been saved!")
        expect(product.reload.is_adult).to be(true)
        expect(product.display_product_reviews).to be(false)
      end
    end

    context "with JSON API request" do
      it "updates the share info and returns success JSON" do
        patch :update, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ "success" => true })
        expect(product.reload.is_adult).to be(true)
        expect(product.display_product_reviews).to be(false)
      end
    end
  end
end

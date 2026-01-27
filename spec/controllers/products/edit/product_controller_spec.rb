# frozen_string_literal: true

require "spec_helper"
require "shared_examples/authorize_called"
require "inertia_rails/rspec"

describe Products::Edit::ProductController, inertia: true do
  let(:seller) { create(:named_seller) }
  let(:product) { create(:product, user: seller) }

  include_context "with user signed in as admin for seller"

  describe "GET edit" do
    it "renders the Products/Edit/Product component" do
      get :edit, params: { id: product.unique_permalink }

      expect(response).to be_successful
      expect(inertia).to render_component("Products/Edit/Product")
      expect(inertia.props).to include(:product, :id, :unique_permalink)
      expect(inertia.props[:product][:name]).to eq(product.name)
    end

    context "when not authorized" do
      let(:other_user) { create(:user) }

      before { sign_in other_user }

      it "redirects to product page" do
        get :edit, params: { id: product.unique_permalink }
        expect(response).to redirect_to(short_link_path(product))
      end
    end
  end

  describe "PATCH update" do
    let(:params) do
      {
        id: product.unique_permalink,
        name: "Updated Name",
        description: "Updated Description"
      }
    end

    context "with Inertia request" do
      before { request.headers["X-Inertia"] = "true" }

      it "updates the product and redirects to edit path" do
        patch :update, params: params

        expect(product.reload.name).to eq("Updated Name")
        expect(product.description).to eq("Updated Description")
        expect(response).to redirect_to(edit_link_path(id: product.unique_permalink))
        expect(flash[:notice]).to eq("Your changes have been saved!")
      end
    end

    context "with JSON API request" do
      it "updates the product and returns success JSON" do
        patch :update, params: params, as: :json

        expect(product.reload.name).to eq("Updated Name")
        expect(product.description).to eq("Updated Description")
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ "success" => true })
      end
    end
  end
end

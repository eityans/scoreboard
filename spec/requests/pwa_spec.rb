require "rails_helper"

RSpec.describe "PWA" do
  describe "GET /manifest" do
    it "returns the PWA manifest as JSON" do
      get "/manifest"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to match(/(application\/manifest\+json|application\/json)/)
      expect(response.body).to include("Scoreboard")
    end
  end

  describe "GET /service-worker" do
    it "returns the service worker as JavaScript" do
      get "/service-worker"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to match(/javascript/)
      expect(response.body).to include("CACHE_NAME")
    end
  end
end

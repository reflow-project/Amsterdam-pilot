require 'test_helper'

class NarrativesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get narratives_show_url
    assert_response :success
  end

end

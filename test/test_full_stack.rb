require File.dirname(__FILE__) + '/helper'

class ThemedController < ActionController::Base #:nodoc:
  attr_accessor :themer
  
  # This is what Rails gives us mostly
  begin
    self.template_root = 'app/views'
  rescue NoMethodError # Rails 2, we must set out special dir as one of the view paths
    self.prepend_view_path RAILS_ROOT + '/app/views-per-site' unless view_paths.include?(RAILS_ROOT + '/app/views-per-site')
    ActionView::TemplateFinder.process_view_paths(view_paths)
  end
  
  before_filter do | c |
    c.themer = Themer::Base.new(c.request.stash)
  end
  
  def overridable
    render :themer => @themer
  end
  
  def traditional_action_option
    render :themer => @themer, :action => "overridable"
  end
  
  def traditional_action_option_with_specific_layout
    render :themer => @themer, :action => "overridable", :layout => "very_special"
  end
  
  def action_with_specific_options
    render :themer => @themer, :action => "overridable", :status => 201
  end
  
  def action_without_layout
    render :themer => @themer, :action => "overridable", :layout => false
  end
  
  def action_rendering_a_partial
    render :themer => @themer, :partial => "quack", :locals => {:quack => "???"}
  end
  
  def action_rendering_a_partial_collection
    render :themer => @themer, :partial => "quack", :collection => (1..3).to_a
  end
  
  def action_rendering_with_intrinsics
    render :update do | page |
      raise Exception, "Poo!"
    end
  end
  
  def action_rendering_a_partial_via_actionview
    render :inline => '<%= render :partial => "quack", :themer => @themer %>'
  end

  def action_rendering_a_partial_collection_via_actionview
    render :inline => '<%= render :partial => "quack", :collection => ("a".."c").to_a, :themer => @themer %>'
  end
  
  def action_rendering_a_partial_conventionally_via_actionview
    render :inline => '<%= render :partial => "quack" %>'
  end
end

class TestFullStack < Test::Unit::TestCase
  
  def setup
    setup_for_controller ThemedController
    emit_view_structure
    @request.stash = 'hecticelectric'
  end
  
  def teardown
    super
    destroy_view_structure
  end
  
  def test_A_controller_includes_module
    assert @controller.class.ancestors.include?(Themer::ControllerMethods)
    assert @controller.respond_to?(:render_with_themes)
  end

  def test_A_view_includes_module
    assert ActionView::Base.ancestors.include?(Themer::ControllerMethods)
    assert ActionView::Base.instance_methods.include?("render_with_themes")
  end
  
  def test_preserves_block_on_render
    assert_raise(Exception) do
      get :action_rendering_with_intrinsics
    end
  end
  
  def test_action_and_layout_used_properly_via_themer
    get :overridable
    assert_equal "The layout for hectic The action is overridden for hectic", @response.body

    @request.stash = 'avp'
    get :overridable
    assert_equal "The base layout The action for everyone", @response.body
  end
  
  def test_render_action_should_attach_layout_because_render_file_wont
    get :traditional_action_option
    assert_equal "The layout for hectic The action is overridden for hectic", @response.body
  end

  def test_render_action_and_specific_layout
    get :traditional_action_option_with_specific_layout
    assert_equal "The very special layouts The action is overridden for hectic", @response.body
  end
  
  def test_render_bypasses_foreign_options_to_actual_render
    get :action_with_specific_options
    assert_response 201
    assert_equal "The layout for hectic The action is overridden for hectic", @response.body
  end
  
  def test_render_bypasses_layout_if_layout_disabled
    get :action_without_layout
    assert_equal "The action is overridden for hectic", @response.body
  end

  def test_render_partial
    get :action_rendering_a_partial
    assert_equal "Quack!???", @response.body
  end
  
  def test_render_partial_collections
    get :action_rendering_a_partial_collection
    assert_equal "Quack!1Quack!2Quack!3", @response.body
  end

  def test_render_partial_via_actionview
    get :action_rendering_a_partial_via_actionview
    assert_equal "Quack!", @response.body
  end
  
  def test_render_partial_collection_via_actionview
    get :action_rendering_a_partial_collection_via_actionview
    assert_equal "Quack!aQuack!bQuack!c", @response.body
  end
end
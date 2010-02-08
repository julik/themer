require File.dirname(__FILE__) + '/helper'

class TestThemer < Test::Unit::TestCase
  
  def setup
    setup_mock_facilities
    
    @themer_for_hectic = Themer::Base.new "hecticelectric"
    @themer_for_avp = Themer::Base.new "avp"
    
    # A mock controller with a mock action for mock translations of mock renders (bah!)
    mock_controller_class = flexmock(:template_root => 'app/views')
    
    @mock_controller = flexmock(:action_name => "overridable", :class => mock_controller_class)
    
    @overridable = fp(rhtml('/hecticelectric/actions/overridable'))
    @layout = vp(rhtml('/hecticelectric/layouts/layout'))
    emit_view_structure
  end
  
  def teardown
    super
    destroy_view_structure
  end
  
  def test_detect_in
    kiwiargs_totally_without = []
    assert_nil Themer.detect_in(kiwiargs_totally_without)

    kiwiargs_without = [:a, "bloop", {:shtoink => 2}]
    assert_nil Themer.detect_in(kiwiargs_without)

    kiwiargs_with_nil = [:a, "bloop", {:themer => nil}]
    assert_raise(RuntimeError) { Themer.detect_in(kiwiargs_with_nil)}

    kiwiargs_with = [:a, "bloop", {:themer => 5}]
    assert_equal 5, Themer.detect_in(kiwiargs_with)
    assert !kiwiargs_with[-1].has_key?(:themer), "The key should have been removed"
  end
  
  def test_properly_sets_base_and_special_path
    assert_equal '_base', @themer_for_hectic.base_subdir
    assert_equal 'avp', @themer_for_avp.special_subdir
    assert_equal 'hecticelectric', @themer_for_hectic.special_subdir
  end
  
  def test_detects_proper_layout
    
    err = assert_raise(Themer::NoSuitableTemplate, "Should bail when the layout isn't found") do
      @themer_for_hectic.layout_path "the_layout_that_wasnt"
    end
    assert_kind_of ActionView::ActionViewError, err
    
    with_relative_root_set do
      assert_equal vp(rhtml('/hecticelectric/layouts/layout')), @themer_for_hectic.layout_path("layout"),
        "should give us the layout in the hectic dir, relative to the template_root"
      
      assert_equal vp(rhtml('/hecticelectric/layouts/layout')), @themer_for_hectic.layout_path,
        "should assume 'layout' as default layout name and pick it from customs"
    
      assert_equal vp(rhtml('/_base/layouts/custom')), @themer_for_hectic.layout_path("custom"),
        "The 'custom' layout is not present in the hectic dir so the lookup should point us to _base"
      
      assert_equal vp(rhtml('/hecticelectric/layouts/custom_for_hectic')), @themer_for_hectic.layout_path("custom_for_hectic"),
        "The 'custom_for_hectic' layout is avaliable to it"
    
      assert_raise(Themer::NoSuitableTemplate, "Should bail - no custom_for_hectic for AVP") do
        @themer_for_avp.layout_path("custom_for_hectic")
      end
    end
  end
  
  def test_detects_proper_action
    assert_raise(ArgumentError, "action_path should not assume any defaults") { @themer_for_hectic.action_path }
    
    assert_raise(Themer::NoSuitableTemplate, "Should bail when the action isn't found") do
      @themer_for_hectic.action_path "unknown_action"
    end
    
    assert_equal fp(rhtml('/hecticelectric/actions/overridable')), @themer_for_hectic.action_path("overridable"),
      "should give us the action in the hectic dir"
    
    assert_equal fp(rhtml('/_base/actions/overridable')), @themer_for_avp.action_path("overridable"),
      "should give us the action in the base"

    assert_equal fp(rhtml('/hecticelectric/actions/custom_for_hectic')), @themer_for_hectic.action_path("custom_for_hectic"),
      "should find the custom template"
    
    assert_raise(Themer::NoSuitableTemplate) do
      @themer_for_avp.action_path "custom_for_hectic"
    end
  end
  
  def test_detects_proper_partial
    assert_raise(ArgumentError, "partial_path should not assume any defaults") { @themer_for_hectic.partial_path }
    
    with_relative_root_set do
      assert_raise(Themer::NoSuitableTemplate, "Should bail when the partial isn't found") do
        @themer_for_hectic.partial_path "unknown_stukje"
      end
      
      assert_equal vp('/hecticelectric/partials/overridable'), @themer_for_hectic.partial_path("overridable"),
        "should give us the partial in the hectic dir, no underscore"
      
      assert_equal vp('/_base/partials/overridable'), @themer_for_avp.partial_path("overridable"),
        "should give us the partial in the base, no underscore"
      
      assert_equal vp('/hecticelectric/partials/custom_for_hectic'), @themer_for_hectic.partial_path("custom_for_hectic"),
        "should find the custom template, no underscore"
      
      assert_raise(Themer::NoSuitableTemplate) do
        @themer_for_avp.action_path "custom_for_hectic"
      end
    end
  end

  def test_accepts_options_in_different_formats
    assert_raise(ArgumentError) do
      Themer::Base.new(:a => "1", :woof => 2)
    end
    
    assert_nothing_raised do
      opts = {:themes_dir => "/foo/bar/baz", :special_subdir => "xx", :cache_results => false}
      @themer = Themer::Base.new(opts)
      opts.each_pair do | k, retval |
        assert_equal retval, @themer.send(k)
      end
    end
  end
  
  private
  def with_relative_root_set
    root = 'app/views'
    @themer_for_hectic.relative_to(root) do
      @themer_for_avp.relative_to(root) do
        yield
      end
    end
  end
end

class TestThemerOptionTranslation < Test::Unit::TestCase
  
  def setup
    
    @themer_for_hectic = Themer::Base.new "hecticelectric"
    @themer_for_avp = Themer::Base.new "avp"
    
    # A mock controller with a mock action for mock translations of mock renders (bah!)
    controller_template_root = 'app/views'
    mock_controller_class = flexmock(:template_root => controller_template_root)
    
    @mock_controller = flexmock(:action_name => "overridable", :class => mock_controller_class)
    
    @overridable = fp(rhtml('/hecticelectric/actions/overridable'))
    @layout = vp(rhtml('/hecticelectric/layouts/layout'))
    emit_view_structure
  end
  
  def teardown
    super
    destroy_view_structure
  end

  def test_properly_substitutes_action_path_with_file_path_and_appends_defaut_layout
    assert_equal({:layout => @layout, :file => @overridable}, translate_render)
  end

  def test_properly_relativizes_options_for_layout
    assert_equal({:layout => rhtml("/../views-per-site/_base/layouts/custom"), :file => @overridable}, translate_render(:layout => "custom"))
  end
  
  def test_properly_passes_layout_off
    assert_equal({:file => @overridable, :layout => false}, translate_render(:layout => false))
  end
  
  def test_properly_relativizes_partial_path
    assert_equal({:partial => '/../views-per-site/_base/partials/quack'}, translate_render(:partial => 'quack'))
  end
  
  private
    def translate_render(opts = {})
      Themer.translate_to_normal_render @mock_controller, @themer_for_hectic, opts
    end
end

class TestThemerCache < Test::Unit::TestCase
  def setup
    @themer = Themer::Base.new :special_subdir => 'hecticelectric'
    emit_view_structure
  end
  
  def teardown
    super
    destroy_view_structure
    Themer::Base.cache = {}
  end
  
  def test_action_lookup_asks_the_cache
    full_slot = [@themer.themes_dir, @themer.base_subdir, @themer.special_subdir, @themer.ref_path, :action, "overridable"]
    return_data = fp(rhtml('/hecticelectric/actions/overridable'))
    cache_container = flexmock
    cache_container.should_receive(:[]).with(full_slot).at_least.once.and_return(nil)    
    cache_container.should_receive(:[]=).with(full_slot, return_data).at_least.once.and_return(return_data)    
    
    Themer::Base.cache = cache_container
    
    assert_equal return_data, @themer.action_path("overridable"), "Should give us the action in the hectic dir"
  end
  
  def test_action_lookup_uses_cached_data_as_provided_by_cache
    full_slot = [@themer.themes_dir, @themer.base_subdir, @themer.special_subdir, @themer.ref_path, :action, "overridable"]
    return_data = "THIS/IS/CACHED"
    
    cache_container = flexmock
    cache_container.should_receive(:[]).with(full_slot).at_least.once.and_return(return_data)
    Themer::Base.cache = cache_container
    assert_equal return_data, @themer.action_path("overridable"), "Should give us the action in the hectic dir"
  end
  
  def test_other_caching
    test_caching_with(:partial, "foobar")
    test_caching_with(:layout, "foobar")
    test_caching_with(:layout, "another")
  end
  
  def test_flush_cache
    mock_hash = flexmock("cache hash")
    mock_hash.should_receive(:clear).with_no_args.once
    Themer::Base.cache = mock_hash
    Themer::Base.flush_cache!
  end

  private
    def test_caching_with(template_type, name)
      full_slot = [@themer.themes_dir, @themer.base_subdir, @themer.special_subdir, @themer.ref_path, template_type.to_sym, "overridable"]
      return_data = "cached result for #{template_type} #{name}"
      
      cache_container = flexmock
      cache_container.should_receive(:[]).with(full_slot).at_least.once.and_return(return_data)
      Themer::Base.cache = cache_container
      assert_equal return_data, @themer.send("#{template_type}_path", "overridable"), "Should give us the action in the hectic dir"
    end
end
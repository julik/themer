require 'rubygems'

require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'

require 'fileutils'
require 'stringio'

begin
  require 'multi_rails_init'
rescue LoadError
end

require 'action_controller'
require 'action_controller/test_process'

RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)
RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + '/rails-root')
ABS_RAILS_ROOT = File.expand_path(RAILS_ROOT)

require File.dirname(__FILE__)  + '/../init'

ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/:action/:id'
end

class Test::Unit::TestCase
  private
    def setup_for_controller(controller)
      @controller = controller.new
      # Re-raise errors of the controller and override some plugin-added methods that we need to check
      class << @controller
        def rescue_action(e); raise e; end
      end
      @request = ActionController::TestRequest.new
      class << @request
        attr_accessor :stash
      end
      @response = ActionController::TestResponse.new
      
    end
    
    def setup_mock_facilities
      return if @hectic

      @hectic = flexmock(:templates_dir => 'hecticelectric')
      @avp = flexmock(:templates_dir => 'avp')
    end
    
    def emit_view_structure
      
      templates_dir = File.expand_path(RAILS_ROOT + '/app/views-per-site')
      FileUtils.mkdir_p templates_dir
      
      bp = templates_dir + '/_base'
      he = templates_dir + '/hecticelectric'
      avp = templates_dir + '/avp'
     
      # Create fake layouts
      FileUtils.mkdir_p( bp + '/layouts')
      emit_file(bp + rhtml('/layouts/layout')) { "The base layout <%= yield %>" }
      emit_file(bp + rhtml('/layouts/custom')) { "The base layout <%= yield %>" }
      emit_file(bp + rhtml('/layouts/very_special')) { "The very special layouts <%= yield %>" }

      FileUtils.mkdir_p( he + '/layouts')
      emit_file(he + rhtml('/layouts/layout')) { "The layout for hectic <%= yield %>" }
      emit_file(he + rhtml('/layouts/custom_for_hectic')) { "The custom layout for hectic <%= yield %>" }
  
      # Create fake actions
      FileUtils.mkdir_p( bp + '/actions')
      emit_file(bp + rhtml('/actions/overridable')) { "The action for everyone" }

      FileUtils.mkdir_p( he + '/actions')
      emit_file(he + rhtml('/actions/overridable')) { "The action is overridden for hectic" }
      emit_file(he + rhtml('/actions/custom_for_hectic')) { "The custom action for hectic" }

      # Create fake partials
      FileUtils.mkdir_p( bp + '/partials')
      emit_file(bp + rhtml('/partials/_overridable')) { "The action for everyone" }
      emit_file(bp + rhtml('/partials/_quack')) { "Quack!<%= quack %>" }
      
      FileUtils.mkdir_p( he + '/partials')
      emit_file(he + rhtml('/partials/_overridable')) { "The action is overridden for hectic" }
      emit_file(he + rhtml('/partials/_custom_for_hectic')) { "The custom action for hectic" }
      
      # For Rails 2.1 we need to refresh the template lookup cache by hand
      if defined?(ActionView::TemplateFinder)
        ActionView::TemplateFinder.send(:class_variable_set, '@@processed_view_paths', {})
        ActionView::TemplateFinder.process_view_paths(RAILS_ROOT + '/app/views-per-site')
      end
      
    end
    
    def destroy_view_structure
      Dir.glob(ABS_RAILS_ROOT + '/app/views-per-site/*').map do | emitted |
        FileUtils.rm_rf emitted
      end
    end
    
    # rhtml extension is changed in rails 2.1
    def rhtml(path)
      (defined?(ActionView::TemplateFinder) ? '%s.html.erb' : '%s.rhtml') % path
    end
    
    def emit_file(path)
      File.open(path, 'w') { | f | f << yield }
    end
    
    # Get absolute path to the argument
    def fp(arg)
      File.join(ABS_RAILS_ROOT, 'app', 'views-per-site', arg)
    end
    
    # Get path to the argument from app/views
    def vp(arg)
      ("/../views-per-site/%s" % arg).squeeze("/")
    end
end


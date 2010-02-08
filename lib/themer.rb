# While Rails Core cannot decide on proper way to do request-based template lookups we reinvent the
# wheel and search for specific templates using a decorator, and let the tests be our salvation.
# The trick of the trade here is the way we feed ActionView paths relative to the assumed template
# directory of the controller
require 'pathname'

module Themer
  
  def self.detect_in(args) #:nodoc:
    return unless args.last.is_a?(Hash)
    return unless args.last.has_key?(:themer)
    raise "Themer cannot be nil" if args.last[:themer].nil?
    args.last.delete(:themer)
  end
  
  class NoTemplateRoot < RuntimeError; end
  class NoSuitableTemplate < ActionView::ActionViewError; end
  
  # Gets mixed into the controllers and view classes.
  # Gives you the render_with_themes method and 
  # the :themer key that you can use for render calls.
  module ControllerMethods
    def self.included(base)
      base.alias_method_chain :render, :themes
      super(base)
    end

    # Renders the template looking it up via the passed Themer or bypassing it. It accepts exactly
    # the same options as a conventional :render: but will it will look for templates
    # according to rules that you specify.
    def render_with_themes(*args, &maybe_block)
      unless (themer_obj = Themer.detect_in(args))
        return render_without_themes(*args, &maybe_block)
      end
      ctr = kind_of?(ActionController::Base) ?  self : controller
      args[-1] = Themer.translate_to_normal_render(ctr, themer_obj, args.last)
      render_without_themes(*args, &maybe_block)
    end
  end

  ActionController::Base.send(:include, ControllerMethods)
  ActionView::Base.send(:include, ControllerMethods)
  
  # An inbetween which allows us to be Rails 2.1 compat
  def self.get_template_root(from_controller)
    begin
      from_controller.class.template_root
    rescue NoMethodError # Rails 2
      from_controller.view_paths.first
    end
  end
  
  # Transforms special render options into options suitable for vanilla render.
  # The controller wil be passed here, along with the Themer object
  # that will be asked to provide the view paths
  def self.translate_to_normal_render(controller, lookup, options = {})
    rel_root = absolutize_from_rails_root(get_template_root(controller))
    lookup.relative_to(rel_root) do
       
       options[:action] ||= controller.action_name unless options[:partial]
       
       if options.has_key?(:layout) && (options[:layout] != false)
         options[:layout] = lookup.layout_path(options[:layout])
       elsif !options.has_key?(:layout) && !options[:partial] # default layout
         # this is actually not to Rails' standards because we do not validate the various
         # layout-related classvars
         options[:layout] = lookup.layout_path
       end
       
       actual_template = if options[:action]
         options[:file] = lookup.action_path(options.delete(:action))
       elsif options[:partial]
         options[:partial] = lookup.partial_path(options.delete(:partial))
       end
       options
    end
  end
  
  # This returns an absolute filesystem path to something given a path to it
  # relative to the RAILS_ROOT
  def self.absolutize_from_rails_root(path)
    # Usually the template_root is relative to RAILS_ROOT, but might be otherwise
    re = unless path =~ /^\// # root is relative, prepend RAILS_ROOT and translate
      path.replace File.expand_path(File.join(CLEAN_RAILS_ROOT, path))
    else
      File.expand_path(path)
    end
  end
  
  CLEAN_RAILS_ROOT = File.expand_path(RAILS_ROOT) #:nodoc:
  
  # The most standard template lookup that just accepts a custom directory name as
  # the overriding one. It will look for templates in RAILS_ROOT/app/views-per-site
  class Core
    
    ActionController::Base.send(:included, ControllerMethods)

    # The directory that contains the themes (absolute paths please!)
    attr_accessor :themes_dir

    # The name of the subdirectory containing the theme base    
    attr_accessor :base_subdir

    # The name of the subdirectory containing the overlay templates
    attr_accessor :special_subdir
    
    # Should the results be cached? (searching for files is expensive)
    attr_accessor :cache_results
    
    
    cattr_accessor :cache
    @@cache = {}
    
    # Clear the cached lookups
    def self.flush_cache!
      @@cache.clear
    end
    
    def initialize(*arguments)
      @special_subdir = arguments.shift if arguments[0].is_a?(String)
      
      if arguments[-1].is_a?(Hash)
        make_ivars_from_options(arguments.pop)
      end
      
      @themes_dir ||= File.join(CLEAN_RAILS_ROOT, 'app/views-per-site')
      @base_subdir ||= "_base"
      @cache_results = true unless (@cache_results === false)
      @ref_path ||= Themer.absolutize_from_rails_root("app/views")
    end
    
    # Detects the path to the layout template
    def layout_path(name = "layout")
      cached_result(:layout, name) do
        name = make_shorthand_globbable(name)
        glob_patterns = all_paths.map {| where | layout_path_within(where, name) }
        relative_to_views grab_one(glob_patterns)
      end
    end

    # Detects the path to the action template
    def action_path(name)
      cached_result(:action, name) do
        name = make_shorthand_globbable(name)
        glob_patterns = all_paths.map { | where |  action_path_within(where, name) }
        grab_one(glob_patterns)
      end
    end
    
    # Runs the block assuming that RAILS_ROOT/app/views is rel_root
    def relative_to(rel_root, &block)
      begin
        saved = @ref_path
        @ref_path = Themer.absolutize_from_rails_root(rel_root)
        yield
      ensure
        @ref_path = saved
      end
    end

    # Detects the path to partial template
    def partial_path(name)
      cached_result(:partial, name) do
        globbable = make_shorthand_globbable(name)
        glob_patterns = all_paths.map { | where | partial_path_within(where, "_" + globbable) }
        relative_to_views File.dirname(grab_one(glob_patterns)) + '/' + name
      end
    end
    
    # Get the reference path (the path that Rails would use when looking for templates for this specific controller)
    # The way Themer works is based on returning paths relative to this one
    def ref_path
      @ref_path ? @ref_path.dup : (raise NoTemplateRoot, "Cannot determine relative path - no controller template root given")
    end

    # The "something_path_within" are somewhat more low-level themer methods.
    # They all receive a path to your themes dir and a glob shorthand for the item to fetch, like so:
    # "/web-apps/shop/app/views-per-site/_base", "layout.*"
    # layout_path_within, action_path_within and partial_path_within all receive absolute paths,
    # and should return a string that can be used for globbing, like this one:
    #  "/stuff/more/stuff/*/*.mab"
    def layout_path_within(path, name)
      File.join(path, "layouts", name)
    end
    
    # Override in your own Themer
    # This will receive a path to your themes dir and a glob shorthand for the action, like so:
    # "/web-apps/shop/app/views-per-site/_base", "index.*"
    def action_path_within(path, name)
      File.join(path, "actions", name)
    end
    
    # Override in your own Themer
    # This will receive a path to your themes dir and a glob shorthand for the partial, like so:
    # "/web-apps/shop/app/views-per-site/_base", "_news_headline.*"
    def partial_path_within(path, name)
      File.join(path, "partials", name)
    end
        
    private
      
      # When using Capistrano there is a possibility that deployment creates the dir structure
      # that Pathname cannot resolve. We have to prevent that.
      def expand_all_paths
        @themes_dir = File.expand_path(@themes_dir)
        
      end
      
      # We cache lookups to prevent excessive overhead of globbing all the time
      def cached_result(slot, key)
        return yield unless @cache_results
        
        full_slot = [@themes_dir, @base_subdir, @special_subdir, @ref_path, slot, key]
        @@cache[full_slot] ||= (yield) # check, conditionally assign, yield AND return - how's that>?
      end
      
      # Pathname#relative_path_from(base_directory)
      def relative_to_views(path)
        abs = Pathname.new path
        views = Pathname.new File.join(ref_path)
        "/" + abs.relative_path_from(views).to_s
      end

      def make_shorthand_globbable(path)
        remove_ext(path) + '.*'
      end

      def remove_ext(str)
        str.gsub(/\.([a-z]+)$/i, '')
      end

      def grab_one(patterns)
        unless (result = patterns.map{ |pat|  Dir.glob pat }.flatten.shift)
          # The irony here is that 8 out of 10 lines concentrate on giving a meaningful error message
          first_choice = patterns[0].gsub(/\.\*$/, '')
          true_name = File.basename(first_choice)

          tpl_type = File.basename(File.dirname(File.expand_path(first_choice))).singularize
          patterns.map! do | p |
            p[0..File.expand_path(CLEAN_RAILS_ROOT).length] = '#{CLEAN_RAILS_ROOT}/'
            File.dirname(p)
          end
          raise NoSuitableTemplate,
            "Cannot find custom #{tpl_type} \"#{true_name}\" (looked under #{patterns.to_sentence })"
        else
          result
        end
      end
      
      def make_ivars_from_options(opt_hash)
        allowed = [:themes_dir, :base_subdir, :special_subdir, :cache_results]
        err = opt_hash.keys - (opt_hash.keys && allowed)
        raise ArgumentError, "Unknown options #{err.to_sentence}" if err.any?
        opt_hash.each_pair{|k,v| self.send "#{k}=", v}
      end
      
      # Should return specific paths first, base paths last
      def all_paths
        [File.join(themes_dir, special_subdir), File.join(themes_dir, base_subdir)] 
      end
  end
end
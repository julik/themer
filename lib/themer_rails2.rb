require 'themer'

# This Themer is used for Rails 2
class Themer::Base < Themer::Core
  def initialize(*args)
    # We have to explicitly tell ActionController that we have an alternate views path
    returning(super(*args)) do
      ActionView::TemplateFinder.process_view_paths(@themes_dir) if @themes_dir
    end
  end
end
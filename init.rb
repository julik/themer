if defined?(ActionView::TemplateFinder)
  require File.dirname(__FILE__) + '/lib/themer_rails2'
else
  require File.dirname(__FILE__) + '/lib/themer_rails1'
end  
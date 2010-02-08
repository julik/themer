require File.dirname(__FILE__) + '/test_full_stack'

class TestWithSymlinks < TestFullStack
  def emit_view_structure
    super
    
    abs_rails_root = File.expand_path(RAILS_ROOT)
    @saved_release_path = File.dirname(File.dirname(abs_rails_root)) + '/release'
    FileUtils.ln_s(abs_rails_root, @saved_release_path) 
    
    @saved_root = RAILS_ROOT.dup
    RAILS_ROOT.replace(@saved_release_path)
  end
  
  def destroy_view_structure
    super
    
    RAILS_ROOT.replace(@saved_root)
    FileUtils.rm(@saved_release_path)
  end
end
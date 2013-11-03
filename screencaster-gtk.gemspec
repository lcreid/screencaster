require './version'

Gem::Specification.new do |s|
  s.name        = 'screencaster-gtk'
  s.version     = ScreencasterGtk::VERSION
  s.date        = '2013-08-08'
  s.summary     = "Screencaster"
  s.description = "A gem for capturing screencasts"
  s.authors     = ["Larry Reid"]
  s.email       = 'larry.reid@jadesystems.ca'
  s.files       = ["lib/screencaster-gtk.rb", "lib/screencaster-gtk/capture.rb", "lib/screencaster-gtk/progresstracker.rb"]
  s.homepage    =
    'http://github.org/lcreid/screencaster'
  s.license     = 'GPL2'
  s.executables << "screencaster"
  s.required_ruby_version = '>= 1.9.2'
  s.add_runtime_dependency 'gdk_pixbuf2', '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'cairo', '~> 1.12', '>= 1.12.6'
  s.add_runtime_dependency 'glib2', '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'gtk2', '~> 2.0', '>= 2.0.2'
  s.requirements << "avconv"
  s.requirements << "wmctl"
  s.requirements << "libavcodec-extra-53"
  s.requirements << "mkvtoolnix"
end

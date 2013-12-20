# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

require './lib/screencaster-gtk/version' # Can't use require_relative here

Gem::Specification.new do |s|
  s.name        = 'screencaster-gtk'
  s.version     = ScreencasterGtk::VERSION
  s.date        = Time.new.strftime("%Y-%m-%d")
  s.summary     = "Screencaster"
  s.description = "A gem for capturing screencasts"
  s.authors     = ScreencasterGtk::AUTHORS
  s.email       = ScreencasterGtk::EMAIL
  s.files       = [
    "lib/screencaster-gtk.rb", 
    "lib/screencaster-gtk/savefile.rb", 
    "lib/screencaster-gtk/capture.rb", 
    "lib/screencaster-gtk/progresstracker.rb",
    "lib/screencaster-gtk/version.rb",
    "MPL2.0",
    "README.md"
    ]
  s.test_files = Dir.glob('test/*.rb')
  s.homepage    = ScreencasterGtk::HOMEPAGE
  s.license     = ScreencasterGtk::LICENSE
  s.executables << "screencaster"
  s.required_ruby_version = '>= 1.9.2'
  s.add_runtime_dependency 'gdk_pixbuf2', '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'cairo', '~> 1.12', '>= 1.12.6'
  s.add_runtime_dependency 'glib2', '~> 2.0', '>= 2.0.2'
  s.add_runtime_dependency 'gtk2', '~> 2.0', '>= 2.0.2'
  s.requirements << "libav-tools"
  s.requirements << "libavcodec-extra-53"
  s.requirements << "wmctl"
  s.requirements << "mkvtoolnix"
  s.requirements << "ruby1.9.1-dev"
  s.requirements << "libgtk2.0-dev"
end

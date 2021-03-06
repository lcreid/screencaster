# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# Copyright (c) Jade Systems Inc. 2013, 2014

require_relative "lib/screencaster-gtk/version"
require "rake/clean"

# Some of these aren't needed by this file, but they're the GNU
# standard names from makefiles, so I'll leave them here for now
# so I don't have to go looking for them
DESTDIR = ENV['DESTDIR'].nil? ? "": ENV['DESTDIR']
PREFIX = File.join DESTDIR, "usr"
BINDIR = File.join PREFIX, "bin"
DATAROOTDIR = File.join PREFIX, "share"
DOCDIR = File.join DATAROOTDIR, "doc"
MANDIR = File.join DATAROOTDIR, "man"
MAN1DIR = File.join MANDIR, "man1"
SYSCONFDIR = File.join DESTDIR, "etc"
TMPDIR = File.join DESTDIR, "tmp"

GEM = "screencaster-gtk-#{ScreencasterGtk::VERSION}.gem"

=begin
Modify and test the code
Build the gem
Test it locally
Commit everything -- not sure I want to automate this yet
Tag the gem part of the tree -- not sure I want to automate this yet
Push it to rubygems (:release)
  Rubygems lets me put things are pre-release -- I should use this somehow
Rev the gem version -- not sure I want to automate this yet
Build the .deb (:debian)
Test it locally
Commit everything -- not sure I want to automate this yet
Tag the debian part of the tree -- not sure I want to automate this yet
Push it to ???
Rev the .deb version -- not sure I want to automate this yet
=end

LINUX_FILES = FileList.new(File.join(MAN1DIR, "screencaster.1.gz"),
  File.join(DATAROOTDIR, "applications", "screencaster.desktop"),
  File.join(DATAROOTDIR, "pixmaps", "screencaster.svg"))
# These get clobbered, so they have to be only the files we move, not source files
DEBIAN_FILES = LINUX_FILES.collect do |f| File.join("debian", f) end

desc "Build the gem."
task :build => GEM

file GEM => 
  FileList.new("lib/*.rb", 
    "lib/screencaster-gtk/*.rb", 
    "bin/screencaster", 
    "screencaster-gtk.gemspec",
    "Rakefile") do
  system "gem build screencaster-gtk.gemspec"
end

desc "Push the gem to RubyGems.org"
task :release => :build do
  system "gem push #{GEM}"
end

desc "Build the .deb file"
task :debian => "screencaster.deb"

#file "screencaster.deb" => :release # This revs the gem too soon, before it's been tested.
file "screencaster.deb" => FileList.new("debian/DEBIAN/*", DEBIAN_FILES) do |t|
  rm Dir.glob("debian/DEBIAN/*~")
  system "fakeroot dpkg-deb --build debian"
  mv "debian.deb", t.name
#  puts "Built #{t.name}"
end

desc "Install the files, like a GNU makefile would install them."
task :install => LINUX_FILES do
  system "gem install screencaster-gtk --pre"
end

CLEAN.include("test/a.mkv",
  "test/b.mkv",
  "test/c.mkv",
  "test/test-final-encode.mp4",
  "test/c-from-one.mkv",
  "test/c-from-two.mkv",
  "screencaster.1.gz")
CLOBBER.include(DEBIAN_FILES, 
  "screencaster.deb", 
  GEM, 
  "bin/screencaster",
  DEBIAN_FILES)

# DEBIAN_FILES.each do |f|
  # file f => File.basename(f) do |target|
    # mkdir_p File.dirname(target.name)
    # cp target.prerequisites.first, target.name
  # end
# end

file "bin/screencaster" => FileList.new("bin/screencaster.rb") do |f|
  cp f.name + ".rb", f.name
  File.chmod 0775, f.name
end

rule '.gz' do |r|
  system "gzip --best --to-stdout #{File.basename(r.name.ext)} >#{r.name}"
end

rule "" do |r|
  file r.name => File.basename(r.name) do |f|
    mkdir_p File.dirname(f.name)
    cp File.basename(f.name), f.name
  end if r.is_a?(Rake::FileTask)
end

##################################

# Testing

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :test

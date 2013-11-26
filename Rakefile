require_relative "version"
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

# These get clobbered, so they have to be only the files we move, not source files
DEBIAN_FILES = FileList.new(File.join(TMPDIR, GEM),
  File.join(MAN1DIR, "screencaster.1.gz"),
  File.join(DATAROOTDIR, "applications", "screencaster.desktop"),
  File.join(DATAROOTDIR, "pixmaps", "screencaster.svg"))

desc "Create the gem."
task :build => GEM

file GEM => 
  FileList.new("lib/*.rb", 
    "lib/screencaster-gtk/*.rb", 
    "bin/screencaster", 
    "screencaster-gtk.gemspec") do
  system "gem build screencaster-gtk.gemspec"
end

desc "Push the gem to RubyGems.org"
task :release => :build do
  system "gem push #{GEM}"
end

desc "Build the .deb file"
task :debian => "screencaster.deb"

file "screencaster.deb" => FileList.new("debian/DEBIAN/*", GEM, DEBIAN_FILES.collect do |f| File.basename f end ) do |t|
  system "rake DESTDIR=debian install" 
  rm Dir.glob("debian/DEBIAN/*~")
  system "fakeroot dpkg-deb --build debian"
  mv "debian.deb", t.name
#  puts "Built #{t.name}"
end

desc "Install the files, like a GNU makefile would install them."
task :install => DEBIAN_FILES

CLEAN.include("screencaster.deb", 
  GEM, 
  "bin/screencaster", 
  "test/c.mkv",
  "test/test-final-encode.mp4",
  "test/c-from-one.mkv",
  "test/c-from-one.mkv")
CLOBBER.include(DEBIAN_FILES.collect { |f| File.join "debian", f })

DEBIAN_FILES.each do |f|
  file f => File.basename(f) do |target|
    cp target.prerequisites.first, target.name
  end
end

file "bin/screencaster" => FileList.new("bin/screencaster.rb") do |f|
  cp f.name + ".rb", f.name
  File.chmod 0775, f.name
end

rule '.gz' do |r|
  system "gzip --best --to-stdout #{r.name.ext} >#{r.name}"
end

rule "" do |r|
  puts r.name
end

##################################

# Testing

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

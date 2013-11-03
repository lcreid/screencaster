# See: http://www.gnu.org/software/make/manual/make.html#Makefile-Conventions
prefix = ${DESTDIR}/usr
bindir=$(prefix)/bin
datarootdir = $(prefix)/share
docdir=$(datarootdir)/doc
mandir=$(datarootdir)/man
man1dir=$(mandir)/man1
sysconfdir=${DESTDIR}/etc
tmpdir=${DESTDIR}/tmp
TARGET_OS?=$(shell "uname")

.SECONDEXPANSION:

EXECUTABLES=screencaster
MAN1FILES=${EXECUTABLES:%=%.1}

INSTALLED_EXECUTABLES=${EXECUTABLES:%=${bindir}/%}
INSTALLED_MANPAGES=${MAN1FILES:%=${man1dir}/%.gz}

GEM_SRC_DIR=lib
GEM_SRC_FILES=${GEM_SRC_DIR}/*.rb bin/screencaster.rb
SOURCES=${GEM_SRC_FILES} *.1 makefile

iconrootdir=${datarootdir}/icons/Mint-X/apps/scalable
# ICON_BITMAPS=${iconrootdir}/48/screencaster.png \
# ${iconrootdir}/32/screencaster.png \
# ${iconrootdir}/24/screencaster.png \
# ${iconrootdir}/22/screencaster.png \
# ${iconrootdir}/16/screencaster.png

INSTALLED_CONFIG_FILES+=${iconrootdir}/screencaster.svg

ifeq (Darwin, ${TARGET_OS})
#	LOGROTATE_DIR=${sysconfdir}/newsyslog.d
#	INSTALLED_CONFIG_FILES+=${LOGROTATE_DIR}/screencaster-newsyslog.conf
else ifeq (Linux, ${TARGET_OS})
#	LOGROTATE_DIR=${sysconfdir}/logrotate.d
#	INSTALLED_CONFIG_FILES+=${LOGROTATE_DIR}/screencaster-logrotate.conf
	MENU_DIR=${datarootdir}/applications
else
	$(error "Operating system " ${TARGET_OS} " not supported."
endif

INSTALLED_MENU_FILE=${MENU_DIR}/screencaster.desktop
INSTALLED_GEM_FILE=${tmpdir}/screencaster-gtk.gemspec

all: ${EXECUTABLES}

screencaster: ${GEM_SRC_FILES}
	cp bin/screencaster.rb $@
	chmod a+x $@

screencaster-gtk.gemspec: ${GEM_SRC_FILES} 
	#-rm screencaster-gtk-*.gem
	gem build screencaster-gtk.gemspec

install_gem: gem
	# gem install -l ${tmpdir}/screencaster-gtk

install: installdirs \
${INSTALLED_GEM_FILE} \
${INSTALLED_MANPAGES} \
${INSTALLED_CONFIG_FILES} \
${INSTALLED_MENU_FILE} \
${ICON_BITMAPS}

uninstall: 
	-rm ${INSTALLED_MANPAGES} \
		${INSTALLED_CONFIG_FILES} \
		${INSTALLED_MENU_FILE} \
		${ICON_BITMAPS}
	gem uninstall screencaster-gtk

${INSTALLED_EXECUTABLES} \
${INSTALLED_MANPAGES} \
${INSTALLED_CONFIG_FILES} \
${INSTALLED_GEM_FILE}: $$(@F)
	cp $? $@

${INSTALLED_MENU_FILE}: $${@F}
	cp $? $@
	chmod a+x $@

############
#
# .deb for Mint, Ubuntu, maybe Debian
#
############

debian: perms screencaster.deb

perms:
	chmod a+x debian/DEBIAN/postinst debian/DEBIAN/prerm

screencaster.deb: ${SOURCES} debian/DEBIAN/* 
	make DESTDIR=debian install
	-rm debian/DEBIAN/*~
	fakeroot dpkg-deb --build debian
	mv debian.deb $@

%.gz : %
	gzip --best --to-stdout $? >$@

############
#
# A tar file for Mac, peor es nada
#
############
LAUNCHD_DIR=${DESTDIR}/Library/LaunchDaemons

mac: screencaster.tar.gz

screencaster.tar.gz: ${SOURCES} ca.jadesystems.screencaster.plist
	make DESTDIR=osx TARGET_OS=Darwin install
	cd osx; tar -c -z --owner=root --group=root -f ../$@ ./*

%.plist : %
	cp $? $@
	chmod 600 $@

############
#
# Miscellaneous
#
############

clean:
	-rm $(EXECUTABLES) ${MAN1FILES:%=%.gz} *~

distclean: clean
	-rm ${INSTALLED_CONFIG_FILES}

installdirs: ${bindir} \
${man1dir} \
${docdir} \
${LOGROTATE_DIR} \
${MENU_DIR} \
${iconrootdir}

${bindir} ${INIT_DIR} ${man1dir} ${docdir} ${LOGROTATE_DIR} ${MENU_DIR} ${iconrootdir}:
	mkdir -p $@ 

# % : %.rb
	# cp $< $@
	# chmod a+x $@

${iconrootdir}/48/screencaster.png: screencaster.svg
	rsvg-convert -w 48 -h 48 $? -o $@

${iconrootdir}/32/screencaster.png: screencaster.svg
	rsvg-convert -w 32 -h 32 $? -o $@

${iconrootdir}/24/screencaster.png: screencaster.svg
	rsvg-convert -w 24 -h 24 $? -o $@

${iconrootdir}/22/screencaster.png: screencaster.svg
	rsvg-convert -w 22 -h 22 $? -o $@

${iconrootdir}/16/screencaster.png: screencaster.svg
	rsvg-convert -w 16 -h 16 $? -o $@



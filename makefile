# See: http://www.gnu.org/software/make/manual/make.html#Makefile-Conventions
prefix = ${DESTDIR}/usr
bindir=$(prefix)/bin
datarootdir = $(prefix)/share
docdir=$(datarootdir)/doc
mandir=$(datarootdir)/man
man1dir=$(mandir)/man1
sysconfdir=${DESTDIR}/etc
TARGET_OS?=$(shell "uname")

.SECONDEXPANSION:

EXECUTABLES=screencaster
MAN1FILES=${EXECUTABLES:%=%.1}

INSTALLED_EXECUTABLES=${EXECUTABLES:%=${bindir}/%}
INSTALLED_MANPAGES=${MAN1FILES:%=${man1dir}/%.gz}

SOURCES=*.rb *.1 makefile

ifeq (Darwin, ${TARGET_OS})
	LOGROTATE_DIR=${sysconfdir}/newsyslog.d
	INSTALLED_CONFIG_FILES+=${LOGROTATE_DIR}/screencaster-newsyslog.conf
else ifeq (Linux, ${TARGET_OS})
	LOGROTATE_DIR=${sysconfdir}/logrotate.d
	INSTALLED_CONFIG_FILES+=${LOGROTATE_DIR}/screencaster-logrotate.conf
	MENU_DIR=${datarootdir}/applications
	INSTALLED_MENU_FILES=${MENU_DIR}/screencaster.desktop
else
	$(error "Operating system " ${TARGET_OS} " not supported."
endif

all: ${EXECUTABLES}

screencaster: \
progresstracker.rb \
capture.rb \
screencaster-gtk.rb
	cat $+ >$@
	chmod a+x $@

install: installdirs \
${INSTALLED_EXECUTABLES} \
${INSTALLED_MANPAGES} \
${INSTALLED_MENU_FILES}

uninstall: 
	-rm ${INSTALLED_EXECUTABLES} ${INSTALLED_MANPAGES} ${INSTALLED_MENU_FILES}

${INSTALLED_EXECUTABLES} \
${INSTALLED_MANPAGES} \
${INSTALLED_MENU_FILES}: $$(@F)
	cp $? $@

############
#
# .deb for Mint, Ubuntu, maybe Debian
#
############

debian: screencaster.deb

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
${MENU_DIR}

${bindir} ${INIT_DIR} ${man1dir} ${docdir} ${LOGROTATE_DIR} ${MENU_DIR}:
	mkdir -p $@ 

% : %.rb
	cp $< $@
	chmod a+x $@


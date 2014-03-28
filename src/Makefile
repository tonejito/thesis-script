CP=cp
RM=rm
TAR=tar
WGET=wget --progress=bar:force
MAKE=make
SUDO=sudo
FIND=find
XARGS=xargs

#PREFIX=/usr/local
PREFIX=$(HOME)/local

CADAVER_VERSION=0.23.3
NEON_VERSION=0.29.6
PAKCHOIS_VERSION=0.4
OPENSSL_VERSION=0.9.8y
LIBXML2_VERSION=2.9.1
EXPAT_VERSION=2.1.0

#.PHONY:	all clean dist-clean cadaver neon pakchois openssl libxml2 expat

all:	cadaver

install:    $(PREFIX)/cadaver/bin/cadaver
	$(CP) -v $(PREFIX)/cadaver/bin/cadaver $(HOME)/bin/cadaver

clean:  
	for dir in `$(FIND) . -mindepth 1 -maxdepth 1 -type d -print` ; \
	do \
	  $(ECHO) $(MAKE) -C $$dir clean ; \
	done

dist-clean:  
	$(FIND) . -mindepth 1 -maxdepth 1 -type d -print0 | $(XARGS) -0 $(RM) -vrf

pkg-clean:  dist-clean
	$(FIND) . -mindepth 1 -maxdepth 1 -type f -iname '*.tar.gz' -print0 | $(XARGS) -0 $(RM) -vrf

cadaver:	neon openssl libxml2 expat
	if [ ! -e $@-$(CADAVER_VERSION) ] ; \
	then \
	  $(WGET) -c 'http://www.webdav.org/cadaver/$@-$(CADAVER_VERSION).tar.gz' ; \
	  $(TAR) -xvvzpf $@-$(CADAVER_VERSION).tar.gz ; \
	fi
	if [ ! -e $@-$(CADAVER_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(CADAVER_VERSION) ; \
	  ./configure --prefix=$(PREFIX)/$@ --with-ssl=openssl --with-neon --with-pakchois --with-libxml2 --with-expat \
	  --with-libs=$(PREFIX)/openssl:$(PREFIX)/neon:$(PREFIX)/pakchois:$(PREFIX)/libxml2:$(PREFIX)/expat ; \
	fi
	$(MAKE) -C $@-$(CADAVER_VERSION)
	$(SUDO) $(MAKE) -C $@-$(CADAVER_VERSION) install

neon:	pakchois
	if [ ! -e $@-$(NEON_VERSION) ] ; \
	then \
	  $(WGET) -c 'http://www.webdav.org/neon/$@-$(NEON_VERSION).tar.gz' ; \
	  $(TAR) -xvvzpf $@-$(NEON_VERSION).tar.gz ; \
	fi
	if [ ! -e $@-$(NEON_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(NEON_VERSION) ; \
	  ./configure --prefix=$(PREFIX)/$@ --disable-debugging --with-pakchois --with-libproxy --without-ca-bundle --without-gssapi --with-libs=$(PREFIX)/pakchois ; \
	fi
	$(MAKE) -C $@-$(NEON_VERSION)
	$(SUDO) $(MAKE) -C $@-$(NEON_VERSION) install

pakchois:
	if [ ! -e $@-$(PAKCHOIS_VERSION) ] ; \
	then \
	  $(WGET) -c 'http://www.manyfish.co.uk/pakchois/$@-$(PAKCHOIS_VERSION).tar.gz' ; \
	  $(TAR) -xvvzpf $@-$(PAKCHOIS_VERSION).tar.gz ; \
	fi
	if [ ! -e $@-$(PAKCHOIS_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(PAKCHOIS_VERSION) ; \
	  ./configure --prefix=$(PREFIX)/$@ ; \
	fi
	$(MAKE) -C $@-$(PAKCHOIS_VERSION)
	$(SUDO) $(MAKE) -C $@-$(PAKCHOIS_VERSION) install

#libproxy:
#	if [ ! -e $@-master ] ; \
#	then \
#	  $(WGET) -c 'https://github.com/gooselinux/$@/archive/master.tar.gz' -O $@-master.tar.gz ; \
#	  $(TAR) -xvvzpf $@-master.tar.gz ; \
#	fi
#	#cd $@-$(PAKCHOIS_VERSION) ; \
#	#./configure --prefix=$(PREFIX)/$@
#	$(MAKE) -C $@-master
#	#$(SUDO) $(MAKE) -C $@-$(PAKCHOIS_VERSION) install


openssl:	
	if [ ! -e $@-$(OPENSSL_VERSION) ] ; \
	then \
	  $(WGET) -c 'http://www.openssl.org/source/$@-$(OPENSSL_VERSION).tar.gz' ; \
	  $(TAR) -xvvzpf $@-$(OPENSSL_VERSION).tar.gz ; \
	fi
	if [ ! -e $@-$(OPENSSL_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(OPENSSL_VERSION) ; \
	  ./config --prefix=$(PREFIX)/$@ ; \
	fi
	$(MAKE) -C $@-$(OPENSSL_VERSION)
	$(SUDO) $(MAKE) -C $@-$(OPENSSL_VERSION) install_sw

libxml2:	
	if [ ! -e $@-$(LIBXML2_VERSION) ] ; \
	then \
	  $(WGET) -c 'ftp://xmlsoft.org/libxml2/$@-git-snapshot.tar.gz' ; \
	  $(TAR) -xvvzpf $@-git-snapshot.tar.gz ; \
	fi
	if [ ! -e $@-$(LIBXML2_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(LIBXML2_VERSION) ; \
	  ./configure --prefix=$(PREFIX)/$@ ; \
	fi
	$(MAKE) -C $@-$(LIBXML2_VERSION)
	$(SUDO) $(MAKE) -C $@-$(LIBXML2_VERSION) install

expat:	
	if [ ! -e $@-$(EXPAT_VERSION) ] ; \
	then \
	  $(WGET) -c 'http://downloads.sourceforge.net/project/expat/expat/2.1.0/expat-2.1.0.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fexpat%2Ffiles%2Fexpat%2F2.1.0%2F&ts=1379198864&use_mirror=softlayer-dal' -O $@-$(EXPAT_VERSION).tar.gz ; \
	  $(TAR) -xvvzpf $@-$(EXPAT_VERSION).tar.gz ; \
	fi
	if [ ! -e $@-$(EXPAT_VERSION)/Makefile ] ; \
	then \
	  cd $@-$(EXPAT_VERSION) ; \
	  ./configure --prefix=$(PREFIX)/$@ ; \
	fi
	$(MAKE) -C $@-$(EXPAT_VERSION)
	$(SUDO) $(MAKE) -C $@-$(EXPAT_VERSION) install

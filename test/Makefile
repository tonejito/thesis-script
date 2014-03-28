#	= ^ . ^ =

# export default shell to sub-make processes
#	http://www.gnu.org/software/make/manual/html_node/Choosing-the-Shell.html
export SHELL=/bin/bash

RM = rm
MV = mv
CAT = cat
SCP = scp
ECHO = echo
PRINTF = printf
CADAVER = ~/bin/cadaver
#CADAVER = src/cadaver-0.23.3/cadaver

NETRC = ~/.netrc
CADAVERRC = ~/.cadaverrc
LOGFILE=make.log

# Import environment variables
_LOGIN=${LOGIN}
_PW=${PW}
_REMOTE=${REMOTE}
_ENDPOINT=${ENDPOINT}
_COMMAND=${COMMAND}

__PW="escuela"

# Works with `bash` $SHELL
RW_USERS=$(shell echo profesor0{1..3})
RO_USERS=$(shell echo alumno0{1..9})

USERS=$(RW_USERS) $(RO_USERS)

HOST=https://$(_REMOTE)${_ENDPOINT}/

OBJECT=${FILE}

MAKEFILE=$(lastword $(MAKEFILE_LIST))

perms:	clean perms-in-ro perms-in-rw

clean:
	$(PRINTF) "" > $(LOGFILE)

# Read-Only  host
perms-in-ro:
	REMOTE=ro.webdav.tonejito.info ; \
	ENDPOINT="/~profesor01/grupo01" ; \
	REMOTE=$$REMOTE ENDPOINT=$$ENDPOINT \
	$(MAKE) -f $(MAKEFILE) perms-ro-user ; \
	REMOTE=$$REMOTE ENDPOINT=$$ENDPOINT \
	$(MAKE) -f $(MAKEFILE) perms-rw-user

# Read-Write host
perms-in-rw:
	REMOTE=rw.webdav.tonejito.info ; \
	ENDPOINT="/~profesor01" ; \
	REMOTE=$$REMOTE ENDPOINT=$$ENDPOINT \
	$(MAKE) -f $(MAKEFILE) perms-ro-user ; \
	REMOTE=$$REMOTE ENDPOINT=$$ENDPOINT \
	$(MAKE) -f $(MAKEFILE) perms-rw-user


## Read-Only
#HEAD
#GET OPTIONS PROPFIND

perms-ro-user:
	PW=$(__PW) ; \
	for user in $(USERS) ; \
	do \
	  LOGIN=$$user PW=$$PW REMOTE=$(_REMOTE) ENDPOINT=$(_ENDPOINT) \
	  $(MAKE) -f $(MAKEFILE) perms-ro-test ; \
	done

perms-ro-test:
	for action in propget get ; \
	do \
	  LOGIN=$(_LOGIN) PW=$(_PW) REMOTE=$(_REMOTE) ENDPOINT=$(_ENDPOINT) COMMAND="$$action $$ENDPOINT/index.html" \
	  $(MAKE) -f $(MAKEFILE) test ; \
	  if [ -e index.html ] ; \
	  then \
	    $(RM) -v index.html ; \
	  fi ; \
	done

## Read-Write
#POST
#PUT PATCH PROPPATCH COPY MOVE LOCK UNLOCK MKCOL DELETE


#
perms-rw-user:
	PW=$(__PW) ; \
	for user in $(USERS) ; \
	do \
	  LOGIN=$$user PW=$$PW REMOTE=$(_REMOTE) ENDPOINT=$(_ENDPOINT) \
	  $(MAKE) -f $(MAKEFILE) perms-rw-test ; \
	done

perms-rw-test:
	for action in \
	  "copy   $$ENDPOINT/index.html  $$ENDPOINT/index2.html" \
	  "move   $$ENDPOINT/index.html  $$ENDPOINT/index.htm"   \
	  "delete $$ENDPOINT/index2.html $$ENDPOINT/index.htm" ; \
	do \
	  LOGIN=$(_LOGIN) PW=$(_PW) REMOTE=$(_REMOTE) ENDPOINT=$(_ENDPOINT) COMMAND="$$action" \
	  $(MAKE) -f $(MAKEFILE) test ; \
	  if [ -e index.html ] ; \
	  then \
	    $(RM) -v index.html ; \
	  fi ; \
	done
	$(PRINTF) "= ^ . ^ =" > /tmp/test ; \
	LOGIN=$(_LOGIN) PW=$(_PW) REMOTE=$(_REMOTE) ENDPOINT=$(_ENDPOINT) COMMAND="put    /tmp/test $$ENDPOINT/index.html" \
	$(MAKE) -f $(MAKEFILE) test ; \
	if [ -e /tmp/test ] ; \
	then \
	  $(RM) -v /tmp/test ; \
	fi ; \

test:
	$(PRINTF) "machine %s\nlogin %s\npassword %s\n" "$(_REMOTE)" "$(_LOGIN)" "$(_PW)" > $(NETRC)
	$(PRINTF) "open %s\n%s\nexit\n" "$(HOST)" "$(_COMMAND)" > $(CADAVERRC)
	# Make report of test case success
	$(CADAVER) --rcfile $(CADAVERRC) ; \
	$(PRINTF) "$$?\t%s\t$(_LOGIN)\t$(HOST)\t$(_COMMAND)\n" $(shell date "+%Y%m%d%H%M%S") >> $(LOGFILE)
	$(RM) $(NETRC) $(CADAVERRC)

scp:
	$(SCP) $(MACHINE):/usr/local/cadaver/bin/cadaver ~/bin/


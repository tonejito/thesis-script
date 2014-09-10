#	= ^ . ^ =
# vim: filetype=Makefile

SHELL=/bin/bash

gem:	
	gem build ./xnas.gemspec && sudo gem install ./xnas-0.0.0.gem

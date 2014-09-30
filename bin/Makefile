#	= ^ . ^ =
# vim: filetype=Makefile

SHELL=/bin/bash

run:	
	reset
	time ($(MAKE) init 2>&1 | tee make.log)

load:	gem
	./clean.rb && ./test.rb && ./alumnos.rb

clean:	
	./clean.rb

check:
	grep -v '^[-+]' ./load.log

gem:	
	$(MAKE) -C ../ gem

test:	gem
	./test.rb

init:	gem clean
	./test.rb

alumnos:	gem
	./alumnos.rb


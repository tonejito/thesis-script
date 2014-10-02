#	= ^ . ^ =
# vim: filetype=Makefile

SHELL=/bin/bash

PREFIX=/opt/xNAS/files

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

json:	gem
	cd $(PREFIX) ; \
	find ./ -maxdepth 5 -type d -printf "%d\t%h\t%f\n" | sort -g | tee find.data ;
	./json.rb

pretty-json:
	mv jqxTree.json jqxTree.1.json
	python -m json.tool jqxTree.1.json > jqxTree.json
	rm jqxTree.1.json
	mv jqxListMenu.json jqxListMenu.1.json
	python -m json.tool jqxListMenu.1.json > jqxListMenu.json
	rm jqxListMenu.1.json


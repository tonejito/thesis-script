#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

payload="/opt/xNAS/files/find.data"

XNAS.json_tree(payload,"jqxTree.json")
XNAS.json_tree_label(payload,"jqxListMenu.json")

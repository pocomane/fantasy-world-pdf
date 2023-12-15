#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import weasyprint

options = {}
a = weasyprint.HTML(sys.argv[1])
b = a.render(None, None, **options)

for number, page in enumerate(b.pages):
    for _, bookmark in enumerate(page.bookmarks):
        print("bookmark", number, bookmark[1])
    for _, anchor in enumerate(page.anchors):
        print("anchor", number, anchor)

if len(sys.argv) > 2:
    a.write_pdf(sys.argv[2], **options)



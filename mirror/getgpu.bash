#!/bin/bash
# rocminfo | grep -i "gfx" | sed -n '0,/gfx90a/s/.*Name:[[:space:]]*\(gfx90a\).*/\1/p;q'
rocminfo | grep -i "gfx" | grep -m1 "gfx[0-9]" | awk '{print $2}'

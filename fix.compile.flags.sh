#!/bin/bash
file=compile_commands.json
sed -i '/-mabi=lp64/d' $file
sed -i '/-fno-allow-store-data-races/d' $file
sed -i '/-fconserve-stack/d' $file
sed -i '/-femit-struct-debug-baseonly/d' $file

#!/usr/bin/env python3
"""Fix base-files/Makefile: split multiline $(if ...) into separate conditionals."""
import sys
import os

makefile = "package/base-files/Makefile"
if not os.path.isfile(makefile):
    print(f"[PREP] WARNING: {makefile} not found, skipping")
    sys.exit(0)

with open(makefile) as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    # Match the $(if $(CONFIG_CLEAN_IPKG) block
    if "$(if $(CONFIG_CLEAN_IPKG)" in line and i + 3 < len(lines):
        # Verify this is the right block by checking next lines
        next_content = "".join(lines[i:i+4])
        if "FeedSourcesAppendOPKG" in next_content and "VERSION_SED_SCRIPT" in next_content:
            # Replace 4 lines with 3 separate $(if ...) calls
            new_lines.append("\t$(if $(CONFIG_CLEAN_IPKG),,mkdir -p $(1)/etc/opkg)\n")
            new_lines.append("\t$(if $(CONFIG_CLEAN_IPKG),,$(call FeedSourcesAppendOPKG,$(1)/etc/opkg/distfeeds.conf))\n")
            new_lines.append("\t$(if $(CONFIG_CLEAN_IPKG),,$(VERSION_SED_SCRIPT) $(1)/etc/opkg/distfeeds.conf)\n")
            i += 4  # skip original 4 lines
            print(f"[PREP] Fixed base-files/Makefile: split multiline $(if ...) into separate conditionals")
            continue
    new_lines.append(line)
    i += 1

with open(makefile, "w") as f:
    f.writelines(new_lines)

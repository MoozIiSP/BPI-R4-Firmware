#!/usr/bin/env python3
"""Fix include/feeds.mk: rewrite FeedSourcesAppendOPKG/APK macros to avoid
unbalanced $(strip $(if ...)) nesting that causes stray ')' in shell output.

The original macros use $(strip $(if ...)) with a shell subshell ( ... ) >> file.
The closing parens are ambiguous between Make function closers and shell syntax,
causing stray ')' to leak into shell commands.

New approach: each echo appends directly to $(1) (no subshell needed).
All Make $(...) constructs are properly balanced within the macro.
"""
import sys
import os

makefile = "include/feeds.mk"
if not os.path.isfile(makefile):
    print(f"[PREP] WARNING: {makefile} not found, skipping")
    sys.exit(0)

with open(makefile) as f:
    content = f.read()

lines = content.split('\n')
new_lines = []
i = 0
fixed = 0

while i < len(lines):
    # Check for FeedSourcesAppendOPKG
    if i + 1 < len(lines) and lines[i].strip() == '# 1: destination file' and \
       'define FeedSourcesAppendOPKG' in lines[i + 1]:
        i += 2  # skip comment and define
        # Skip until endef
        while i < len(lines) and lines[i].strip() != 'endef':
            i += 1
        # Write new macro — no subshell, no $(strip), balanced parens
        new_lines.append('# 1: destination file')
        new_lines.append('define FeedSourcesAppendOPKG')
        new_lines.append("\techo 'src/gz %d_core %U/targets/%S/packages' >> $(1); \\")
        new_lines.append("\t$(if $(CONFIG_PER_FEED_REPO),\\")
        new_lines.append("\t\techo 'src/gz %d_base %U/packages/%A/base' >> $(1); \\")
        new_lines.append("\t\techo 'src/gz %d_kmods %U/targets/%S/kmods/$(LINUX_VERSION)-$(LINUX_RELEASE)-$(LINUX_VERMAGIC)' >> $(1)) \\")
        new_lines.append("\t$(foreach feed,$(FEEDS_AVAILABLE),\\")
        new_lines.append("\t\t$(if $(CONFIG_FEED_$(feed)),\\")
        new_lines.append("\t\t\techo '$(if $(filter m,$(CONFIG_FEED_$(feed))),# )src/gz %d_$(feed) %U/packages/%A/$(feed)' >> $(1)))")
        if i < len(lines):
            new_lines.append(lines[i])  # endef
            i += 1
        fixed += 1
        print("[PREP] Rewrote FeedSourcesAppendOPKG macro")
        continue

    # Check for FeedSourcesAppendAPK
    if i + 1 < len(lines) and lines[i].strip() == '# 1: destination file' and \
       'define FeedSourcesAppendAPK' in lines[i + 1]:
        i += 2
        while i < len(lines) and lines[i].strip() != 'endef':
            i += 1
        new_lines.append('# 1: destination file')
        new_lines.append('define FeedSourcesAppendAPK')
        new_lines.append("\techo '%U/targets/%S/packages/packages.adb' >> $(1); \\")
        new_lines.append("\t$(if $(CONFIG_PER_FEED_REPO),\\")
        new_lines.append("\t\techo '%U/packages/%A/base/packages.adb' >> $(1); \\")
        new_lines.append("\t\techo '%U/targets/%S/kmods/$(LINUX_VERSION)-$(LINUX_RELEASE)-$(LINUX_VERMAGIC)/packages.adb' >> $(1)) \\")
        new_lines.append("\t$(foreach feed,$(FEEDS_AVAILABLE),\\")
        new_lines.append("\t\t$(if $(CONFIG_FEED_$(feed)),\\")
        new_lines.append("\t\t\techo '$(if $(filter m,$(CONFIG_FEED_$(feed))),# )%U/packages/%A/$(feed)/packages.adb' >> $(1)))")
        if i < len(lines):
            new_lines.append(lines[i])
            i += 1
        fixed += 1
        print("[PREP] Rewrote FeedSourcesAppendAPK macro")
        continue

    new_lines.append(lines[i])
    i += 1

if fixed > 0:
    with open(makefile, 'w') as f:
        f.write('\n'.join(new_lines))
    print(f"[PREP] Fixed include/feeds.mk: rewrote {fixed} macro(s)")
else:
    print(f"[PREP] include/feeds.mk: no fixes applied (structure changed)")

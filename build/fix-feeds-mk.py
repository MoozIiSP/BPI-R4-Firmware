#!/usr/bin/env python3
"""Fix include/feeds.mk: FeedSourcesAppendOPKG/APK macros have unbalanced parentheses.

The closing line `) >> $(1)` only has 1 `)` but needs 5 total:
  4 to close nested Make functions: $(strip), $(if), $(foreach), $(if)
  1 literal `)` for the shell subshell closer

Without this fix, Make leaves 3 functions unclosed, causing stray `)` to
leak into shell output and produce: `bash: syntax error near unexpected token ')'`
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
    line = lines[i]
    # Match closing lines of FeedSourcesAppendOPKG/APK macros:
    # `) >> $(1)` followed by `endef` on next line
    if line.strip() == ') >> $(1)' and i + 1 < len(lines) and lines[i + 1].strip() == 'endef':
        # Verify we're inside a FeedSourcesAppend macro by looking backwards
        in_macro = False
        for j in range(i - 1, max(i - 30, 0), -1):
            if lines[j].strip().startswith('endef'):
                break
            if 'define FeedSourcesAppend' in lines[j]:
                in_macro = True
                break
        if in_macro:
            new_lines.append('))))) >> $(1)')
            fixed += 1
            i += 1
            continue
    new_lines.append(line)
    i += 1

if fixed > 0:
    with open(makefile, 'w') as f:
        f.write('\n'.join(new_lines))
    print(f"[PREP] Fixed include/feeds.mk: added missing closing parens in {fixed} macro(s)")
else:
    print(f"[PREP] include/feeds.mk: no fixes needed (already balanced or structure changed)")

import re
import os

filepath = 'lib/features/sim_lines/presentation/widgets/sim_line_card.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Naive fix: just remove 'const ' if it's on a line that also contains 'context.'
# But actually, 'const ' might be before a widget that *contains* context.
# Let's just remove 'const ' from lines that have 'context.'
lines = content.split('\n')
for i in range(len(lines)):
    if 'context.' in lines[i]:
        lines[i] = lines[i].replace('const ', '')
        
content = '\n'.join(lines)

# Also, there are places where 'const' is multiline.
# Let's use regex to find `const ` before widgets that contain context.
# Easier: Just run a script that removes `const ` before anything with `context`.
content = re.sub(r'const\s+([A-Za-z0-9_]+\([^)]*context\.[^)]*\))', r'\1', content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

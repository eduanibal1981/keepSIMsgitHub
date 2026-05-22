import re

file_path = r'g:\KeepSIMs\keep_sims\lib\features\dashboard\presentation\ui\dashboard_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# The error lines are 1-indexed, so we map them to 0-indexed:
# 38, 61, 144, 382, 576, 582

lines_to_fix = [37, 60, 143, 381, 575, 581]

for i in lines_to_fix:
    # Replace the first occurrence of "const " on that line with ""
    lines[i] = lines[i].replace('const ', '', 1)

content = "".join(lines)

# Fix withOpacity -> withValues(alpha: 
content = re.sub(r'\.withOpacity\(', r'.withValues(alpha: ', content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed constants and warnings in dashboard_screen.dart")

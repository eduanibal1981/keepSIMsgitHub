import re

file_path = r'g:\KeepSIMs\keep_sims\lib\features\settings\presentation\screens\preferences_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace withOpacity with withValues
content = re.sub(r'\.withOpacity\(', r'.withValues(alpha: ', content)

# Replace activeColor with activeThumbColor (only inside Switch widgets)
content = re.sub(r'activeColor:', r'activeThumbColor:', content)

# Fix async gaps
content = re.sub(
    r'(await HapticHelper\.lightTick\(\);\s*)(_showLanguageSelector\(context, currentLang\);)',
    r'\1if (!context.mounted) return;\n          \2',
    content
)

content = re.sub(
    r'(await HapticHelper\.lightTick\(\);\s*)(_showPinSetupSheet\(context, hasPin\);)',
    r'\1if (!context.mounted) return;\n              \2',
    content
)

content = re.sub(
    r'(await HapticHelper\.lightTick\(\);\s*)(_selectQuietTime\()',
    r'\1if (!context.mounted) return;\n                          \2',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed warnings in preferences_screen.dart")

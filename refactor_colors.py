import os
import re

files_to_refactor = [
    'lib/features/dashboard/presentation/ui/dashboard_screen.dart',
    'lib/features/sim_lines/presentation/widgets/sim_line_card.dart',
    'lib/features/settings/presentation/screens/preferences_screen.dart',
    'lib/features/scheduled_topups/ui/widgets/scheduled_topup_sheet.dart',
]

replacements = {
    'AppColors.darkBg': 'context.scaffoldBackgroundColor',
    'AppColors.darkSurface': 'context.surfaceColor',
    'AppColors.darkCard': 'context.cardColor',
    'AppColors.darkBorder': 'context.dividerColor',
    'Colors.white.withValues': 'context.onSurfaceColor.withValues',
    'Colors.white.withOpacity': 'context.onSurfaceColor.withOpacity',
    'Colors.white24': 'context.onSurfaceColor.withOpacity(0.24)',
    'Colors.white': 'context.onSurfaceColor',
    'Colors.black.withValues': 'context.theme.shadowColor.withValues',
    'Colors.black.withOpacity': 'context.theme.shadowColor.withOpacity',
    'AppColors.textSecondaryDark': 'context.onSurfaceColor.withOpacity(0.6)',
    'AppColors.textPrimaryDark': 'context.onSurfaceColor',
    'AppColors.textTertiaryDark': 'context.onSurfaceColor.withOpacity(0.4)',
}

def process_file(filepath):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Only add import if it's not there and we actually make replacements
    original_content = content
    
    for old_str, new_str in replacements.items():
        content = content.replace(old_str, new_str)
        
    if content != original_content:
        # Add import
        import_stmt = "import 'package:keep_sims/core/utils/build_context_extension.dart';\n"
        if import_stmt not in content:
            # Add after first package import
            parts = content.split('import \'package:', 1)
            if len(parts) == 2:
                content = parts[0] + import_stmt + 'import \'package:' + parts[1]
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Refactored: {filepath}")

for file in files_to_refactor:
    process_file(file)

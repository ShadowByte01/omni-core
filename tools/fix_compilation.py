import os
import re

def fix_database():
    p = 'lib/database/database.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('class OmniDatabase extends Database', 'class OmniDatabase extends GeneratedDatabase')
    with open(p, 'w') as f:
        f.write(c)

def fix_constants():
    p = 'lib/theme/sketchy_constants.dart'
    with open(p, 'r') as f:
        c = f.read()
    if 'package:flutter/animation.dart' not in c:
        c = c.replace("import 'dart:ui';", "import 'dart:ui';\nimport 'package:flutter/animation.dart';")
    with open(p, 'w') as f:
        f.write(c)

def fix_file_manager():
    p = 'lib/screens/file_manager_screen.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('begin: 1.0,', 'begin: const Offset(1.0, 1.0),')
    c = c.replace('end: 1.03,', 'end: const Offset(1.03, 1.03),')
    with open(p, 'w') as f:
        f.write(c)

def fix_optimizer():
    p = 'lib/screens/optimizer_screen.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('Widget _infoRow(String label, String value) {', 'Widget _infoRow(BuildContext context, String label, String value) {')
    c = re.sub(r"_infoRow\(\s*'([^']*)',", r"_infoRow(context, '\1',", c)
    with open(p, 'w') as f:
        f.write(c)

def fix_status_bar():
    p = 'lib/widgets/sketchy_status_bar.dart'
    with open(p, 'r') as f:
        lines = f.readlines()
    if '),' in lines[248]:
        del lines[248]
    with open(p, 'w') as f:
        f.writelines(lines)

def fix_file_node():
    p = 'lib/models/file_node.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('bytes.toDouble().bitLength', 'bytes.bitLength')
    with open(p, 'w') as f:
        f.write(c)

def fix_file_indexer():
    p = 'lib/services/file_indexer.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('perms.isGranted(Permission.storage)', '(perms[Permission.storage]?.isGranted ?? false)')
    with open(p, 'w') as f:
        f.write(c)

def fix_mail_service():
    p = 'lib/services/mail_service.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('if (!ref.mounted) return;', '')
    with open(p, 'w') as f:
        f.write(c)

def fix_gallery_service():
    p = 'lib/services/gallery_service.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('PhotoManager.permissionStatus()', 'PhotoManager.requestPermissionExtend()')
    with open(p, 'w') as f:
        f.write(c)

def fix_auth_controller():
    p = 'lib/controllers/auth_controller.dart'
    with open(p, 'r') as f:
        c = f.read()
    c = c.replace('StreamSubscription<AuthState>? _sub;', 'StreamSubscription? _sub;')
    c = c.replace("meta['full_name']", "meta?['full_name']")
    c = c.replace("meta['avatar_url']", "meta?['avatar_url']")
    with open(p, 'w') as f:
        f.write(c)

def main():
    fix_database()
    fix_constants()
    fix_file_manager()
    fix_optimizer()
    fix_status_bar()
    fix_file_node()
    fix_file_indexer()
    fix_mail_service()
    fix_gallery_service()
    fix_auth_controller()
    print("Fixes applied.")

if __name__ == '__main__':
    main()

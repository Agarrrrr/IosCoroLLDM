import sys

files = [
    'lib/core/audio/vocal_audio_service.dart',
    'lib/core/providers/vocal_audio_provider.dart',
    'lib/features/visor/widgets/singing_icon.dart',
    'lib/features/visor/widgets/vocal_panel.dart',
    'lib/features/settings/settings_screen.dart',
    'lib/features/visor/visor_screen.dart'
]

for p in files:
    with open(p, 'r', encoding='utf-8') as f:
        code = f.read()
    stack = []
    pairs = {'(': ')', '{': '}', '[': ']'}
    inv = {')': '(', '}': '{', ']': '['}
    i = 0
    in_str = None
    in_line_comment = False
    in_block_comment = False
    err = []
    while i < len(code):
        c = code[i]
        if in_line_comment:
            if c == '\n': in_line_comment = False
        elif in_block_comment:
            if c == '*' and i + 1 < len(code) and code[i+1] == '/':
                in_block_comment = False
                i += 1
        elif in_str:
            if c == '\\':
                i += 1
            elif c == in_str:
                in_str = None
        else:
            if c == '/' and i + 1 < len(code) and code[i+1] == '/':
                in_line_comment = True
                i += 1
            elif c == '/' and i + 1 < len(code) and code[i+1] == '*':
                in_block_comment = True
                i += 1
            elif c in ('"', "'"):
                in_str = c
            elif c in pairs:
                stack.append(c)
            elif c in inv:
                if not stack or stack[-1] != inv[c]:
                    err.append(f'Mismatched {c} at {i}')
                    break
                stack.pop()
        i += 1
    if stack:
        err.append(f'{len(stack)} unclosed: {stack[-3:]}')
    print(p, '->', 'OK' if not err else err)

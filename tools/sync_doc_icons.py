"""Export user-guide icons from the exact fonts and mappings used by Flutter.

Run flutter pub get first. Requires fonttools (build tooling only).
Committed SVGs let MkDocs build without Flutter or fonttools installed.
"""

import argparse
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlparse

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/overrides/.icons/app'


def package_roots():
    config_path = ROOT / '.dart_tool/package_config.json'
    config = json.loads(config_path.read_text(encoding='utf-8'))
    roots = {}
    for package in config['packages']:
        uri = package['rootUri']
        parsed = urlparse(uri)
        if parsed.scheme == 'file':
            path = unquote(parsed.path)
            if re.match(r'^/[A-Za-z]:/', path):
                path = path[1:]
            roots[package['name']] = Path(path)
        else:
            roots[package['name']] = (config_path.parent / unquote(uri)).resolve()
    return roots


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify committed SVGs without writing')
    args = parser.parse_args()
    app_source = (ROOT / 'lib/shared/utils/app_icons.dart').read_text(encoding='utf-8')
    mappings = dict(re.findall(r'static const IconData (\w+)\s*=\s*(\w+(?:\.\w+)?);', app_source))
    used = set()
    for page in (ROOT / 'docs/user').glob('*.md'):
        text = page.read_text(encoding='utf-8')
        if ':material-' in text:
            raise ValueError(f'{page}: replace approximate icons with :app-AppIconsMember:')
        used.update(re.findall(r':app-(\w+):', text))
    roots = package_roots()
    symbols_root = roots['material_symbols_icons']
    flutter_root = roots['flutter']
    sources = {
        'Symbols': (symbols_root / 'lib/symbols.dart').read_text(encoding='utf-8'),
        'Icons': (flutter_root / 'lib/src/material/icons.dart').read_text(encoding='utf-8'),
    }
    fonts = {}
    errors = []
    if not args.check:
        OUTPUT.mkdir(parents=True, exist_ok=True)
    for member in sorted(used):
        source = mappings[member]
        while '.' not in source:
            source = mappings[source]
        owner, glyph = source.split('.')
        pattern = rf'static const IconData {glyph}\s*=\s*IconData\(0x([0-9a-f]+),\s*fontFamily: \'([^\']+)\''
        match = re.search(pattern, sources[owner])
        if not match:
            raise ValueError(f'Cannot resolve AppIcons.{member}: {source}')
        codepoint, family = match.groups()
        if family not in fonts:
            font_path = (symbols_root / f'lib/fonts/{family}.ttf' if owner == 'Symbols' else
                         flutter_root.parents[1] / 'bin/cache/artifacts/material_fonts/materialicons-regular.otf')
            fonts[family] = TTFont(font_path)
        font = fonts[family]
        glyphs = font.getGlyphSet()
        pen = SVGPathPen(glyphs)
        glyphs[font.getBestCmap()[int(codepoint, 16)]].draw(
            TransformPen(pen, (1, 0, 0, -1, 0, font['hhea'].ascent)))
        size = font['head'].unitsPerEm
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">'
               f'<!-- AppIcons.{member} = {source}; font default axes. -->'
               f'<path fill="currentColor" d="{pen.getCommands()}"/></svg>\n')
        target = OUTPUT / f'{member}.svg'
        if args.check:
            if not target.exists() or target.read_text(encoding='utf-8') != svg:
                errors.append(member)
        else:
            target.write_text(svg, encoding='utf-8', newline='\n')
    extra = {p.stem for p in OUTPUT.glob('*.svg')} - used
    if extra:
        errors.extend(f'unused: {member}' for member in sorted(extra))
    if errors:
        raise SystemExit('Guide icons need syncing: ' + ', '.join(errors))
    print(f'{"Checked" if args.check else "Exported"} {len(used)} app icons for the user guide')


if __name__ == '__main__':
    main()

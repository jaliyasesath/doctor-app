"""Run only in the PP Client Codemagic pre-build step, before flutter build."""
from pathlib import Path
import plistlib
import re
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.applix.privatepractice.client'
IOS_ID = '1045461226834-h4elr7si23rbnp1b31uf6hduc5knmobc.apps.googleusercontent.com'
WEB_ID = '1045461226834-1gn3un22402smuj82b8mprk44fmh5709.apps.googleusercontent.com'
SCHEME = 'com.googleusercontent.apps.1045461226834-h4elr7si23rbnp1b31uf6hduc5knmobc'


def prepare(root):
    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    info = root / 'ios/Runner/Info.plist'
    original = project.read_text(encoding='utf-8')
    pattern = r'(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)(com\.example\.doctorApp|com\.applix\.privatepractice\.client)(\.RunnerTests)?(\s*;)'
    updated, count = re.subn(pattern, lambda m: m[1] + BUNDLE + (m[3] or '') + m[4], original)
    if count != 6:
        raise SystemExit('Unexpected iOS bundle settings. No files changed; review project.pbxproj first.')
    data = plistlib.loads(info.read_bytes())
    data['CFBundleDisplayName'] = 'PP Care'
    data['CFBundleName'] = 'PP Care'
    data['GIDClientID'] = IOS_ID
    data['GIDServerClientID'] = WEB_ID
    url_types = data.setdefault('CFBundleURLTypes', [])
    if not any(SCHEME in entry.get('CFBundleURLSchemes', []) for entry in url_types):
        url_types.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLSchemes': [SCHEME]})
    data['NSLocationWhenInUseUsageDescription'] = 'Your location is used to find nearby doctors and show their distance.'
    encoded = plistlib.dumps(data, sort_keys=False)
    project.write_text(updated, encoding='utf-8')
    info.write_bytes(encoded)
    # Runs only for PP Care; PP App's checked-in iOS icon is not changed.
    iconset = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    source = root / 'assets/images/pp_care_icon.png'
    entries = json.loads((iconset / 'Contents.json').read_text())['images']
    for entry in entries:
        filename = entry.get('filename')
        if not filename:
            continue
        points = float(entry['size'].split('x')[0])
        pixels = round(points * float(entry.get('scale', '1x')[:-1]))
        subprocess.run(['sips', '-z', str(pixels), str(pixels), str(source), '--out', str(iconset / filename)], check=True, capture_output=True)
    print('PP Care iOS configured: ' + BUNDLE)


if __name__ == '__main__':
    prepare(ROOT)

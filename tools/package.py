"""Build an installable ZIP from the explicit manifest and verify every byte."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def package_configuration(root=ROOT):
    manifest = json.loads((root / 'release-manifest.json').read_text(encoding='utf-8'))
    addon = manifest['addon']
    files = manifest['files']
    if not isinstance(addon, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', addon):
        raise ValueError('Invalid add-on folder')
    addon_root = root / addon
    if addon_root.is_symlink() or addon_root.resolve().parent != root.resolve():
        raise ValueError('Invalid add-on folder')
    if not isinstance(files, list) or not all(isinstance(name, str) for name in files):
        raise ValueError('Manifest files must be a list of paths')
    if len(files) != len(set(files)):
        raise ValueError('Duplicate manifest entry')
    for relative in files:
        member = PurePosixPath(relative)
        if (member.is_absolute() or member.as_posix() != relative or
                '..' in member.parts or '\\' in relative or ':' in relative or
                len(member.parts) < 2 or member.parts[0] != addon):
            raise ValueError('Invalid package path: ' + relative)
        path = root / relative
        if (path.is_symlink() or not path.is_file() or
                not path.resolve().is_relative_to(addon_root.resolve())):
            raise ValueError('Invalid package path: ' + relative)
    actual = {p.relative_to(root).as_posix() for p in addon_root.rglob('*') if p.is_file()}
    if actual != set(files):
        raise ValueError('Manifest does not match runtime files')
    if addon + '/' + addon + '.toc' not in files:
        raise ValueError('Missing add-on TOC')
    versions = set()
    for toc in addon_root.glob('*.toc'):
        text = toc.read_text(encoding='utf-8-sig')
        toc_versions = re.findall(r'^## Version: (.+)$', text, re.M)
        if len(toc_versions) != 1:
            raise ValueError('TOC must declare exactly one version: ' + toc.name)
        versions.add(toc_versions[0].strip())
        for line in text.splitlines():
            line = line.strip()
            if line and not line.startswith('#') and addon + '/' + line.replace('\\', '/') not in files:
                raise ValueError('Missing TOC file: ' + line)
    if len(versions) != 1:
        raise ValueError('TOC versions disagree')
    version = versions.pop()
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9.-]+)?', version):
        raise ValueError('Unexpected version')
    package = json.loads((root / 'package.json').read_text(encoding='utf-8'))
    lock = json.loads((root / 'package-lock.json').read_text(encoding='utf-8'))
    if any(value != version for value in (
            package.get('version'), lock.get('version'),
            lock.get('packages', {}).get('', {}).get('version'))):
        raise ValueError('Package and lockfile versions must match the TOC version')
    return addon, files, version


def build_package(root=ROOT):
    addon, files, version = package_configuration(root)
    dist = root / 'dist'
    dist.mkdir(exist_ok=True)
    archive = dist / (addon + '-' + version + '.zip')
    with zipfile.ZipFile(archive, 'w') as output:
        for relative in sorted(files):
            info = zipfile.ZipInfo(relative, (2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(info, (root / relative).read_bytes())
    with zipfile.ZipFile(archive) as output:
        if set(output.namelist()) != set(files):
            raise ValueError('ZIP members do not match the manifest')
        for relative in files:
            if output.read(relative) != (root / relative).read_bytes():
                raise ValueError('ZIP member differs from its source: ' + relative)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (dist / 'SHA256SUMS.txt').write_text(digest + '  ' + archive.name + '\n', encoding='utf-8', newline='\n')
    print('Verified ' + archive.name + ', ' + str(len(files)) + ' files, SHA256 ' + digest)
    return archive


if __name__ == '__main__':
    try:
        build_package()
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(str(error)) from error

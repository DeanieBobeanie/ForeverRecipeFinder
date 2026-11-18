"""Check release metadata relative to the repository, regardless of the working directory."""
import os
from package import package_configuration


if __name__ == '__main__':
    try:
        _, _, version = package_configuration()
        if os.environ.get('RELEASE_TAG') != 'v' + version:
            raise ValueError('Release tag does not match TOC version')
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(str(error)) from error

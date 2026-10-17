"""Small App Store Connect API client. Credentials stay outside the repository; JWTs are never logged."""
import argparse
import json
from pathlib import Path
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import jwt


class AppStoreConnect:
    def __init__(self, config_path):
        self.config = json.loads(Path(config_path).expanduser().read_text())

    def request(self, method, path, body=None):
        now = int(time.time())
        token = jwt.encode({'iss': self.config['issuer_id'], 'iat': now-10, 'exp': now+900,
                            'aud': 'appstoreconnect-v1'},
                           Path(self.config['key_path']).expanduser().read_bytes(), algorithm='ES256',
                           headers={'kid': self.config['key_id'], 'typ': 'JWT'})
        url = path if path.startswith('https://api.appstoreconnect.apple.com/') else 'https://api.appstoreconnect.apple.com' + path
        request = Request(url, data=json.dumps(body).encode() if body is not None else None,
                          headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}, method=method)
        try:
            with urlopen(request, timeout=60) as response:
                data = response.read()
                return json.loads(data) if data else {}
        except HTTPError as error:
            # The API's error response does not include the authorization header.
            raise RuntimeError(f'Apple API HTTP {error.code}: {error.read().decode()}') from None


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--credentials', required=True, help='Path to external release JSON (issuer_id, key_id, key_path)')
    parser.add_argument('method', choices=['GET', 'POST', 'PATCH', 'DELETE'])
    parser.add_argument('path')
    parser.add_argument('--body', help='JSON request body file')
    parser.add_argument('--out', help='Save response locally rather than printing it')
    args = parser.parse_args()
    result = AppStoreConnect(args.credentials).request(args.method, args.path,
                    json.loads(Path(args.body).read_text()) if args.body else None)
    text = json.dumps(result, indent=2)
    if args.out:
        Path(args.out).write_text(text)
        print(f'Response saved to {args.out}')
    else:
        print(text)

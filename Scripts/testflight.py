"""Upload a prepared IPA and distribute only to the explicitly configured internal tester.

Usage: python Scripts/testflight.py --credentials /external/release.json --upload
The initial App Store Connect app record must already exist (Apple does not offer public API creation).
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
from urllib.parse import urlencode
from asc import AppStoreConnect

BUNDLE = 'fr.yannick.mangaflow'
EMAIL = 'yannick.herrero@proton.me'
GROUP = 'Yannick — Personnel'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--credentials', required=True)
    parser.add_argument('--ipa', default='Artifacts/TestFlight/MangaFlow.ipa')
    parser.add_argument('--upload', action='store_true', help='Upload the signed IPA (omit to resume after an existing upload)')
    parser.add_argument('--configure-only', action='store_true', help='Prepare and verify the private internal group without uploading')
    parser.add_argument('--invite', action='store_true', help='Ask Apple to send the TestFlight invitation to the sole configured tester')
    parser.add_argument('--build', default='1')
    parser.add_argument('--notes-file', help='UTF-8 French TestFlight release notes')
    args = parser.parse_args()
    notes = Path(args.notes_file).read_text().strip() if args.notes_file else 'Importer un CBZ et lire en défilement vertical. Toucher une case pour voir la page originale.'
    api = AppStoreConnect(args.credentials)
    artifacts = Path('Artifacts'); artifacts.mkdir(exist_ok=True)

    def get(path, params=None):
        return api.request('GET', path + ('?' + urlencode(params) if params else ''))['data']

    apps = get('/v1/apps', {'filter[bundleId]': BUNDLE})
    if len(apps) != 1:
        raise RuntimeError('Create the MangaFlow Reader app record in App Store Connect first: bundle fr.yannick.mangaflow, SKU MangaFlow, locale fr-FR.')
    app = apps[0]; app_id = app['id']
    print('App:', app['attributes']['name'], app_id, flush=True)
    groups = get(f'/v1/apps/{app_id}/betaGroups')
    matches = [g for g in groups if g['attributes']['name'] == GROUP]
    if matches:
        group = matches[0]
        if not group['attributes']['isInternalGroup'] or group['attributes'].get('publicLinkEnabled'):
            raise RuntimeError('Existing group is not private/internal; refusing to distribute.')
    else:
        group = api.request('POST', '/v1/betaGroups', {'data': {'type': 'betaGroups',
            'attributes': {'name': GROUP, 'isInternalGroup': True, 'publicLinkEnabled': False, 'hasAccessToAllBuilds': False},
            'relationships': {'app': {'data': {'type': 'apps', 'id': app_id}}}}})['data']
    group_id = group['id']
    members = get(f'/v1/betaGroups/{group_id}/betaTesters')
    if any(t['attributes']['email'].lower() != EMAIL for t in members):
        raise RuntimeError('Group contains a different tester. No build was assigned.')
    if not members:
        testers = get('/v1/betaTesters', {'filter[email]': EMAIL, 'filter[apps]': app_id})
        if testers:
            tester = testers[0]
            api.request('POST', f'/v1/betaGroups/{group_id}/relationships/betaTesters',
                        {'data': [{'type': 'betaTesters', 'id': tester['id']}]})
        else:
            tester = api.request('POST', '/v1/betaTesters', {'data': {'type': 'betaTesters',
                'attributes': {'email': EMAIL, 'firstName': 'Yannick', 'lastName': 'Herrero'},
                'relationships': {'betaGroups': {'data': [{'type': 'betaGroups', 'id': group_id}]}}}})['data']
    else:
        tester = members[0]
    print('Internal group configured for', EMAIL, flush=True)
    if args.configure_only:
        members = get(f'/v1/betaGroups/{group_id}/betaTesters')
        assert len(members) == 1 and members[0]['attributes']['email'].lower() == EMAIL
        configuration = {'app_id': app_id, 'group_id': group_id, 'tester': EMAIL, 'internal_only': True, 'public_link': False}
        (artifacts / 'testflight-configuration.json').write_text(json.dumps(configuration, indent=2))
        print(json.dumps(configuration, indent=2), flush=True)
        return

    if args.upload:
        config = api.config
        env = os.environ.copy(); env['API_PRIVATE_KEYS_DIR'] = str(Path(config['key_path']).parent)
        command = ['xcrun', 'altool', '--upload-app', '-f', args.ipa,
                   '--api-key', config['key_id'], '--api-issuer', config['issuer_id']]
        with (artifacts / 'testflight-upload.log').open('w') as log:
            subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        print('Upload accepted; waiting for Apple processing.', flush=True)

    last_state = None
    for _ in range(45):
        builds = get('/v1/builds', {'filter[app]': app_id, 'filter[version]': args.build, 'sort': '-uploadedDate'})
        build = builds[0] if builds else None
        state = build['attributes']['processingState'] if build else 'NOT_VISIBLE_YET'
        if state != last_state:
            print('Build state:', state, flush=True); last_state = state
        if state == 'VALID':
            break
        if state in ['FAILED', 'INVALID']:
            raise RuntimeError('Apple rejected build processing: ' + state)
        time.sleep(20)
    else:
        raise RuntimeError('Processing still pending. Rerun without --upload to resume.')
    build_id = build['id']
    if build['attributes'].get('buildAudienceType') != 'INTERNAL_ONLY':
        raise RuntimeError('Build is not marked INTERNAL_ONLY. Export again with testFlightInternalTestingOnly=true.')
    locales = get(f'/v1/builds/{build_id}/betaBuildLocalizations')
    if not any(x['attributes']['locale'] == 'fr-FR' for x in locales):
        api.request('POST', '/v1/betaBuildLocalizations', {'data': {'type': 'betaBuildLocalizations',
            'attributes': {'locale': 'fr-FR', 'whatsNew': notes},
            'relationships': {'build': {'data': {'type': 'builds', 'id': build_id}}}}})
    current_builds = get(f'/v1/betaGroups/{group_id}/builds')
    if not any(b['id'] == build_id for b in current_builds):
        api.request('POST', f'/v1/betaGroups/{group_id}/relationships/builds',
                    {'data': [{'type': 'builds', 'id': build_id}]})
    # Verify the actual server-side configuration before reporting completion.
    group = api.request('GET', f'/v1/betaGroups/{group_id}')['data']
    members = get(f'/v1/betaGroups/{group_id}/betaTesters')
    assigned = get(f'/v1/betaGroups/{group_id}/builds')
    assert group['attributes']['isInternalGroup'] and not group['attributes'].get('publicLinkEnabled')
    assert len(members) == 1 and members[0]['attributes']['email'].lower() == EMAIL
    assert any(x['id'] == build_id for x in assigned)
    detail = api.request('GET', f'/v1/builds/{build_id}/buildBetaDetail')['data']
    if detail['attributes'].get('internalBuildState') != 'IN_BETA_TESTING':
        raise RuntimeError('Build is assigned but not yet in beta testing: ' + str(detail['attributes'].get('internalBuildState')))
    if args.invite:
        api.request('POST', '/v1/betaTesterInvitations', {'data': {'type': 'betaTesterInvitations',
            'relationships': {'app': {'data': {'type': 'apps', 'id': app_id}},
                              'betaTester': {'data': {'type': 'betaTesters', 'id': members[0]['id']}}}}})
        print('Apple accepted the TestFlight invitation request for', EMAIL, flush=True)
    status = {'app_id': app_id, 'bundle_id': BUNDLE, 'build_id': build_id, 'build_number': args.build,
              'group_id': group_id, 'group_name': GROUP, 'tester': EMAIL, 'public_link': False,
              'internal_build_state': detail['attributes'].get('internalBuildState'),
              'build_audience': build['attributes'].get('buildAudienceType'),
              'url': f'https://appstoreconnect.apple.com/apps/{app_id}/testflight/ios'}
    (artifacts / 'testflight-status.json').write_text(json.dumps(status, indent=2))
    print(json.dumps(status, indent=2), flush=True)


if __name__ == '__main__':
    main()

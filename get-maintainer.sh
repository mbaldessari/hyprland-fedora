#!/usr/bin/python3

import sys

import requests

def get_fedora_maintainer(package_name):
    url = f"https://src.fedoraproject.org/api/0/rpms/{package_name}"
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        # The 'user' field is the primary owner (Main Admin)
        owner = data.get('user', {}).get('fullname')
        # 'access_users' contains all people with commit access (co-maintainers)
        maintainers = data.get('access_users', {}).get('admin', [])
        
        return {
            "owner": owner,
            "maintainers": maintainers
        }
    return None

if len(sys.argv) <= 1:
    print("Pass a parameter")
    sys.exit(1)

info = get_fedora_maintainer(sys.argv[1])
if info is not None and "owner" in info:
    print(f"  Owner: {info['owner']}")
if info is not None and "maintainers" in info:
    print(f"  Admins: {', '.join(info['maintainers'])}")

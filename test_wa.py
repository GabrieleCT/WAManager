import requests

try:
    print('1. Login...')
    r = requests.post('http://127.0.0.1:8082/api/auth/login/', json={'username': 'admin', 'password': 'admin'})
    print(r.status_code, r.text)
    token = r.json().get('token')
    
    print('2. Fetch WA Status...')
    headers = {'Authorization': f'Token {token}'}
    r = requests.get('http://127.0.0.1:8082/api/wa-status/', headers=headers)
    print(r.status_code, r.text)
except Exception as e:
    print('Error:', e)

with open('WAManager/settings.py', 'rb') as f: data = f.read()
data = data.replace(b'\x00', b'')
with open('WAManager/settings.py', 'wb') as f: f.write(data)

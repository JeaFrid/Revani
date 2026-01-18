# 
# Copyright (C) 2026 JeaFriday (https://github.com/JeaFrid/Revani)
# 
# Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).
# Project: Revani
#
import asyncio
import json
import struct
import base64
import time
import hashlib
import os
import ssl
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

class RevaniClient:
    def __init__(self, host, port=16897, secure=True):
        self.host = host
        self.port = port
        self.secure = secure
        self._reader = None
        self._writer = None
        self._session_key = None
        self._account_id = None
        self._project_name = None
        self._project_id = None
        self.account = RevaniAccount(self)
        self.project = RevaniProject(self)
        self.data = RevaniData(self)
        self.storage = RevaniStorage(self)
        self.livekit = RevaniLivekit(self)
        self.pubsub = RevaniPubSub(self)

    async def connect(self):
        if self.secure:
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            self._reader, self._writer = await asyncio.open_connection(
                self.host, self.port, ssl=context
            )
        else:
            self._reader, self._writer = await asyncio.open_connection(
                self.host, self.port
            )

    async def execute(self, command, use_encryption=True):
        if use_encryption and self._session_key:
            payload = {'encrypted': self._encrypt(json.dumps(command))}
        else:
            payload = command

        bytes_data = json.dumps(payload).encode('utf-8')
        header = struct.pack('>I', len(bytes_data))
        
        self._writer.write(header)
        self._writer.write(bytes_data)
        await self._writer.drain()

        header_resp = await self._reader.readexactly(4)
        length = struct.unpack('>I', header_resp)[0]
        payload_resp = await self._reader.readexactly(length)
        
        response_json = json.loads(payload_resp.decode('utf-8'))

        if isinstance(response_json, dict) and 'encrypted' in response_json and self._session_key:
            decrypted = self._decrypt(response_json['encrypted'])
            return json.loads(decrypted)
        
        return response_json

    def _encrypt(self, text):
        wrapper = json.dumps({
            "payload": text,
            "ts": int(time.time() * 1000)
        })
        
        salt_bytes = os.urandom(16)
        salt_b64 = base64.b64encode(salt_bytes).decode('utf-8')
        
        key_material = (self._session_key + salt_b64).encode('utf-8')
        key_hash = hashlib.sha256(key_material).digest()
        
        iv = os.urandom(16)
        aesgcm = AESGCM(key_hash)
        ciphertext = aesgcm.encrypt(iv, wrapper.encode('utf-8'), None)
        
        iv_b64 = base64.b64encode(iv).decode('utf-8')
        cipher_b64 = base64.b64encode(ciphertext).decode('utf-8')
        
        return f"{salt_b64}:{iv_b64}:{cipher_b64}"

    def _decrypt(self, encrypted_data):
        parts = encrypted_data.split(':')
        salt_b64 = parts[0]
        iv = base64.b64decode(parts[1])
        ciphertext = base64.b64decode(parts[2])
        
        key_material = (self._session_key + salt_b64).encode('utf-8')
        key_hash = hashlib.sha256(key_material).digest()
        
        aesgcm = AESGCM(key_hash)
        decrypted_bytes = aesgcm.decrypt(iv, ciphertext, None)
        
        wrapper = json.loads(decrypted_bytes.decode('utf-8'))
        return wrapper['payload']

    def set_session(self, key):
        self._session_key = key

    def set_account(self, account_id):
        self._account_id = account_id

    def set_project(self, name, project_id):
        self._project_name = name
        self._project_id = project_id

    @property
    def account_id(self):
        return self._account_id or ""

    @property
    def project_name(self):
        return self._project_name or ""

    @property
    def project_id(self):
        return self._project_id or ""

    async def disconnect(self):
        if self._writer:
            self._writer.close()
            await self._writer.wait_closed()
        self._reader = None
        self._writer = None
        self._session_key = None
        self._account_id = None
        self._project_name = None
        self._project_id = None

class RevaniAccount:
    def __init__(self, client):
        self._client = client

    async def create(self, email, password, extra_data=None):
        return await self._client.execute({
            'cmd': 'account/create',
            'email': email,
            'password': password,
            'data': extra_data or {},
        }, use_encryption=False)

    async def login(self, email, password):
        res = await self._client.execute({
            'cmd': 'auth/login',
            'email': email,
            'password': password,
        }, use_encryption=False)

        if res.get('status') == 200:
            self._client.set_session(res['session_key'])
            id_res = await self._client.execute({
                'cmd': 'account/get-id',
                'email': email,
                'password': password,
            }, use_encryption=False)

            if id_res.get('status') == 200:
                self._client.set_account(id_res['data']['id'])
            return True
        return False

    async def get_data(self):
        return await self._client.execute({
            'cmd': 'account/get-data',
            'id': self._client.account_id,
        })

class RevaniProject:
    def __init__(self, client):
        self._client = client

    async def use(self, project_name):
        res = await self._client.execute({
            'cmd': 'project/exist',
            'accountID': self._client.account_id,
            'projectName': project_name,
        })

        if res.get('status') == 200:
            self._client.set_project(project_name, res.get('id'))
        return res

    async def create(self, project_name):
        res = await self._client.execute({
            'cmd': 'project/create',
            'accountID': self._client.account_id,
            'projectName': project_name,
        })
        if res.get('status') == 200:
            self._client.set_project(project_name, res['data']['id'])
        return res

class RevaniData:
    def __init__(self, client):
        self._client = client

    async def add(self, bucket, tag, value):
        return await self._client.execute({
            'cmd': 'data/add',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'bucket': bucket,
            'tag': tag,
            'value': value,
        })

    async def get(self, bucket, tag):
        return await self._client.execute({
            'cmd': 'data/get',
            'projectID': self._client.project_id,
            'bucket': bucket,
            'tag': tag,
        })

    async def query(self, bucket, query_map):
        return await self._client.execute({
            'cmd': 'data/query',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'bucket': bucket,
            'query': query_map,
        })

    async def update(self, bucket, tag, new_value):
        return await self._client.execute({
            'cmd': 'data/update',
            'projectID': self._client.project_id,
            'bucket': bucket,
            'tag': tag,
            'newValue': new_value,
        })

    async def delete(self, bucket, tag):
        return await self._client.execute({
            'cmd': 'data/delete',
            'projectID': self._client.project_id,
            'bucket': bucket,
            'tag': tag,
        })

class RevaniStorage:
    def __init__(self, client):
        self._client = client

    async def upload(self, file_name, byte_list, compress=False):
        return await self._client.execute({
            'cmd': 'storage/upload',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'fileName': file_name,
            'bytes': byte_list,
            'compress': compress,
        })

    async def download(self, file_id):
        return await self._client.execute({
            'cmd': 'storage/download',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'fileId': file_id,
        })

    async def delete(self, file_id):
        return await self._client.execute({
            'cmd': 'storage/delete',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'fileId': file_id,
        })

class RevaniLivekit:
    def __init__(self, client):
        self._client = client

    async def init(self, host, api_key, api_secret):
        return await self._client.execute({
            'cmd': 'livekit/init',
            'host': host,
            'apiKey': api_key,
            'apiSecret': api_secret,
        })

    async def auto_connect(self):
        return await self._client.execute({
            'cmd': 'livekit/connect',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
        })

    async def create_token(self, room_name, user_id, user_name, is_admin=False):
        return await self._client.execute({
            'cmd': 'livekit/create-token',
            'roomName': room_name,
            'userID': user_id,
            'userName': user_name,
            'isAdmin': is_admin,
        })

    async def create_room(self, room_name, timeout=10, max_users=50):
        return await self._client.execute({
            'cmd': 'livekit/create-room',
            'roomName': room_name,
            'emptyTimeoutMinute': timeout,
            'maxUsers': max_users,
        })

class RevaniPubSub:
    def __init__(self, client):
        self._client = client

    async def subscribe(self, topic, client_id):
        return await self._client.execute({
            'cmd': 'pubsub/subscribe',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'clientId': client_id,
            'topic': topic,
        })

    async def publish(self, topic, data, client_id=None):
        return await self._client.execute({
            'cmd': 'pubsub/publish',
            'accountID': self._client.account_id,
            'projectName': self._client.project_name,
            'topic': topic,
            'data': data,
            'clientId': client_id,
        })

    async def unsubscribe(self, topic, client_id):
        return await self._client.execute({
            'cmd': 'pubsub/unsubscribe',
            'clientId': client_id,
            'topic': topic,
        })
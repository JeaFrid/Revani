<?php

class RevaniClient {
    private $host;
    private $port;
    private $secure;
    private $_socket;
    private $_sessionKey;
    private $_accountID;
    private $_projectName;
    private $_projectID;

    public $account;
    public $project;
    public $data;
    public $storage;
    public $livekit;
    public $pubsub;

    public function __construct(string $host, int $port = 16897, bool $secure = true) {
        $this->host = $host;
        $this->port = $port;
        $this->secure = $secure;
        $this->account = new RevaniAccount($this);
        $this->project = new RevaniProject($this);
        $this->data = new RevaniData($this);
        $this->storage = new RevaniStorage($this);
        $this->livekit = new RevaniLivekit($this);
        $this->pubsub = new RevaniPubSub($this);
    }

    public function connect() {
        $protocol = $this->secure ? "ssl" : "tcp";
        $remote = $protocol . "://" . $this->host . ":" . $this->port;
        $context = stream_context_create([
            "ssl" => [
                "verify_peer" => false,
                "verify_peer_name" => false,
            ]
        ]);

        $this->_socket = stream_socket_client($remote, $errno, $errstr, 30, STREAM_CLIENT_CONNECT, $context);
        
        if (!$this->_socket) {
            throw new Exception("Connection failed: $errstr");
        }
    }

    public function execute(array $command, bool $useEncryption = true): array {
        $payload = ($useEncryption && $this->_sessionKey !== null)
            ? ['encrypted' => $this->_encrypt(json_encode($command))]
            : $command;

        $jsonPayload = json_encode($payload);
        $length = strlen($jsonPayload);
        $header = pack('N', $length);

        fwrite($this->_socket, $header);
        fwrite($this->_socket, $jsonPayload);

        $responseHeader = fread($this->_socket, 4);
        if (!$responseHeader) {
            $this->disconnect();
            throw new Exception("Connection closed");
        }

        $unpackHeader = unpack('Nlength', $responseHeader);
        $responseLength = $unpackHeader['length'];
        
        $responsePayload = "";
        while (strlen($responsePayload) < $responseLength) {
            $chunk = fread($this->_socket, $responseLength - strlen($responsePayload));
            if (!$chunk) break;
            $responsePayload .= $chunk;
        }

        $json = json_decode($responsePayload, true);

        if (isset($json['encrypted']) && $this->_sessionKey !== null) {
            $decrypted = $this->_decrypt($json['encrypted']);
            return json_decode($decrypted, true);
        }

        return $json;
    }

    private function _encrypt(string $text): string {
        $wrapper = json_encode([
            "payload" => $text,
            "ts" => (int)(microtime(true) * 1000)
        ]);

        $salt = random_bytes(16);
        $saltBase64 = base64_encode($salt);
        
        $keyBytes = hash('sha256', $this->_sessionKey . $saltBase64, true);
        $iv = random_bytes(16);
        
        $ciphertext = openssl_encrypt($wrapper, 'aes-256-gcm', $keyBytes, OPENSSL_RAW_DATA, $iv, $tag);

        return $saltBase64 . ":" . base64_encode($iv) . ":" . base64_encode($ciphertext . $tag);
    }

    private function _decrypt(string $encryptedData): string {
        $parts = explode(':', $encryptedData);
        $saltBase64 = $parts[0];
        $iv = base64_decode($parts[1]);
        $cipherAndTag = base64_decode($parts[2]);
        
        $tag = substr($cipherAndTag, -16);
        $ciphertext = substr($cipherAndTag, 0, -16);

        $keyBytes = hash('sha256', $this->_sessionKey . $saltBase64, true);
        
        $decrypted = openssl_decrypt($ciphertext, 'aes-256-gcm', $keyBytes, OPENSSL_RAW_DATA, $iv, $tag);
        
        $wrapper = json_decode($decrypted, true);
        return $wrapper['payload'];
    }

    public function setSession(string $key) { $this->_sessionKey = $key; }
    public function setAccount(string $id) { $this->_accountID = $id; }
    public function setProject(string $name, ?string $id) {
        $this->_projectName = $name;
        $this->_projectID = $id;
    }

    public function getAccountID(): string { return $this->_accountID ?? ""; }
    public function getProjectName(): string { return $this->_projectName ?? ""; }
    public function getProjectID(): string { return $this->_projectID ?? ""; }

    public function disconnect() {
        if ($this->_socket) {
            fclose($this->_socket);
        }
        $this->_socket = null;
        $this->_sessionKey = null;
        $this->_accountID = null;
        $this->_projectName = null;
        $this->_projectID = null;
    }
}

class RevaniAccount {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function create(string $email, string $password, ?array $extraData = null): array {
        return $this->_client->execute([
            'cmd' => 'account/create',
            'email' => $email,
            'password' => $password,
            'data' => $extraData ?? new stdClass(),
        ], false);
    }

    public function login(string $email, string $password): bool {
        $res = $this->_client->execute([
            'cmd' => 'auth/login',
            'email' => $email,
            'password' => $password,
        ], false);

        if (isset($res['status']) && $res['status'] == 200) {
            $this->_client->setSession($res['session_key']);
            $idRes = $this->_client->execute([
                'cmd' => 'account/get-id',
                'email' => $email,
                'password' => $password,
            ], false);

            if (isset($idRes['status']) && $idRes['status'] == 200) {
                $this->_client->setAccount($idRes['data']['id']);
            }
            return true;
        }
        return false;
    }

    public function getData(): array {
        return $this->_client->execute([
            'cmd' => 'account/get-data',
            'id' => $this->_client->getAccountID(),
        ]);
    }
}

class RevaniProject {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function use(string $projectName): array {
        $res = $this->_client->execute([
            'cmd' => 'project/exist',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $projectName,
        ]);

        if (isset($res['status']) && $res['status'] == 200) {
            $this->_client->setProject($projectName, $res['id']);
        }
        return $res;
    }

    public function create(string $projectName): array {
        $res = $this->_client->execute([
            'cmd' => 'project/create',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $projectName,
        ]);
        if (isset($res['status']) && $res['status'] == 200) {
            $this->_client->setProject($projectName, $res['data']['id']);
        }
        return $res;
    }
}

class RevaniData {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function add(string $bucket, string $tag, array $value): array {
        return $this->_client->execute([
            'cmd' => 'data/add',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'bucket' => $bucket,
            'tag' => $tag,
            'value' => $value,
        ]);
    }

    public function get(string $bucket, string $tag): array {
        return $this->_client->execute([
            'cmd' => 'data/get',
            'projectID' => $this->_client->getProjectID(),
            'bucket' => $bucket,
            'tag' => $tag,
        ]);
    }

    public function query(string $bucket, array $query): array {
        return $this->_client->execute([
            'cmd' => 'data/query',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'bucket' => $bucket,
            'query' => $query,
        ]);
    }

    public function update(string $bucket, string $tag, $newValue): array {
        return $this->_client->execute([
            'cmd' => 'data/update',
            'projectID' => $this->_client->getProjectID(),
            'bucket' => $bucket,
            'tag' => $tag,
            'newValue' => $newValue,
        ]);
    }

    public function delete(string $bucket, string $tag): array {
        return $this->_client->execute([
            'cmd' => 'data/delete',
            'projectID' => $this->_client->getProjectID(),
            'bucket' => $bucket,
            'tag' => $tag,
        ]);
    }
}

class RevaniStorage {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function upload(string $fileName, array $bytes, bool $compress = false): array {
        return $this->_client->execute([
            'cmd' => 'storage/upload',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'fileName' => $fileName,
            'bytes' => $bytes,
            'compress' => $compress,
        ]);
    }

    public function download(string $fileId): array {
        return $this->_client->execute([
            'cmd' => 'storage/download',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'fileId' => $fileId,
        ]);
    }

    public function delete(string $fileId): array {
        return $this->_client->execute([
            'cmd' => 'storage/delete',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'fileId' => $fileId,
        ]);
    }
}

class RevaniLivekit {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function init(string $host, string $apiKey, string $apiSecret): array {
        return $this->_client->execute([
            'cmd' => 'livekit/init',
            'host' => $host,
            'apiKey' => $apiKey,
            'apiSecret' => $apiSecret,
        ]);
    }

    public function autoConnect(): array {
        return $this->_client->execute([
            'cmd' => 'livekit/connect',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
        ]);
    }

    public function createToken(string $roomName, string $userID, string $userName, bool $isAdmin = false): array {
        return $this->_client->execute([
            'cmd' => 'livekit/create-token',
            'roomName' => $roomName,
            'userID' => $userID,
            'userName' => $userName,
            'isAdmin' => $isAdmin,
        ]);
    }

    public function createRoom(string $roomName, int $timeout = 10, int $maxUsers = 50): array {
        return $this->_client->execute([
            'cmd' => 'livekit/create-room',
            'roomName' => $roomName,
            'emptyTimeoutMinute' => $timeout,
            'maxUsers' => $maxUsers,
        ]);
    }
}

class RevaniPubSub {
    private $_client;
    public function __construct($client) { $this->_client = $client; }

    public function subscribe(string $topic, string $clientId): array {
        return $this->_client->execute([
            'cmd' => 'pubsub/subscribe',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'clientId' => $clientId,
            'topic' => $topic,
        ]);
    }

    public function publish(string $topic, array $data, ?string $clientId = null): array {
        return $this->_client->execute([
            'cmd' => 'pubsub/publish',
            'accountID' => $this->_client->getAccountID(),
            'projectName' => $this->_client->getProjectName(),
            'topic' => $topic,
            'data' => $data,
            'clientId' => $clientId,
        ]);
    }

    public function unsubscribe(string $topic, string $clientId): array {
        return $this->_client->execute([
            'cmd' => 'pubsub/unsubscribe',
            'clientId' => $clientId,
            'topic' => $topic,
        ]);
    }
}
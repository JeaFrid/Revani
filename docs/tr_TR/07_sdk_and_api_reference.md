# 📚 SDK ve API Referans Rehberi

Revani, tüm istemciler için standartlaştırılmış bir protokol kullanır. Bu rehberde Dart SDK üzerinden anlatılan tüm yapılar, metod isimleri ve parametreler; Python, PHP ve diğer dillerdeki Revani kütüphaneleriyle birebir aynıdır.

## 1. Giriş: RevaniClient Yapısı
Revani ile olan tüm etkileşiminiz `RevaniClient` sınıfı üzerinden başlar. Bu sınıf, sunucu ile olan TCP bağlantısını, el sıkışma sürecini ve şifreli paket trafiğini otomatik olarak yönetir.



### Bağlantı Kurma
Sunucuya bağlanmak için host ve port bilgilerini girmeniz yeterlidir. `secure` parametresi, TLS/SSL katmanının aktif olup olmayacağını belirler.

```dart
final client = RevaniClient(
  host: '127.0.0.1', 
  port: 16897, 
  secure: true
);

await client.connect();
```

---

## 2. Hesap ve Kimlik Doğrulama (RevaniAccount)
Revani'de her işlem bir hesaba ve projeye bağlıdır. Güvenlik gereği `create` ve `login` metodları dışındaki tüm trafik şifreli akar.

### Hesap Oluşturma ve Giriş
```dart
// Yeni bir hesap oluşturun (Tek seferlik)
await client.account.create("admin@revani.com", "guclu_sifre");

// Giriş yapın (Handshake ve Session Key alımı otomatik gerçekleşir)
bool success = await client.account.login("admin@revani.com", "guclu_sifre");
```
*Not: Login başarılı olduğunda `session_key` otomatik olarak set edilir ve sonraki tüm talepler AES-GCM ile zırhlanır.*

---

## 3. Proje Yönetimi (RevaniProject)
Revani, "Multi-Tenant" bir yapıya sahiptir. Veriler projeler altında izole edilir.

```dart
// Yeni bir proje oluşturun
await client.project.create("AkilliEv_Sistemi");

// Mevcut bir projeyi aktif edin
await client.project.use("AkilliEv_Sistemi");
```

---

## 4. NoSQL Veri İşlemleri (RevaniData)
Revani'nin kalbi olan NoSQL RevaniEngine motoru; `bucket`, `tag` ve `value` hiyerarşisiyle çalışır.

### Veri Ekleme ve Güncelleme
```dart
await client.data.add(
  bucket: "sensor_verileri",
  tag: "salon_sicaklik",
  value: {"temp": 24.5, "unit": "C"}
);

await client.data.update(
  bucket: "sensor_verileri",
  tag: "salon_sicaklik",
  newValue: {"temp": 22.0}
);
```

### Veri Okuma ve Sorgulama
```dart
// Tekil veri çekme
var res = await client.data.get(bucket: "sensor_verileri", tag: "salon_sicaklik");

// Gelişmiş sorgulama
var queryRes = await client.data.query(
  bucket: "sensor_verileri",
  query: {"temp": {"$gt": 20}} // 20 dereceden büyükleri getir
);
```

---

## 5. Nesne Depolama (RevaniStorage)
Dosyalarınızı şifreli ve optimize edilmiş bir şekilde diskte saklamanızı sağlar.

```dart
// Dosya yükleme
await client.storage.upload(
  fileName: "profil_foto.jpg",
  bytes: fileBytes,
  compress: true // Otomatik sıkıştırma
);

// Dosya indirme
var file = await client.storage.download("file_id_buraya");
```

---

## 6. Gerçek Zamanlı Servisler (Livekit & PubSub)
Revani, veritabanı olmanın ötesinde bir iletişim köprüsüdür.

### PubSub (Yayın/Abone)
Anlık mesajlaşma veya olay tabanlı sistemler için kullanılır.
```dart
// Kanala abone ol
await client.pubsub.subscribe("ev_alarm", "client_id_01");

// Kanala mesaj gönder
await client.pubsub.publish("ev_alarm", {"status": "triggered"});
```

### Livekit Entegrasyonu
Sesli ve görüntülü odaların yönetimini sunucu tarafında güvenli hale getirir.
```dart
await client.livekit.createRoom("Toplanti_Odasi_1");
var token = await client.livekit.createToken(
  roomName: "Toplanti_Odasi_1",
  userID: "user_123",
  userName: "JeaFriday"
);
```

---

## 🛡️ Güvenlik Notu: Protokol Uyumluluğu
Hangi dili kullanırsanız kullanın (Python, PHP, C# vb.), Revani SDK'ları arka planda şu standartları uygular:
1.  **Frame Header:** Her paket 4 byte'lık (Uint32) bir uzunluk bilgisiyle başlar.
2.  **Encryption:** `salt:iv:ciphertext` formatında AES-GCM şifreleme kullanılır.
3.  **Timestamp:** Her şifreli paket içinde Replay Attack koruması için `ts` (timestamp) barındırır.



---
Bu dökümanın devamı, *08_endpoint_reference.md* dosyasındadır.


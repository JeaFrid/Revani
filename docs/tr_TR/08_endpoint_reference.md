# 🔌 Endpoint ve Protokol Referansı

Bu döküman, Revani sunucusuyla SDK kullanmadan doğrudan TCP üzerinden iletişim kurmak isteyen geliştiriciler için hazırlanmıştır. Revani, standart bir HTTP arayüzü yerine düşük gecikmeli, binary paket yapısına sahip özel bir protokol kullanır.

## 1. İletişim Protokolü (The Wire Format)

Revani sunucusuyla iletişim kurarken şu üç kurala uymanız zorunludur:
1.  **Bağlantı:** TCP soketi üzerinden bağlantı kurulur (Varsayılan Port: `16897`).
2.  **Güvenlik:** Sunucu `secure: true` modundaysa SSL/TLS el sıkışması zorunludur.
3.  **Frame Yapısı:** Her mesaj bir "Header" ve "Payload"dan oluşur.

### Paket Çerçevesi (Frame Structure)
Mesaj gönderirken mesajın başına mesaj boyutunu belirten 4 byte'lık bir başlık eklemelisiniz.

| Bölüm | Boyut | Tip | Açıklama |
| :--- | :--- | :--- | :--- |
| **Header** | 4 Byte | Uint32 (Big Endian) | Payload'ın byte cinsinden uzunluğu. |
| **Payload** | Değişken | UTF-8 JSON | İsteğin veya yanıtın kendisi. |



---

## 2. Şifreleme Algoritması (Security Implementation)

`auth/login` işleminden sonra dönen `session_key` ile tüm isteklerinizi zırhlamanız gerekir.

**İstek Paketleme Adımları:**
1.  **Wrapper Oluşturma:** Göndermek istediğiniz komutu şu JSON içine koyun:
    `{"payload": "COMMAND_JSON_STRING", "ts": TIMESTAMP_MS}`
2.  **Key Türetme:** 16 byte rastgele `salt` üretin. Anahtar = `SHA256(session_key + salt_base64)`.
3.  **Şifreleme:** AES-GCM (256-bit) kullanarak, 16 byte rastgele `iv` ile wrapper'ı şifreleyin.
4.  **Final String:** `salt_base64 : iv_base64 : ciphertext_base64` formatında bir string oluşturun.
5.  **Envelope:** Sunucuya gönderilecek nihai JSON: `{"encrypted": "FINAL_STRING"}`.

---

## 3. Endpoint (Komut) Listesi

Tüm komutlar JSON içindeki `cmd` anahtarıyla belirtilir.

### A. Hesap ve Kimlik Doğrulama
| Komut (`cmd`) | Parametreler | Açıklama |
| :--- | :--- | :--- |
| `account/create` | `email`, `password`, `data` | Yeni hesap oluşturur (Şifresiz). |
| `auth/login` | `email`, `password` | `session_key` döndürür (Şifresiz). |
| `account/get-id` | `email`, `password` | Hesabın benzersiz ID'sini döndürür. |
| `account/get-data`| `id` | Hesaba ait ekstra verileri getirir. |

### B. Proje Yönetimi
| Komut (`cmd`) | Parametreler | Açıklama |
| :--- | :--- | :--- |
| `project/create` | `accountID`, `projectName` | Yeni proje ve veritabanı dosyası oluşturur. |
| `project/exist` | `accountID`, `projectName` | Projenin varlığını ve ID'sini kontrol eder. |

### C. NoSQL Veri Operasyonları (RevaniEngine)
Tüm parametreler şifreli paket içinde gönderilmelidir.

| Komut (`cmd`) | Önemli Parametreler | İşlev |
| :--- | :--- | :--- |
| `data/add` | `bucket`, `tag`, `value` | Yeni veri ekler (Append-only). |
| `data/get` | `bucket`, `tag`, `projectID` | Belirli bir veriyi çeker. |
| `data/update` | `bucket`, `tag`, `newValue` | Veriyi günceller (Sona ekleyerek). |
| `data/delete` | `bucket`, `tag` | Veriyi silindi olarak işaretler. |
| `data/query` | `bucket`, `query` | Mantıksal sorgu çalıştırır ($gt, $lt vb.). |

### D. Depolama ve Medya (RevaniStorage & Livekit)
| Komut (`cmd`) | Açıklama |
| :--- | :--- |
| `storage/upload` | `bytes` (List<int>) ve `fileName` ile dosya yükleme. |
| `livekit/init` | Sunucu tarafında Livekit API yapılandırmasını kurar. |
| `livekit/create-token`| İstemci için odaya giriş token'ı üretir. |
| `pubsub/publish` | Belirli bir `topic` üzerinden veri yayını yapar. |

---

## 4. Hata Kodları ve Yanıt Formatı

Sunucudan gelen her yanıt standart bir yapıdadır:
```json
{
  "status": 200,      // 200: OK, 400: Error, 401: Unauthorized
  "data": { ... },    // İşlem başarılıysa dönen veri
  "msg": "Açıklama"   // Hata durumunda hata mesajı
}
```

> 💡 **Önemli:** Eğer sunucu şifreli bir yanıt gönderiyorsa, yanıt size `{"encrypted": "..."}` şeklinde gelecektir. İstemci tarafında aynı AES-GCM mantığıyla bu paketi çözmeniz gerekir.
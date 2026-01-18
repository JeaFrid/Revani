
# Kriptografik Protokol Tasarımı
Revani, güvenliği bir eklenti olarak değil, sistemin en temel bileşeni olarak görür. İletişim katmanında "Sıfır Güven" mimarisi üzerine kurulu özel bir protokol kullanır.

1. **AES-GCM 256-bit:** Şeffaf ve Zırhlı İletişim

İstemci (Client) ve Sunucu (Server) arasındaki tüm veri akışı AES-GCM ile şifrelenir. Bu algoritmanın seçilme nedenleri:

**Gizlilik:** Verinin yetkisiz kişilerce okunmasını engeller.

**Bütünlük:** Verinin yolda değiştirilip değiştirilmediğini matematiksel olarak garanti eder.

**AEAD Desteği:** Kimlik doğrulamalı şifreleme sayesinde hem şifreleme hem de veri doğrulama işlemleri tek adımda gerçekleştirilir.

2. **Dinamik Oturum Yönetimi ve Salt/Nonce Türetimi**
Statik şifreleme anahtarları her zaman saldırıya açıktır. Revani, bu riski şu şekilde minimize eder:

**Oturum Bazlı Anahtarlar:** Her yeni bağlantıda istemci ve sunucu arasında benzersiz bir oturum anahtarı türetilir.

**Request-Specific IV:** Her bir istek, şifreleme kütüphanesi tarafından üretilen rastgele bir IV ve Salt kullanır. Bu, aynı komut iki kez gönderilse bile oluşan şifreli çıktıların tamamen farklı olmasını sağlar.

3. **Tekrar Saldırısı Koruması**
Saldırganlar şifreyi çözemese bile, ele geçirdikleri geçerli bir paketi sunucuya tekrar göndererek işlem yapmaya çalışabilirler. Revani bu durumu şu mekanizmayla engeller:

**Zaman Damgalı Paketler:** Şifrelenmiş her paket içinde hassas bir zaman damgası barındırır.

**30 Saniye Kuralı:** Sunucu, gelen paketin damgasını kendi saatiyle karşılaştırır. Eğer paket 30 saniyeden daha eski bir damgaya sahipse, şifre doğru olsa bile paket "Replay Attack Detected" hatasıyla reddedilir.

4. **Kimlik Doğrulama:** *Argon2id*

Kullanıcıların sisteme girişi sırasında kullanılan şifreler, standart hashing yöntemleriyle değil, Argon2id algoritması ile korunur:

**Bellek Sertliği:** GPU veya ASIC tabanlı kaba kuvvet saldırılarının maliyetini katlanılamaz seviyeye çıkarır.

**Zaman ve Bellek Parametreleri:** Sunucu yapılandırmasındaki iterasyon ve bellek parametreleri, saldırganlara karşı matematiksel bir duvar örer.

5. **Güvenlik Katmanları**

Revani'de veri güvenliği iki ana katmana ayrılmıştır:

**In-Transit:** İstemciden sunucuya akan verinin ağ üzerinden çalınmasını engeller.

**At-Rest:** Verinin veritabanı dosyasında (revani.db) şifreli olarak saklanması. Bu sayede fiziksel diske erişen bir saldırgan, anlamlı bir veri elde edemez.

**Teknik Özet**

Revani protokolü, kriptografik primitifleri bir araya getirerek, her paketin tekilliğini, gizliliğini ve bütünlüğünü garanti altına alan bir mühendislik çalışmasıdır.


---
Bu dökümanın devamı, *04_data_persistence.md* dosyasındadır.

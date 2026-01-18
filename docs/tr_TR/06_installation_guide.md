
# Kurulum ve Sunucu Hazırlık Rehberi

Bu rehber, temiz bir Ubuntu sunucuda Revani'yi sıfırdan başlatmak için gereken tüm adımları içerir.

## 1. Sistem Gereksinimleri ve Güncelleme
Öncelikle işletim sistemindeki temel araçları ve paket depolarını güncelleyelim:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git curl unzip build-essential python3 python3-pip -y
```

## 2. Dart SDK Kurulumu
Revani'nin motoru Dart ile yazılmıştır. Resmi Google depolarını kullanarak kurulumu gerçekleştirelim:

```bash
# Gerekli anahtarları ve depoları ekleyin
wget -qO- [https://dl-ssl.google.com/linux/linux_signing_key.pub](https://dl-ssl.google.com/linux/linux_signing_key.pub) | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] [https://storage.googleapis.com/download.dartlang.org/linux/debian](https://storage.googleapis.com/download.dartlang.org/linux/debian) stable main' | sudo tee /etc/apt/sources.list.d/dart.list

# Kurulumu gerçekleştirin
sudo apt update
sudo apt install dart
```

## 3. Yan Servislerin Hazırlanması (Livekit)
Revani, gerçek zamanlı sesli/görüntülü iletişim yönetimi için **Livekit** ile entegre çalışır.

- **Docker üzerinden hızlı geliştirme kurulumu:**
```bash
docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit server --dev
```

## 4. Revani'nin Klonlanması ve Bağımlılıklar
Proje kaynak kodlarını GitHub üzerinden çekin ve bağımlılıkları yükleyin:

```bash
git clone [https://github.com/JeaFrid/Revani.git](https://github.com/JeaFrid/Revani.git)
cd Revani
dart pub get
```

## 5. Güvenlik Sertifikalarının Üretilmesi
Revani, Zero-Trust mimarisi gereği SSL/TLS kullanımını zorunlu kılar. İhtiyacınıza göre iki farklı yöntem izleyebilirsiniz:

### Yöntem A: Yerel Geliştirme ve Test (Self-Signed)
Geliştirme ortamında hızlıca çalışmak için proje içindeki scripti kullanabilirsiniz:

```bash
# Python bağımlılığını yükleyin
pip3 install cryptography

# Sertifika üreten scripti çalıştırın
python3 cert_gen.py
```
Bu işlem dizinde `server.crt` ve `server.key` dosyalarını oluşturacaktır.

### Yöntem B: Canlı Ortam / Üretim (Let's Encrypt)
Canlı bir sunucuda (domain üzerinde) çalışıyorsanız, ücretsiz ve geçerli bir sertifika almak için **Certbot** kullanmanız önerilir:

```bash
# Certbot yükleyin
sudo apt install certbot -y

# Sertifikanızı alın (Sunucuda 80 portunun boş olduğundan emin olun)
sudo certbot certonly --standalone -d alanadiniz.com

# Üretilen sertifikaları Revani'nin tanıyacağı isimlere bağlayın (Sembolik Link)
ln -s /etc/letsencrypt/live/[alanadiniz.com/fullchain.pem](https://alanadiniz.com/fullchain.pem) server.crt
ln -s /etc/letsencrypt/live/[alanadiniz.com/privkey.pem](https://alanadiniz.com/privkey.pem) server.key
```
> 🛡️ **Güvenlik Notu:** Canlı ortamda sertifikaların okunabilmesi için `server.key` dosyasının izinlerini kontrol edin. Revani, bu sertifikaların yollarını `lib/config.dart` dosyasındaki yapılandırmaya göre arar.

## 6. Ortam Değişkenleri (.env) Yapılandırması
Revani'nin depolama motorunu kilitlemek için bir gizli anahtar tanımlayın:

```bash
nano .env
# İçine şunu yazın:
PASSWORD=Sizin_Cok_Guclu_Sifreniz
```

## 7. Fırını Ateşlemek: Sunucuyu Başlatma
Revani sunucusunu başlatmak için şu komutu verin:

```bash
dart bin/server.dart
```

### 🐳 Docker Kullanarak Hızlı Kurulum (Alternatif)
```bash
docker build -t revani-bakery .
docker run -p 16897:16897 revani-bakery
```

---

## 💡 Teknik İpuçları
* **Ağ Ayarları:** Revani varsayılan olarak `16897` portunu kullanır. `sudo ufw allow 16897` ile izin verebilirsiniz.
* **Performans:** Loglarda gördüğünüz Chef (Şef) sayısı, işlemcinizin çekirdek sayısına (Isolates) eşittir.
---
Bu dökümanın devamı, *07_sdk_and_api_reference.md* dosyasındadır.
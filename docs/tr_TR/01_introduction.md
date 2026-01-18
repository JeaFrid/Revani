# Giriş ve Vizyon
Revani, geleneksel veritabanı yönetim sistemlerindeki hantal yapıları, merkezi kilitlenme darboğazlarını ve güvenliği sadece uygulama katmanına bırakan zayıf yaklaşımları ortadan kaldırmak amacıyla tasarlanmış, yüksek performanslı bir NoSQL motoru ve bütünleşik teknoloji ekosistemidir.

## Vizyonumuz
Revani'nin temel vizyonu, veriyi sadece saklayan bir birim olmaktan çıkıp; onu taşıyan, işleyen ve koruyan "zırhlı bir teknoloji çekirdeği" haline gelmektir. Modern dünyada hızın güvenlikten, güvenliğin ise hızdan feragat etmemesi gerektiğine inanıyoruz.

## Revani Nedir?
Revani, tek bir API ve protokol üzerinden şu temel sorunları çözen bir "Teknoloji Kutusu"dur:

**Güvenlik Çekirdeği:** Çoğu sistemde şifreleme opsiyonel bir eklentiyken, Revani'de mimarinin temel taşıdır. Tüm trafik AES-GCM 256-bit ile her an zırh altındadır.

**Maksimum Eşzamanlılık:** Actor Model mimarisi sayesinde her CPU çekirdeğini bağımsız birer işleme birimi olarak kullanarak kilitlenme krizlerini tarih eder.

**Bütünleşik Altyapı:** Veritabanı fonksiyonlarının yanı sıra dosya depolama, gerçek zamanlı PubSub ve Livekit gibi servisleri tek bir ağaç yapısında toplar.

### Temel Hedefler
**Ultra Düşük Gecikme:** Okuma operasyonlarında milisaniye altı seviyelere ulaşmak.

**Sıfır Güven:** Paketlerin sunucuya ulaştığı andan diskte saklandığı ana kadar uçtan uca şifreli kalmasını sağlamak.

**Geliştirici Deneyimi:** Karmaşık backend altyapılarını tek bir "fırından" çıkan hazır ürünler kadar kolay kullanılabilir hale getirmek.

---
Bu dökümanın devamı, *02_architecture_and_philosophy.md* dosyasındadır.

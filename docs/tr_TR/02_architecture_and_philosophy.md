# Mimari ve Felsefe: "The Bakery"
Revani'nin mimarisi, bilgisayar bilimlerindeki en sağlam eşzamanlılık modellerinden biri olan Actor Model üzerine inşa edilmiştir. Bu karmaşık yapıyı daha anlaşılır ve yönetilebilir kılmak için tüm sistem bir "Pastane" metaforu ile tasarlanmıştır.

1. **Actor Model ve "Shared-Nothing" Yaklaşımı**

Geleneksel veritabanları, veriye erişimi kontrol etmek için paylaşılan bellek ve karmaşık kilitleme mekanizmaları kullanır. Revani ise "Hiçbir Şey Paylaşılmaz" prensibiyle çalışır.

**İzolasyon:** Her bir iş birimi kendi bellek alanına sahiptir.

**Mesajlaşma:** Birimler arası veri transferi sadece güvenli mesaj kanalları üzerinden yapılır.

**Yan Etkisizlik:** Bir birimde oluşan hata veya gecikme, sistemin geri kalanını etkilemez.

2. **Pastane Metaforu**

Sistemin çalışma mantığı şu bileşenlerden oluşur:

**👨‍🍳 Şefler (Isolates)** 

Dart dilinin Isolate yapısı, Revani'nin "Şeflerini" temsil eder. Sunucu başladığında, CPU çekirdek sayınız kadar "Şef" fırının başına geçer. Her şef kendi tezgahında bağımsız çalışır.

Kilitlenme yaşanmaz, çünkü her şef sadece kendine gelen sipariş fişini işler.

**🍰 Revani (Nihai Veri)**

*(Revani, Türkiye'de şerbetli bir tatlı türü.)*

Revani, titizlikle hazırlanmış bir sonuçtur. Veri, sunucuda işlendikten sonra RevaniBson formatında paketlenir ve dış dünyaya "zırhlı bir kutuda" sunulur.

**🧹 Hijyen ve Bakım (Sweeping the floor)**

Bir pastanenin verimliliği temizliğine bağlıdır. Revani, arka planda sürekli çalışan bakım döngüleriyle şunları sağlar:

**Compaction:** Dosya sistemindeki boşlukları temizleyerek disk kullanımını optimize eder.

**Sweeping:** Süresi dolmuş verileri temizleyerek belleği taze tutar.

3. **Neden Bu Yapı?**

Bu mimari sadece estetik bir tercih değil, donanım kaynaklarını en üst verimle kullanma stratejisidir. Modern işlemcilerin çok çekirdekli gücü, Revani'nin bağımsız "Şefleri" sayesinde darboğaz oluşmadan eşzamanlı olarak kullanılır.

---
Bu dökümanın devamı, *03_cryptographic_protocol.md* dosyasındadır.

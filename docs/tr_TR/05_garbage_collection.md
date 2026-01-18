
# Çöp Toplama Stratejisi: Kademeli GC
Yüksek performanslı sistemlerde bellek yönetimi kritik bir öneme sahiptir. Revani, sistemi aniden durduran ("Stop-the-world") hantal temizlik mekanizmaları yerine, iş yükünü zamana yayan (Kademeli) Garbage Collection algoritmasını kullanır.

1. **Stop-the-world Problemine Çözüm**

Geleneksel veritabanları temizlik yaparken tüm operasyonları dondurabilir. Bu durum gerçek zamanlı uygulamalarda kabul edilemez gecikmelere yol açar. Revani, temizlik işlemini küçük mikro görevlere bölerek bu sorunu ortadan kaldırır.

2. **Çalışma Prensibi: Akıllı Örnekleme**

Revani'nin "Komi" (GC Aktörü) şu adımları izler:

**Rastgele Örnekleme:** Her temizlik döngüsünde tüm veritabanı taranmaz. Bunun yerine rastgele seçilen belirli bir miktar veri grubu mercek altına alınır.

**TTL Kontrolü:** Örneklem içindeki her verinin yaşam süresi kontrol edilir. Süresi dolmuş veriler anında bellekten ve diskten temizlenmek üzere işaretlenir.

**Yoğunluk Analizi:** Eğer seçilen gruptaki bayat veri oranı %25'in üzerindeyse, sistem "burada çok çöp var" diyerek bir sonraki temizlik döngüsünü daha erkene çeker veya temizlik hacmini artırır.

3. **Donanım Dostu Planlama**

Temizlik işlemleri, ana veritabanı motorunun en boş olduğu milisaniyelik boşluklarda gerçekleştirilir:

**Micro-tasking:** Temizlik görevleri Dart'ın Future.microtask kuyruğuna eklenir. Bu sayede kullanıcıdan gelen bir "yazma" veya "okuma" talebi varsa, temizlik işlemi ona yol verir.

**Isolate Seviyesinde GC:** Her "Şef" (Isolate) kendi bellek alanından sorumlu olduğu için, temizlik işlemleri çekirdekler arasında birbirini beklemeden paralel olarak yürütülür.

4. **Sweeping vs. Compaction Ayrımı**

Revani iki farklı temizlik katmanına sahiptir:

**Sweeping:** Süresi dolmuş verileri bellekten temizler. Süreç çok hızlıdır ve milisaniyeler sürer.

**Sıkıştırma:** Veritabanı dosyasındaki fiziksel boşlukları kapatır. Daha ağır bir işlemdir ve periyodik aralıklarla arka planda yürütülür.

5. **Sonuç:** Tahmin Edilebilir Performans

Bu strateji sayesinde Revani, sistem kaynaklarını anlık olarak tüketmez. Veri miktarı ne kadar artarsa artsın, gecikme süreleri her zaman öngörülebilir ve düşük seviyede kalır.


---
Bu dökümanın devamı, *06_installation_guide.md* dosyasındadır.
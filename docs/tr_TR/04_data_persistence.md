# Veri Kalıcılığı ve Depolama Stratejisi
Revani, yüksek performanslı okuma/yazma operasyonları ile uzun vadeli veri güvenliğini dengelemek için optimize edilmiş bir depolama katmanı kullanır. Veri kalıcılığı stratejimiz, modern veritabanı teorilerindeki en verimli yaklaşımlardan derlenmiştir.

1. **RevaniBson:** Binary Serileştirme Motoru

Veritabanı performansını etkileyen en büyük darboğazlardan biri veri serileştirme işlemidir. Revani, JSON gibi hantal metin formatları yerine kendi yerel binary formatı olan RevaniBson'ı kullanır.

**Tip Güvenliği:** Veri, diskte en saf haliyle (Int64, Double, String, Binary) saklanır.

**Overhead Minimizasyonu:** JSON'un getirdiği parantez, tırnak gibi gereksiz karakter yükü ortadan kaldırılarak disk alanı tasarrufu sağlanır.

**Hızlı Ayrıştırma:** Veri yapısı önceden bilindiği için, CPU veriyi okurken karmaşık string parse işlemleri yapmak yerine doğrudan bellek adreslerine erişir.

2. **Append-Only Logging (AOL)**

Revani, diske yazma işlemlerinde Append-Only (Sadece sona ekle) stratejisini benimser. Bu yaklaşımın üç temel avantajı vardır:

**Sıralı Yazma Performansı:** Disk kafasının sürekli hareket etmesini engelleyerek veriyi dosyanın en sonuna ekler. Bu, özellikle yüksek trafikli sistemlerde yazma hızını maksimize eder.

**Veri Bütünlüğü:** Mevcut verinin üzerine yazılmadığı için, bir çökme anında verinin bozulma riski minimumdur.

**Hızlı Kurtarma:** Sunucu yeniden başladığında, dosyayı sadece bir kez tarayarak en güncel state'i hızlıca belleğe yükler.

3. Veri Sıkıştırma

Append-Only yapısı, zamanla dosya boyutunun büyümesine neden olur. Revani, bu sorunu periyodik olarak çalışan Compaction döngüsüyle çözer.

**"Kneading the Dough":** Arka planda çalışan temizlik süreci, veritabanı dosyasını yeniden organize eder.

**Ölü Kayıtların Temizliği:** Güncellenmiş veya silinmiş verilerin eski kopyaları diskten kalıcı olarak kaldırılır.

**Atomik Değişim:** Sıkıştırma işlemi tamamlandığında, eski dosya ile yeni ve optimize edilmiş dosya atomik olarak yer değiştirir, bu esnada veri akışı kesilmez.

4. **Atomic Flush ve Güvenlik Kilidi**

Veri kaybını önlemek için iki ek mekanizma devrededir:

**Flush Interval:** Bellekteki veriler, kullanıcı tanımlı aralıklarla fiziksel diske kalıcı olarak senkronize edilir.

**Database Lock:** Aynı veritabanı dosyasının (revani.db) yanlışlıkla iki farklı süreç tarafından açılmasını engellemek için .lock dosyası mekanizması kullanılır.

**Teknik Not**


Revani'nin depolama mimarisi, "Yüksek Performanslı Yazma" odaklı sistemler için tasarlanmıştır. Verinin diskteki yolculuğu, RevaniBson ile başlar ve Append-Only günlüğüyle kalıcı hale gelir.


---
Bu dökümanın devamı, *05_garbage_collection.md* dosyasındadır.
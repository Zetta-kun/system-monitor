# 🔧 Sistem Monitorinq Scripti

Universal Linux sistem monitorinq scripti. Bütün Linux distribusiyalarında işləyir.

## 📝 Xüsusiyyətlər

- ✅ Disk istifadəsi (80%-dən çox olarsa xəbərdarlıq)
- ✅ RAM istifadəsi
- ✅ CPU yükü (load average)
- ✅ Ən çox CPU istifadə edən proseslər
- ✅ Servis yoxlaması (nginx, mysql, docker)
- ✅ Port yoxlaması
- ✅ Log faylına yazma
- ✅ Heç bir xüsusi asılılıq tələb etmir

## 🚀 Quraşdırma

```bash
# 1. Reponu klonlayın
git clone https://github.com/istifadeciadim/system-monitor.git
cd system-monitor

# 2. Script-i executable edin
chmod +x monitoring.sh

# 3. Test edin
./monitoring.sh

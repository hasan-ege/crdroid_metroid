#!/bin/sh
# Shows how the long-running downloads are doing.
#   sh tools/status.sh          once
#   watch -n 30 sh tools/status.sh   refreshing every 30 s
here=$(cd "$(dirname "$0")/.." && pwd)
log=/home/hasan/android/crdroid-sync.log

echo "== crDroid kaynakları (repo sync)"
if [ -f "$log" ]; then
    echo "   indirilen: $(du -sh /home/hasan/android/crdroid 2>/dev/null | cut -f1)  (çalışma kopyası dahil toplam ~110-140 GB)"
    last=$(tail -c 2000 "$log" | tr '\r' '\n' | grep -v '^$' | tail -1)
    [ -n "$last" ] && echo "   son satır: $last"
    if grep -q '^exit=' "$log"; then
        echo "   BİTTİ ($(grep '^exit=' "$log"); exit=0 başarılı)"
    elif pgrep -f 'repo sync' >/dev/null; then
        echo "   sürüyor"
    else
        echo "   çalışmıyor ama bitmedi: yarıda kalmış olabilir"
    fi
fi

echo "== Stok B4.1 sistem imajları"
d="$here/stock/B4.1-260814-1733"
if [ -d "$d/logical" ] && ! ls "$d"/*.7z.0* >/dev/null 2>&1; then
    echo "   BİTTİ: $(ls "$d/logical" | wc -l) imaj, $(du -sh "$d/logical" | cut -f1)"
else
    got=$(cat "$d"/*.7z.0* 2>/dev/null | wc -c)
    echo "   indirilen: $((got / 1048576)) MB / ~6700 MB"
fi

echo "== Disk ve bellek"
df -h /home | awk 'NR==2 {print "   /home boş: " $4}'
free -h | awk '/Mem/ {print "   RAM kullanılan: " $3 " / " $2}'

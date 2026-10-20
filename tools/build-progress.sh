#!/usr/bin/env bash
# Live dashboard for tools/build.sh: stage tracker, colour progress bar, speed, ETA, RAM/swap
# and a scrolling tail of the build log (errors red, warnings yellow).
#
#   bash tools/build-progress.sh [log]     (Ctrl+C quits the view; the build keeps running)
#
# Ninja prints "[ 42% 12345/29000] ..." lines. The total restarts for each phase
# (Soong bootstrap, analysis, Kati, then the real ninja run), so the ETA settles once the
# "derleme" stage has run for a few minutes.
LOG=${1:-/home/hasan/android/logs/current_build.log}
WINDOW=300   # seconds of history for the speed estimate

E=$'\e'
R="$E[0m" B="$E[1m" DIM="$E[2m"
RED="$E[38;5;203m" GRN="$E[38;5;114m" YEL="$E[38;5;221m" CYN="$E[38;5;117m"
MAG="$E[38;5;213m" GRY="$E[38;5;245m" WHT="$E[38;5;255m"
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

fmt_time() {
    local s=$1
    if (( s >= 3600 )); then printf '%d sa %02d dk' $((s / 3600)) $((s % 3600 / 60))
    elif (( s >= 60 )); then printf '%d dk %02d sn' $((s / 60)) $((s % 60))
    else printf '%d sn' "$s"; fi
}

# Colour bar: green -> cyan -> magenta along its length, partial cell with ▏▎▍▌▋▊▉.
draw_bar() {  # <permille> <width>
    local pm=$1 w=$2 cells=$(( $1 * $2 * 8 / 1000 )) full part i out="" col
    local parts=("" ▏ ▎ ▍ ▌ ▋ ▊ ▉)
    full=$(( cells / 8 )); part=$(( cells % 8 ))
    for (( i = 0; i < w; i++ )); do
        if   (( i < w / 3 ));     then col="$E[38;5;114m"
        elif (( i < 2 * w / 3 )); then col="$E[38;5;117m"
        else                           col="$E[38;5;213m"; fi
        if (( i < full )); then out+="$col█"
        elif (( i == full && part > 0 )); then out+="$col${parts[part]}"
        else out+="$GRY·"; fi
    done
    printf '%s%s' "$out" "$R"
}

stage_of() {
    if   grep -aqE '^BUILD END' "$LOG";              then echo 5
    elif grep -aqE 'Starting ninja' "$LOG";          then echo 4
    elif grep -aqE '[Kk]ati' "$LOG";                 then echo 3
    elif grep -aqE 'soong_build|Analysis|analysis' "$LOG"; then echo 2
    elif grep -aqE '^\[ *[0-9]+%' "$LOG";            then echo 1
    else echo 0; fi
}
STAGES=("breakfast" "soong kurulum" "Android.bp analizi" "Kati" "derleme" "bitti")

colorize() {  # log line -> coloured
    local l=$1
    case "$l" in
        *FAILED:*|*error:*|*Error:*|*"ninja: build stopped"*|*Killed*) printf '%s%s%s' "$RED" "$l" "$R" ;;
        *warning:*|*Warning:*|*WARNING*)                              printf '%s%s%s' "$YEL" "$l" "$R" ;;
        \[*%*)  local head=${l%%]*}] rest=${l#*] }
                printf '%s%s%s %s%s%s' "$CYN" "$head" "$R" "$WHT" "$rest" "$R" ;;
        *)      printf '%s%s%s' "$GRY" "$l" "$R" ;;
    esac
}

declare -a T D
start=$(date +%s)
sl=$(grep -am1 '^BUILD START' "$LOG" 2>/dev/null)
[[ -n $sl ]] && start=$(date -d "$(sed 's/^BUILD START \(.*\) target=.*/\1/' <<<"$sl")" +%s 2>/dev/null || echo "$start")
last_total=0 tick=0

printf '%s[?25l%s[2J' "$E" "$E"
trap 'printf "%s[?25h%s\n" "$E" "$R"; exit' INT TERM

while true; do
    now=$(date +%s); tick=$(( tick + 1 ))
    cols=$(tput cols 2>/dev/null || echo 100); rows=$(tput lines 2>/dev/null || echo 30)
    tailbuf=$(tail -c 400000 "$LOG" 2>/dev/null | tr '\r' '\n' | grep -av '^\s*$')
    prog=$(grep -aoE '^\[ *[0-9]+% [0-9]+/[0-9]+' <<<"$tailbuf" | tail -1)
    done_n=0 total=0
    [[ $prog =~ ([0-9]+)/([0-9]+) ]] && { done_n=${BASH_REMATCH[1]}; total=${BASH_REMATCH[2]}; }
    pm=0; (( total > 0 )) && pm=$(( done_n * 1000 / total ))
    st=$(stage_of)
    end=$(grep -a '^BUILD END' "$LOG" 2>/dev/null | tail -1)

    # a new phase restarts the counters: reset the speed history
    if (( total != last_total )); then T=(); D=(); last_total=$total; fi
    T+=("$now"); D+=("$done_n")
    while (( ${#T[@]} > 1 && now - T[0] > WINDOW )); do T=("${T[@]:1}"); D=("${D[@]:1}"); done
    dt=$(( now - T[0] )); dd=$(( done_n - D[0] ))
    eta="${DIM}hesaplanıyor…${R}" speed="${DIM}-${R}"
    if (( dt >= 20 && dd > 0 && total > done_n )); then
        eta="$B$(fmt_time $(( (total - done_n) * dt / dd )))$R"
        speed=$(awk -v a="$dd" -v b="$dt" 'BEGIN { printf "%.1f adım/sn", a / b }')
    fi
    # Ninja's own estimate ("[ 99% 20727/20884 8m39s remaining]") knows that the last steps
    # (image packaging) are slow; prefer it over our step-rate guess when it is there.
    nrem=$(grep -aoE '^\[ *[0-9]+% [0-9]+/[0-9]+ [0-9hms]+ remaining\]' <<<"$tailbuf" | tail -1 \
        | grep -oE '[0-9hms]+ remaining' | cut -d' ' -f1)
    if [[ -n $nrem ]]; then
        h=0 m=0 sec=0
        [[ $nrem =~ ([0-9]+)h ]] && h=${BASH_REMATCH[1]}
        [[ $nrem =~ ([0-9]+)m ]] && m=${BASH_REMATCH[1]}
        [[ $nrem =~ ([0-9]+)s ]] && sec=${BASH_REMATCH[1]}
        eta="$B$(fmt_time $(( h * 3600 + m * 60 + sec )))$R ${DIM}(ninja tahmini)${R}"
    fi
    (( st == 4 )) || eta="$eta ${DIM}(bu aşama için)${R}"

    read -r mu mt su stt < <(free -b | awk '/Mem/ {mu=$3; mt=$2} /Swap/ {su=$3; st=$2} END {print mu, mt, su, st}')
    mp=$(( mu * 100 / mt )); spc=0; (( stt > 0 )) && spc=$(( su * 100 / stt ))
    mcol=$GRN; (( mp > 80 )) && mcol=$YEL; (( mp > 93 )) && mcol=$RED
    scol=$GRN; (( spc > 50 )) && scol=$YEL; (( spc > 85 )) && scol=$RED
    load=$(cut -d' ' -f1 /proc/loadavg)

    width=$(( cols - 16 )); (( width > 70 )) && width=70; (( width < 10 )) && width=10

    {
        printf '%s[H' "$E"
        if [[ -n $end ]]; then icon="$GRN✔$R"; [[ $end == *"rc=0"* ]] || icon="$RED✘$R"
        else icon="$MAG${SPIN[tick % 10]}$R"; fi
        printf ' %s %s%scrDroid 16 · Nothing Phone (3) metroid%s   %s%s%s%s[K\n' \
            "$icon" "$B" "$WHT" "$R" "$GRY" "$(date +%H:%M:%S)" "$R" "$E"
        printf ' %s%s%s%s[K\n' "$GRY" "$(printf '─%.0s' $(seq 1 $(( cols - 2 ))))" "$R" "$E"

        # stage tracker
        line=" "
        for i in 0 1 2 3 4; do
            if (( i < st )); then line+="$GRN● ${STAGES[i]}$R"
            elif (( i == st )); then line+="$MAG$B◉ ${STAGES[i]}$R"
            else line+="$GRY○ ${STAGES[i]}$R"; fi
            (( i < 4 )) && line+="$GRY ─ $R"
        done
        printf '%s%s[K\n\n' "$line" "$E"

        printf '  %s  %s%3d.%d%%%s%s[K\n\n' "$(draw_bar "$pm" "$width")" "$B" $(( pm / 10 )) $(( pm % 10 )) "$R" "$E"
        printf '  %sadım%s      %s%s%s / %s%s[K\n' "$GRY" "$R" "$WHT" "$done_n" "$R" "$total" "$E"
        printf '  %shız%s       %s%s[K\n' "$GRY" "$R" "$speed" "$E"
        printf '  %sgeçen%s     %s%s[K\n' "$GRY" "$R" "$(fmt_time $(( now - start )))" "$E"
        printf '  %skalan%s     %s%s[K\n' "$GRY" "$R" "$eta" "$E"
        printf '  %sRAM%s       %s%d%%%s %s(%s)%s   %sswap%s %s%d%%%s %s(%s)%s   %syük%s %s%s[K\n' \
            "$GRY" "$R" "$mcol" "$mp" "$R" "$DIM" "$(numfmt --to=iec "$mu")/$(numfmt --to=iec "$mt")" "$R" \
            "$GRY" "$R" "$scol" "$spc" "$R" "$DIM" "$(numfmt --to=iec "$su")/$(numfmt --to=iec "$stt")" "$R" \
            "$GRY" "$R" "$load" "$E"

        if [[ -n $end ]]; then
            printf '\n'
            if [[ $end == *"rc=0"* ]]; then
                printf '  %s%s✔ DERLEME BAŞARILI%s  %s%s[K\n' "$GRN" "$B" "$R" "$(ls -t /home/hasan/android/crdroid/out/target/product/metroid/*.zip 2>/dev/null | head -1)" "$E"
            else
                printf '  %s%s✘ DERLEME HATAYLA BİTTİ%s  %slog: %s%s%s[K\n' "$RED" "$B" "$R" "$GRY" "$LOG" "$R" "$E"
            fi
        fi

        printf '\n %s── log %s%s%s[K\n' "$GRY" "$(printf '─%.0s' $(seq 1 $(( cols - 9 ))))" "$R" "$E"
        used=$(( 14 + ( ${#end} > 0 ? 2 : 0 ) ))
        n=$(( rows - used - 1 )); (( n < 3 )) && n=3
        while IFS= read -r l; do
            printf ' %s%s[K\n' "$(colorize "${l:0:$(( cols - 2 ))}")" "$E"
        done < <(tail -n "$n" <<<"$tailbuf")
        printf '%s[J' "$E"
    }

    if [[ -n $end ]]; then printf '%s[?25h' "$E"; exit 0; fi
    sleep 2
done

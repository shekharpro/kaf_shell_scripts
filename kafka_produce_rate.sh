#!/bin/bash

kafka_helper_topic_message_rate() {
    while getopts b:t:p: flag; do
        case "${flag}" in
        b) broker=${OPTARG} ;;
        t) topic=${OPTARG} ;;
        p) poll=${OPTARG} ;;
        esac
    done

    local last_high_watermark=0
    local poll_time=$poll
    local last_diff_per_Sec=0
    local last_epoch=0
    local poll_diff_seconds=0

    for (( ; ; )); do
        local current_high_watermark_line=$(kaf topic describe $topic -b $broker | grep -B 1 'Summed HighWatermark')
        local current_epoch=$(date +%s)

        local partitions=$(($(echo $current_high_watermark_line | awk '{print $1F}') + 1))

        local current_high_watermark=$(echo $current_high_watermark_line | awk '{print $NF}')
        local diff=0
        local diffPerSec=0

        if [ $last_epoch -gt 0 ]; then
          poll_diff_seconds=$((current_epoch - last_epoch))
        fi

        if [ $last_high_watermark -gt 0 ]; then
            diff=$((current_high_watermark - last_high_watermark))
            diffPerSec=$((diff / poll_diff_seconds))
        fi

        local BOLD='\033[1;m'
        local RED='\033[0;31m'
        local GREEN='\033[0;32m'
        local YELLOW='\033[0;33m'
        local color=
        local color_off='\033[0m'
        local red_up=$RED'↑'$color_off
        local red_down=$RED'↓'$color_off
        local green_up=$GREEN'↑'$color_off
        local green_down=$GREEN'↓'$color_off
        local arrow='='
        local diff_color=
        local darrow='='

        if [ $diff -gt 0 ]; then
            color=$GREEN
            arrow=$green_up
        else
            color=$color_off
        fi


        if [ $diffPerSec -lt $last_diff_per_Sec ]; then
            diff_color=$RED
            darrow=$red_down
        elif [ $diffPerSec -gt $last_diff_per_Sec ]; then
            diff_color=$GREEN
            darrow=$green_up
        else
            diff_color=$color_off
        fi

        local formattedDiff=$(builtin printf "%6d" $(($diff)))
        local formattedDiffPerSec=$(builtin printf "%4d" $diffPerSec)

       echo $BOLD$(date)$color_off ' | Topic:' "$(builtin printf "%-35s" $topic)" ' | Partitions:' "$(builtin printf "%-10s" $partitions)"

        if [ $last_high_watermark -gt 0 ]; then
            echo '↪ Current Watermark ' $YELLOW"$(builtin printf "%6d" $current_high_watermark)"$color_off $arrow $color"$formattedDiff"$color_off ' | Messages introduced per sec: ' $darrow$diff_color"$formattedDiffPerSec"$color_off"\n"
        else
            echo '↪ Current Watermark ' $YELLOW"$(builtin printf "%6d" $current_high_watermark)$color_off\n"
        fi

        last_high_watermark=$current_high_watermark
        last_diff_per_Sec=$diffPerSec
        last_epoch=$current_epoch
        sleep $poll_time
    done
}

kafka_helper_topic_message_rate -b $1 -t $2 -p $3

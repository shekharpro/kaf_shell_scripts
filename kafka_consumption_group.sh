#!/bin/bash

kafka_helper_track_group_lag() {
    while getopts b:g:p: flag; do
        case "${flag}" in
        b) broker=${OPTARG} ;;
        g) group=${OPTARG} ;;
        p) poll=${OPTARG} ;;
        esac
    done

    local last_lag=0
    local last_group_high_watermark=0
    local last_total_topic_watermark=0
    local last_consumed_diff=0
    local last_epoch=0
    local poll_time=$poll
    local poll_diff_seconds=$poll_time

    for (( ; ; )); do
        local groupNumbers
        groupNumbers=$(kaf group describe $group -b $broker --no-members | grep 'Total\|State')
        local current_epoch=$(date +%s)
        local current_lag=0
        local current_group_high_watermark=0
        while IFS= read -r lagDetails; do
            if [ "$(echo "$lagDetails" | grep -c -e "State")" -eq 1 ]; then
                local kafka_state=$(echo $lagDetails | awk '{print $1 $2}')
            else
                the_lag=$(echo $lagDetails | awk '{print $NF}')
                the_group_highWatermark=$(echo $lagDetails | awk '{print $2F}')
                current_lag=$((current_lag + the_lag))
                current_group_high_watermark=$((current_group_high_watermark + the_group_highWatermark))
            fi

        done <<<"$groupNumbers"
        local diff=0
        local diffPerSec=0
        local current_consumed_diff=0
        local current_consumed_diff_diff=0

        if [ $last_epoch -gt 0 ]; then
            poll_diff_seconds=$((current_epoch - last_epoch))
        fi

        if [ $last_lag -gt 0 ]; then
            diff=$((last_lag - current_lag))
            diffPerSec=$((diff / poll_diff_seconds))
            current_consumed_diff=$((current_group_high_watermark - last_group_high_watermark))
            if [ $last_consumed_diff -gt 0 ]; then
                current_consumed_diff_diff=$((current_consumed_diff - last_consumed_diff))
            fi
        fi
        local formattedState=$(builtin printf '%-30s' $kafka_state)
        local BOLD='\033[1;m'
        local RED='\033[0;31m'
        local GREEN='\033[0;32m'
        local YELLOW='\033[0;33m'
        local color=
        local ncolor=
        local color_off='\033[0m'
        local red_up=$RED'↑'$color_off
        local red_down=$RED'↓'$color_off
        local green_up=$GREEN'↑'$color_off
        local green_down=$GREEN'↓'$color_off
        local stateColor=
        local arrow='='
        local narrow='='

        if [ $diff -lt 0 ]; then
            color=$RED
            arrow=$red_up
        elif [ $diff -gt 0 ]; then
            color=$GREEN
            arrow=$green_down
        else
            color=$color_off
        fi

        if [ $current_consumed_diff_diff -lt 0 ]; then
            ncolor=$RED
            narrow=$red_down
        elif [ $current_consumed_diff_diff -gt 0 ]; then
            ncolor=$GREEN
            narrow=$green_up
        else
            ncolor=$color_off
        fi
        local formattedDiff=$(builtin printf "%6d" $((-$diff)))
        local formattedDiffPerSec=$(builtin printf "%4d" $diffPerSec)

        if [[ "$kafka_state" == *"Stable"* ]]; then
            stateColor=$GREEN
        else
            stateColor=$YELLOW
        fi

        if [ $last_lag -gt 0 ]; then
            if [ $last_group_high_watermark -gt 0 ]; then
                echo $BOLD$(date)$color_off ' | ' "$(builtin printf "GROUP:%-45s" $group)" ' | ' $stateColor"$formattedState"$color_off
                echo '↪ Current Lag ' $YELLOW"$(builtin printf "%6d" $current_lag)"$color_off $arrow $color"$formattedDiff"$color_off ' | Lag reduced per sec: ' $color"$formattedDiffPerSec"$color_off ' | Processed:' $YELLOW$current_consumed_diff$color_off $narrow $ncolor"$current_consumed_diff_diff"$color_off ' | Processed per sec:' $ncolor"$((current_consumed_diff / poll_diff_seconds))"$color_off'\n'
            else
                echo $BOLD$(date)$color_off ' | ' "$(builtin printf "GROUP:%-45s" $group)" ' | ' $stateColor"$formattedState"$color_off
                echo '↪ Current Lag ' $YELLOW"$(builtin printf "%6d" $current_lag)"$color_off $arrow $color"$formattedDiff"$color_off ' | Lag reduced per sec: ' $color"$formattedDiffPerSec"$color_off ' | Processed:' $YELLOW$current_consumed_diff$color_off'\n'
            fi
        else
            echo $BOLD$(date)$color_off ' | ' "$(builtin printf "GROUP:%-45s" $group)" ' | ' $stateColor"$formattedState"$color_off
            echo '↪ Current Lag ' $YELLOW"$(builtin printf "%6d" $current_lag)"$color_off'\n'
        fi

        last_lag=$current_lag
        last_group_high_watermark=$current_group_high_watermark
        last_consumed_diff=$current_consumed_diff
        last_epoch=$current_epoch
        sleep $poll_time
    done
}

kafka_helper_track_group_lag -b $1 -g $2 -p $3

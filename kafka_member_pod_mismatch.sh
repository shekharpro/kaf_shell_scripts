#!/bin/bash


kafka_member_pod_mismatch() {
  if ! command -v kaf &> /dev/null
  then
      echo "'kaf' could not be found, you can install it by running following:"
      echo "brew install kaf"
      exit
  fi
  if ! command -v kubectl &> /dev/null
  then
      echo "'kubectl' could not be found, you can install it by running following:"
      echo "brew install kubectl"
      exit
  fi

   while getopts b:g:p: flag; do
       # shellcheck disable=SC2220
      case "${flag}" in
      b) broker=${OPTARG} ;;
      g) group=${OPTARG} ;;
      p) podName=${OPTARG} ;;
      esac
   done

  local GREEN='\033[0;32m'
  local RED='\033[0;31m'
  local YELLOW='\033[0;33m'
  local color_off='\033[0m'

  local availablePods
  local kafkaGroupMembers
  local matchingMemberCounter=0
  local missingMemberCounter=0
  local kafkaState
  local kafkaStateColor
  availablePods=$(kubectl get pods -n services -o wide | grep "$podName" | awk '{printf ("%5s\t%s\t%5s\n",$6F,$5,$1F)}'| sort)
  kafkaGroupDescribeLine=$(kaf group describe "$group" -b "$broker" | grep 'Host\|State')
  kafkaState=$(echo "$kafkaGroupDescribeLine" | grep State | awk '{printf $NF}')

  if [[ "$kafkaState" == *"Stable"* ]]; then
    kafkaStateColor=$GREEN
  else
    kafkaStateColor=$YELLOW
  fi

  kafkaGroupMembers=$(echo "$kafkaGroupDescribeLine" | grep Host  | awk -F '/' '{print $NF}' | sort)
  
  #  echo "$availablePods"
  #  echo "$kafkaGroupMembers"
  local resultOutput="\n MEMBER STATUS     HOST         AGE     POD"
  while IFS= read -r poddetails; do
      if  [ "$(echo "$poddetails" | grep -c -e "$kafkaGroupMembers")" -eq 1 ]; then
        resultOutput="$resultOutput\n$GREEN ASSIGNED MEMBER : $poddetails$color_off"
        matchingMemberCounter=$((matchingMemberCounter+1))
      else
        resultOutput="$resultOutput\n$RED MISSING MEMBER  : $poddetails$color_off"
        missingMemberCounter=$((missingMemberCounter+1))
      fi
  done <<< "$availablePods"
  echo "$kafkaStateColor GROUP STATE :" "$kafkaState"  "$color_off" "$GREEN""ASSIGNED MEMBER PODS :" $matchingMemberCounter "$color_off"  "$RED"  "MISSING MEMBERS PODS :" $missingMemberCounter "$color_off"
  echo "$resultOutput"

}

kafka_member_pod_mismatch  -b "$1" -g "$2" -p "$3"

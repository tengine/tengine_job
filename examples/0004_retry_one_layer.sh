#!/bin/bash
case "$MM_ACTUAL_JOB_NAME_PATH" in
  "/jn0004/j1" ) 
    sleep $J1_SLEEP 
    if [ $J1_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j1'
    ;;
  "/jn0004/j2" ) 
    sleep $J2_SLEEP
    if [ $J2_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j2'
    ;;
  "/jn0004/j3" ) 
    sleep $J3_SLEEP 
    if [ $J3_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j3'
    ;;
  "/jn0004/j4" ) 
    sleep $J4_SLEEP 
    if [ $J4_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j4'
    ;;
  "/jn0004/finally/jn0004_f" ) 
    sleep $JN0004_F_SLEEP 
    if [ $JN0004_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn0004_f'
    ;;
esac


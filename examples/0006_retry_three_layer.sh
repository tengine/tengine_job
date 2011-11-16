#!/bin/bash
case "$MM_ACTUAL_JOB_NAME_PATH" in
  "/jn0006/jn1/jn11/j111" ) 
    sleep $J111_SLEEP 
    if [ $J111_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j111'
    ;;
  "/jn0006/jn1/jn11/j112" ) 
    sleep $J112_SLEEP 
    if [ $J112_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j112'
    ;;
  "/jn0006/jn1/jn11/finally/jn11_f" ) 
    sleep $JN11_F_SLEEP 
    if [ $JN11_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn11_f'
    ;;
  "/jn0006/jn1/j12" ) 
    sleep $J12_SLEEP 
    if [ $JN12_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j12'
    ;;
  "/jn0006/jn1/finally/jn1_f" ) 
    sleep $JN1_F_SLEEP 
    if [ $JN1_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn1_f'
    ;;
  "/jn0006/jn2/j21" ) 
    sleep $J21_SLEEP 
    if [ $JN21_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j21'
    ;;
  "/jn0006/jn2/jn22/j221" ) 
    sleep $J221_SLEEP 
    if [ $J221_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j221'
    ;;
  "/jn0006/jn2/jn22/j222" ) 
    sleep $J222_SLEEP 
    if [ $J222_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'j222'
    ;;
  "/jn0006/jn2/jn22/finally/jn22_f" ) 
    sleep $JN22_F_SLEEP 
    if [ $JN22_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn22_f'
    ;;

  "/jn0006/jn2/finally/jn2_f" ) 
    sleep $JN2_F_SLEEP 
    if [ $JN2_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn2_f'
    ;;
  "/jn0006/finally/finally/jn_f" ) 
    sleep $JN_F_SLEEP 
    if [ $JN_F_FAIL = "true" ] ; then
      exit 1
    fi
    echo 'jn_f'
    ;;
esac


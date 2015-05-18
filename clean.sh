#! /bin/sh

case $ACTION in
    "")
        ;;

    "clean")
        rm -fr $BUILD_DIR/*
        ;;
esac

exit 0

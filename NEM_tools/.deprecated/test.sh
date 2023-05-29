#!/usr/bin/bash


echo $@
tmp=`getopt -o ab:c:: "$@"`
echo $tmp
set -- $(getopt -o ab:c:: "$@")

echo $@

while [ -n "$1" ]
do
	case "$1" in 
		-a)
			defa="a is defined"
			shift ;;
		-b)
			defb=$2
			shift 2;;
		-c)
			case "$2" in 
				"")
					defc="c is empty"
					shift 2;;
				*)
					defc="c is defined $2"
					shift 2;;
			esac ;;
		--)
			shift 
			break
			;;
		*)
			echo "no such para"
			exit 1
			;;
	esac
done

echo $defa
echo $defb
echo $defc



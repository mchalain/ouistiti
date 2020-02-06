#!/bin/sh

TESTDIR=$(dirname $0)/
SRCDIR=src/
PWD=$(pwd)

CONTINUE=0
GCOV=0
ALL=0
while [ -n "$1" ]; do
case $1 in
	-D)
		DEBUG=1
		;;
	-C)
		CONTINUE=1
		;;
	-GCOV)
		GCOV=1
		;;
	-I)
		INFO=1
		;;
	-A)
		ALL=1
		TESTS=$(find $TESTDIR -maxdepth 1 -name test*[0-9] | sort)
		;;
	-N)
		NOERROR=1
		;;
	-h)
		printf "$0 <-I> <-D> <-C> <-GCOV> test/test[09]*\n"
		printf "\t-I    display information about test and the response\n"
		printf "\t-C    leave ouistiti running for the next test\n"
		printf "\t-GCOV run lcov to display the code coverage\n"
		exit 1
		;;
	*)
		TESTS=$1
		;;
esac
shift
done

echo $TESTS

TMPRESPONSE=/tmp/ouistiti.test

AWK=awk
SED=sed
WC=wc
CURL=curl
USER=$(ls -l $0 | ${AWK} '{print $3}')
TESTCLIENT="./host/utils/testclient -p 8080"
LD_LIBRARY_PATH=${SRCDIR}:$TESTDIR../libhttpserver/src/:$TESTDIR../libhttpserver/src/httpserver/

if [ -z "$INFO" ]; then
CURLOUT="-o /dev/null"
fi

TESTERROR=""
for TEST in ${TESTS}
do

	unset CMDREQUEST
	unset FILEDATA
	unset PREPARE
	unset CURLPARAM
	unset TESTREQUEST
	unset TESTCODE
	unset TESTHEADERLEN
	unset TESTCONTENTLEN
	TESTRESPONSE=$(basename ${TEST})_rs.txt
	. $TEST

	echo
	echo "******************************"
	echo $TEST
	echo $DESC


	if [ -n "$FILEDATA" ]; then
		cp ${TESTDIR}htdocs/${FILE}.in ${TESTDIR}htdocs/${FILE}
		${SED} -i "s/\%FILEDATA\%/$(echo $FILEDATA | ${SED} 's/\//\\\//g')/g" ${TESTDIR}htdocs/${FILE}
		TESTCONTENTLEN=$(cat ${TESTDIR}htdocs/${FILE} | ${WC} -c)
	fi

	cp ${TESTDIR}conf/${CONFIG}.in ${TESTDIR}conf/${CONFIG}
	${SED} -i "s/\%PWD\%/$(echo $PWD | ${SED} 's/\//\\\//g')/g" ${TESTDIR}conf/${CONFIG}
	${SED} -i "s/\%USER\%/$USER/g" ${TESTDIR}conf/${CONFIG}

	if [ -n "$PREPARE_ASYNC" ]; then
		$PREPARE_ASYNC &
		sleep 1
	fi

	if [ -n "$PREPARE" ]; then
		$PREPARE
	fi

	TARGET="ouistiti -s 1 -f ${TESTDIR}conf/${CONFIG}"

	if [ -n "$INFO" ]; then
		echo ${SRCDIR}${TARGET} -f ${TESTDIR}conf/${CONFIG}
	fi

	if [ $CONTINUE -eq 0 -o ! -x ${TESTDIR}run.pid ]; then
		if [ -z $DEBUG ]; then
			${SRCDIR}${TARGET} &
		fi
		PID=$!
		echo "${TARGET} started with pid ${PID}"
		echo ${PID} > ${TESTDIR}run.pid
		sleep 1
	fi

	if [ -n "$INFO" ]; then
		echo "******************************"
		cat ${TESTDIR}conf/${CONFIG}
	fi
	echo "******************************"
	if [ -n "$CURLPARAM" ]; then
		$CURL $CURLOUT -f -s -S $CURLPARAM > $TMPRESPONSE
	fi
	if [ -n "$TESTREQUEST" ]; then
		if [ -n "$INFO" ]; then
			cat ${TESTDIR}$TESTREQUEST
			echo "******************************"
			echo
		fi
		cat ${TESTDIR}$TESTREQUEST | $TESTCLIENT > $TMPRESPONSE
	fi
	if [ -n "$CMDREQUEST" ]; then
		if [ -n "$INFO" ]; then
			$CMDREQUEST
			echo "******************************"
			echo
		fi
		$CMDREQUEST | $TESTCLIENT > $TMPRESPONSE
	fi
	ERR=0
	if [ -n "$INFO" ]; then
		cat $TMPRESPONSE
		echo "******************************"
		echo $TEST
		echo $DESC
		rescode=$TESTCODE
		resheaderlen=$TESTHEADERLEN
		rescontentlen=$TESTCONTENTLEN
	else
		if [ -e ${TMPRESPONSE} ]; then
			diff ${TMPRESPONSE} ${TESTDIR}${TESTRESPONSE} | grep '^>'
			if [ ! $? -eq 1 ]; then
				ERR=4
			fi
		fi
		rescode=$(cat $TMPRESPONSE | ${AWK} '/^HTTP\/1\.1 .* .*/{print $2}' )
		resheaderlen=$TESTHEADERLEN
		rescontentlen=$TESTCONTENTLEN
		#resheaderlen=$(echo $result | ${AWK} -F= 't$0 == t {print $0}' | wc -c)
		#rescontentlen=$(echo $result | ${AWK} -F= 't$0 != t {print $0}' | wc -c)
	fi
	if [ -n "$TESTCODE"  ]; then
		echo $rescode | grep $TESTCODE > /dev/null
		if [ $? -eq 1 ]; then
			echo "result code error $rescode instead $TESTCODE"
			ERR=1
		fi
	fi
	if [ -n "$TESTHEADERLEN" -a x$resheaderlen != x$TESTHEADERLEN ]; then
		echo "header error received $resheaderlen instead $TESTHEADERLEN"
		ERR=2
	fi
	if [ -n "$TESTCONTENTLEN" -a x$rescontentlen != x$TESTCONTENTLEN ]; then
		echo "content error received $rescontentlen instead $TESTCONTENTLEN"
		ERR=3
	fi
	if [ ! $ERR -eq 0 ]; then
		echo "$TEST quits on error"
		if [ -n "$NOERROR" ]; then
			TESTERROR=${TESTERROR} $TEST
		else
			kill -9 $PID 2> /dev/null
			exit $ERR
		fi
	else
		echo "$TEST completed"
		echo "status        : $TESTCODE"
		if [ x"$TESTHEADERLEN" != x ]; then
			echo "header  length: $TESTHEADERLEN"
		fi
		if [ x"$TESTCONTENTLEN" != x ]; then
			echo "content length: $TESTCONTENTLEN"
		fi
	fi
	if [ $CONTINUE -eq 0 ]; then
		PID=$(cat ${TESTDIR}run.pid)
		rm ${TESTDIR}run.pid
		killall -9 $(echo $TARGET | ${AWK} '{print $1}')
		sleep 1
		#kill -9 $PID 2> /dev/null
	fi
done
echo $TESTERROR

if [ ${ALL} -eq 1 ]; then
	./src/ouistiti -h
	./src/ouistiti -V
fi
if [ ${GCOV} -eq 1 ]; then
	make DEBUG=y gcov
	lcov --directory . -c -o rapport.info
	genhtml -o ./rapport -t "couverture de code des tests" rapport.info
	firefox ./rapport/index.html
fi

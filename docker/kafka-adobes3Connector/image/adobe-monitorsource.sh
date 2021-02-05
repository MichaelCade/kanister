#!/bin/sh
echo "===========================Monitoring started==================================="
sleep 60
export elapsedtime="$(ps -e -o "pid,etimes,command" |awk -v processid=$pid '{if($1==processid) print $2}')"
if [ -z "$elapsedtime" ]
then
    echo "================Connector failed======================"
    curl -X DELETE http://localhost:8083/connectors/$connectorName
    echo "================Connector Deleted======================"
    exit 1
fi
for i in $(echo $topicDetail | sed "s/,/ /g")
do
    
    export topic="$(echo $i | awk -F ":" '{print $1}')"
    export finalMessageCount="$(echo $i | awk -F ":" '{print $2}')"
    if echo ",$topicList," | grep -q ",$topic,"
    then
        
        echo "======================Start Restore process for topic $topic with messagecount = $finalMessageCount ============================="
        export startOffset="$(/bin/kafka-run-class kafka.tools.GetOffsetShell --broker-list "$bootstrapServer" --topic "$topic" --time -1 | grep -e ':[[:digit:]]*:' | awk -F  ":" '{sum += $3} END {print sum}')"
        export endOffset="$(/bin/kafka-run-class kafka.tools.GetOffsetShell --broker-list "$bootstrapServer" --topic "$topic" --time -2 | grep -e ':[[:digit:]]*:' | awk -F  ":" '{sum += $3} END {print sum}')"
        export currentMessageCount=$((startOffset - endOffset))
        echo "======================Start offset = $startOffset , endoffset = $endOffset , message count = $currentMessageCount ============================="
        
        until [ "$currentMessageCount" = "$finalMessageCount" ]
        do
        echo "======================Restore in process for $topic ============================="
        startOffset="$(/bin/kafka-run-class kafka.tools.GetOffsetShell --broker-list "$bootstrapServer" --topic "$topic" --time -1 | grep -e ':[[:digit:]]*:' | awk -F  ":" '{sum += $3} END {print sum}')"
        endOffset="$(/bin/kafka-run-class kafka.tools.GetOffsetShell --broker-list "$bootstrapServer" --topic "$topic" --time -2 | grep -e ':[[:digit:]]*:' | awk -F  ":" '{sum += $3} END {print sum}')"
        currentMessageCount=$((startOffset - endOffset))
        echo "======================Start offset = $startOffset , endoffset = $endOffset , message count = $currentMessageCount ============================="
        sleep 3
        done

        echo "=======================restore complete for $topic =================================="
    else
        echo "=================$topic not listed in the $topicList, skipping restore====================="
    fi
done

echo "=========================== All topic restored as per backup details ==================================="
curl -X DELETE http://localhost:8083/connectors/$connectorName
echo "================Connector Deleted======================"
kill -INT $pid
exit 0

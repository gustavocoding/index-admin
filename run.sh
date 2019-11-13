set -e

function start()  {
  nohup ~/.indexPerf/$1/bin/server.sh -Dinfinispan.node.name=$1 $3 > server-$1.log &
  while ! curl -s -o /dev/null -w "%{http_code}" http://localhost:$2/rest/v2/server | grep 200
  do
   echo "waiting for server to start"
   sleep 1;
  done
}

SERVER_HOME="$1"
JFR=${2:-false}
if [ $# -eq 0 ]
  then
    echo "Usage: ./prepare.sh <VERSION>"
    exit 1
fi

if [[ $JFR = "false" ]]
then
  export JAVA_OPTS="-Xms6g -Xmx6g -Djava.net.preferIPv4Stack=true"	  
else 
  export JAVA_OPTS="-Xms6g -Xmx6g -Djava.net.preferIPv4Stack=true -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints -XX:+UnlockCommercialFeatures -XX:+FlightRecorder -XX:FlightRecorderOptions=defaultrecording=true,disk=true,settings=profile,repository=/tmp,maxage=2h,dumponexit=true,dumponexitpath=dumponexit.jfr,loglevel=info"
fi

export JAVA_OPTS="-Xmx10000m -Djava.net.preferIPv4Stack=true -Djava.awt.headless=true"


rm -Rf ~/.indexPerf
mkdir ~/.indexPerf
cp -R $SERVER_HOME ~/.indexPerf/node1
cp -R $SERVER_HOME ~/.indexPerf/node2

start node1 11222
start node2 12222 '-Dinfinispan.socket.binding.port-offset=1000 -Dinfinispan.server.data.path=/tmp'

curl -XDELETE http://127.0.0.1:11222/rest/v2/caches/___protobuf_metadata/schema.proto
curl -X POST --data-binary @./schema.proto http://127.0.0.1:11222/rest/v2/caches/___protobuf_metadata/schema.proto

curl -XDELETE http://127.0.0.1:11222/rest/v2/caches/indexed
#curl -v -XPOST -H "Content-Type: application/json" -d '{"distributed-cache":{"mode":"SYNC","statistics":true, "indexing":{"index":"LOCAL", "properties":{"default.indexmanager":"near-real-time","default.indexBase":"${infinispan.server.home.path}/${infinispan.node.name}"}}}}' http://127.0.0.1:11222/rest/v2/caches/indexed
curl -v -XPOST -H "Content-Type: application/json" -d '{"distributed-cache":{"mode":"SYNC","statistics":true, "indexing":{"index":"LOCAL", "auto-config": true,"properties":{"default.worker.execution":"async"}}}}' http://127.0.0.1:11222/rest/v2/caches/indexed

./load.sh --entries 100000 --write-batch 1000 --phrase-size 100

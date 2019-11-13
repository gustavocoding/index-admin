#!/bin/sh
export JAVA_OPTS=""
DIR="$( cd "$( dirname "$0" )" && pwd )"
CLASSPATH=`echo lib/*.jar|sed 's/ /:/g'`
exec scala -J-Xmx5g -classpath $CLASSPATH -savecompiled "$0" "$@"
!#

import org.infinispan.client.hotrod._
import org.infinispan.client.hotrod.configuration._
import org.infinispan.commons.marshall.UTF8StringMarshaller
import java.net._
import scala.collection.JavaConverters._
import scala.util.Random
import scala.io._
import org.infinispan.commons.dataconversion._

val usage = """

Usage: load.sh --entries num [--write-batch num] [--phrase-size num]

"""

if (args.length == 0) {
  println(usage)
  System.exit(1)
}

var entries = 0
var write_batch = 10000
var phrase_size = 10
var hotrodversion: String = _ 

args.sliding(2, 2).toList.collect {
  case Array("--hotrodversion", num: String) => hotrodversion = num 
  case Array("--entries", num: String) => entries = num.toInt
  case Array("--write-batch", num: String) => write_batch = num.toInt
  case Array("--phrase-size", num: String) => phrase_size = num.toInt
}

if(entries <= 0) {
   println("option 'entries' is required")
   println(usage)
   System.exit(1)
}

println(s"\nLoading $entries entries with write batch size of $write_batch and phrase size of $phrase_size\n")

val wordList = Source.fromFile("/usr/share/dict/words").getLines.foldLeft(Vector[String]())( (s, w) => s :+ w)

val sz = wordList.size

val rand = new Random()

def randInt = rand.nextInt(sz)

def randomWord = wordList(randInt)

def randomPhrase = (0 to phrase_size).map(i => randomWord).mkString(" ")

def entify(desc: String): String = s"""{"_type":"Entity","desc":"$desc","number":$randInt}"""

val clientBuilder = new ConfigurationBuilder

clientBuilder.addServer().host("localhost").port(11222)
clientBuilder.marshaller(new UTF8StringMarshaller())
if(hotrodversion != null) clientBuilder.protocolVersion(hotrodversion)
val rcm = new RemoteCacheManager(clientBuilder.build)
val cache = rcm.getCache[Int,String]("indexed")

val jsonCache: RemoteCache[Int, String] = cache.withDataFormat(DataFormat.builder().valueType(MediaType.APPLICATION_JSON).valueMarshaller(new UTF8StringMarshaller()).build())

cache.clear

(1 to entries)
     .view
     .map(_ -> entify(randomPhrase))
     .grouped(write_batch)
     .map(m => mapAsJavaMap(m.toMap))
     .foreach(m => jsonCache.putAll(m))

##################################################
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## HStream 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##################################################

FROM ubuntu:xenial


#-------------------------------------------------
#-- Tools
#-------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git  \
    netcat \
    software-properties-common \
    unzip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*



#-------------------------------------------------
#  JAVA 
#-------------------------------------------------

ENV JAVA_VERSION=8
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-oracle

RUN echo oracle-java${JAVA_VERSION}-installer shared/accepted-oracle-license-v1-1 select true \
  | /usr/bin/debconf-set-selections \
 && add-apt-repository -y ppa:webupd8team/java \
 && apt-get update && apt-get install -y --no-install-recommends oracle-java${JAVA_VERSION}-installer \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /var/cache/oracle-jdk${JAVA_VERSION}-installer
 

#-------------------------------------------------
#-- SBT
#-------------------------------------------------
ENV SBT_VERSION 1.0.1

RUN curl -sL -o sbt-$SBT_VERSION.deb https://dl.bintray.com/sbt/debian/sbt-$SBT_VERSION.deb \
 && dpkg -i sbt-$SBT_VERSION.deb \
 && rm sbt-$SBT_VERSION.deb \
 && apt-get update \
 && apt-get install sbt



#-------------------------------------------------
#  SPARK
#-------------------------------------------------

ENV SPARK_VERSION=2.2.0
    
ENV SPARK_PACKAGE=spark-${SPARK_VERSION}-bin-hadoop2.7 \
    SPARK_HOME=/usr/spark-${SPARK_VERSION}
    
ENV PATH=${PATH}:${SPARK_HOME}/bin

RUN curl -sL --retry 3 \
  "http://apache.rediris.es/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/${SPARK_PACKAGE} ${SPARK_HOME} \
 && chown -R root:root ${SPARK_HOME}


#-------------------------------------------------
#-- Ruby
#-------------------------------------------------

RUN apt-get update \
 && apt-get install -y --no-install-recommends ruby-full

#-------------------------------------------------
#-- DEMO dependencies
#-------------------------------------------------

RUN gem install bunny:2.9.2 influxdb:0.3.14

CMD /bin/bash

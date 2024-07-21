# Based on the work of:
# https://github.com/earthquakesan/hdfs-spark-hive-dev-setup

# Enda Farrell 2017
# Enda Farrell 2017
# Enda Farrell 2017
# Enda Farrell 2017
# Enda Farrell 2017


# Important: make sure ssh is running:
# eval `ssh-agent -s`


# Dont echo 'make' commands
.SILENT:


mkfile_path     :=  $(abspath $(lastword $(MAKEFILE_LIST)))
this_dir        :=  $(dir $(mkfile_path))

# Note:
# Install old version of Hive (ver 1.2) because 'PySpark' uses
# the 1.2 HIVE metastore by default. (Want Hive clients and
# 'Pyspark' to use the same metastore)

hadoop_bin      :=  hadoop-2.7.2
spark_bin       :=  spark-2.1.1-bin-hadoop2.7
hive_bin        :=  apache-hive-1.2.2-bin

hadoop_mirror   :=  http://www-us.apache.org/dist/hadoop/common/hadoop-2.7.2
spark_mirror    :=  http://mirror.vorboss.net/apache/spark/spark-2.1.1
hive_mirror     :=  http://mirror.ox.ac.uk/sites/rsync.apache.org/hive/hive-1.2.2/

hadoop_home     :=  $(addsuffix  tools/$(hadoop_bin), $(this_dir))
spark_home      :=  $(addsuffix  tools/$(spark_bin),  $(this_dir))
hive_home       :=  $(addsuffix  tools/$(hive_bin),   $(this_dir))

spark_local_ip  := 0.0.0.0
spark_master_ip := 0.0.0.0

SHELL           :=  /bin/bash
GREEN           :=  \033[0;32m
RED             :=  \033[0;31m
NO_COLOR        :=  \e[0m
JAVA_HOME       :=  /usr/lib/jvm/java-8-oracle


# --------------------------------------------------------------
# Define most important targets
# --------------------------------------------------------------

install:    create-ssh-id \
            get_ubuntu_packages \
            download \
            configure \
            start \
            configure_hive \
            activate \
            install_instructions

download:    get_hadoop \
             get_spark \
             get_hive \
             tidy_tarballs

configure:   configure_hadoop \
             configure_spark

start:       start_hadoop \
             start_spark

stop:        stop_hadoop \
             stop_spark




create-ssh-id:
    # $(shell eval "$(ssh-agent -s)")
    sudo apt-get install -y ssh

    if [ -f "$$HOME/.ssh/id_rsa" ]; then                   \
        printf '\nSSH identity exists already...\n';       \
    else                                                   \
        printf '\nCreating SSH identity: id_rsa...\n';     \
        ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa;          \
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys;   \
        chmod 0600                 ~/.ssh/authorized_keys; \
    fi

    printf "\nIf an error occurs, please execute: \n"
    printf "$(GREEN)eval \`ssh-agent -s\`$(NO_COLOR)\n"
    printf "and re-try this makefile...\n\n";
    ssh-add


get_ubuntu_packages:
    # first install the basics
    sudo apt-get install -y rsync
    sudo apt-get install -y ipython
    sudo apt-get install -y tmux

    # **Oracle JAVA**
    # (silent install)
    # sudo apt-get install -y python-software-properties debconf-utils
    sudo apt-get install -y python-software-properties
    sudo add-apt-repository -y ppa:webupd8team/java
    sudo apt-get update
    echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
    sudo apt-get install -y oracle-java8-installer




install_instructions:
    printf "\n$(GREEN)The basic cluster is now installed/setup."
    printf "\nThe easiest way to continue is to run a tmux script:\n"
    printf "\n\t./run-tmux-session.sh$(NO_COLOR)"
    printf "\n"



get_hadoop:
    $(eval tarball := $(hadoop_bin).tar.gz)
    mkdir -p $(this_dir)tools
    [ -f "$(tarball)" ] ||  wget $(hadoop_mirror)/$(tarball)
    cd $(this_dir)tools; tar -xvf ../$(tarball)


get_spark:
    $(eval tarball := $(spark_bin).tgz)
    mkdir -p $(this_dir)tools
    [ -f "$(tarball)" ] ||  wget $(spark_mirror)/$(tarball)
    cd $(this_dir)tools; tar -xvf ../$(tarball)


get_hive:
    $(eval tarball := $(hive_bin).tar.gz)
    mkdir -p $(this_dir)tools
    [ -f "$(tarball)" ] ||  wget $(hive_mirror)/$(tarball)
    cd $(this_dir)tools; tar -xvf ../$(tarball)


tidy_tarballs:
    # store downloaded tarballs into separate folder
    mkdir -p $(this_dir)tarballs
    mv --verbose  $(this_dir)*gz    $(this_dir)tarballs


configure_hadoop:
    # explicitly set 'JAVA_HOME'
    sed -i "s#.*export JAVA_HOME.*#export JAVA_HOME=${JAVA_HOME}#g" ${hadoop_home}/etc/hadoop/hadoop-env.sh

    # explicitly set 'HADOOP_CONF_DIR'
    sed -i "s#.*export HADOOP_CONF_DIR.*#export HADOOP_CONF_DIR=${hadoop_home}/etc/hadoop#" ${hadoop_home}/etc/hadoop/hadoop-env.sh

    # define 'fs.default.name' in core-site.xml
    sed -i '/<\/configuration>/i <property><name>fs.default.name</name><value>hdfs://localhost:9000</value></property>'            ${hadoop_home}/etc/hadoop/core-site.xml
    sed -i '/<\/configuration>/i <property><name>hadoop.tmp.dir</name><value>file://$(this_dir)data/hadoop-tmp</value></property>' ${hadoop_home}/etc/hadoop/core-site.xml

    # set 'dfs.replication' and 'dfs.namenode.name.dir'
    mkdir -p $(this_dir)data/hadoop
    sed -i '/<\/configuration>/i <property><name>dfs.replication</name><value>1</value></property>'                                   ${hadoop_home}/etc/hadoop/hdfs-site.xml
    sed -i '/<\/configuration>/i <property><name>dfs.namenode.name.dir</name><value>file://$(this_dir)data/hadoop</value></property>' ${hadoop_home}/etc/hadoop/hdfs-site.xml
    ${hadoop_home}/bin/hdfs namenode -format



configure_spark:
    $(eval spark_classpath := $(shell ${hadoop_home}/bin/hadoop classpath))

    # create folder for spark RDD's
    mkdir -p $(this_dir)data/spark-rdd

    # Change logging level from 'INFO' to 'WARN'
    cp ${spark_home}/conf/log4j.properties.template                                   ${spark_home}/conf/log4j.properties
    sed -i "s#log4j.rootCategory=INFO, console#log4j.rootCategory=WARN, console#g" ${spark_home}/conf/log4j.properties

    # Set Spark environment variables
    echo 'export SPARK_LOCAL_IP=$(spark_local_ip)'            >> ${spark_home}/conf/spark-env.sh
    echo 'export HADOOP_CONF_DIR="${hadoop_home}/etc/hadoop"' >> ${spark_home}/conf/spark-env.sh
    echo 'export SPARK_DIST_CLASSPATH="$(spark_classpath)"'   >> ${spark_home}/conf/spark-env.sh
    echo 'export SPARK_MASTER_IP=$(spark_master_ip)'          >> ${spark_home}/conf/spark-env.sh
    echo 'export SPARK_LOCAL_DIRS=$(this_dir)data/spark-rdd'  >> ${spark_home}/conf/spark-env.sh


configure_hive:
    # Metastore JDBC connection: Use an embedded *Derby* Metastore

    echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'                       > ${hive_home}/conf/hive-site.xml
    echo '<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>'                 >> ${hive_home}/conf/hive-site.xml
    echo '<configuration>'                                                             >> ${hive_home}/conf/hive-site.xml
    echo '<property>'                                                                  >> ${hive_home}/conf/hive-site.xml
    echo '<name>javax.jdo.option.ConnectionURL</name>'                                 >> ${hive_home}/conf/hive-site.xml
    echo '<value>jdbc:derby:;databaseName=$(this_dir)metastore_db;create=true</value>' >> ${hive_home}/conf/hive-site.xml
    echo '</property>'                                                                 >> ${hive_home}/conf/hive-site.xml
    echo '<property>'                                                                  >> ${hive_home}/conf/hive-site.xml
    echo '<name>hive.metastore.schema.verification</name>'                             >> ${hive_home}/conf/hive-site.xml
    echo '<value>true</value>'                                                         >> ${hive_home}/conf/hive-site.xml
    echo '</property>'                                                                 >> ${hive_home}/conf/hive-site.xml
    echo '</configuration>'                                                            >> ${hive_home}/conf/hive-site.xml

    # export environment variables
    echo 'export HADOOP_HOME="${hadoop_home}"'       > ${hive_home}/conf/hive-env.sh
    echo 'export HIVE_HOME="${hive_home}"'          >> ${hive_home}/conf/hive-env.sh

    # copy 'hive-site.xml' to Spark
    # (necessary to run Spark apps with configured metastore)
    cp ${hive_home}/conf/hive-site.xml  ${spark_home}/conf/

    # Initialise the Metastore schema
    printf "\nCreating MetaStore schema... \n"
    ${hive_home}/bin/schematool -initSchema   -dbType derby

    # Create HDFS folders
    printf "\nCreating HDFS folder: 'tmp'...\n"
    ${hadoop_home}/bin/hadoop  fs  -mkdir  -p   /tmp
    ${hadoop_home}/bin/hadoop  fs  -chmod  g+w  /tmp
    ${hadoop_home}/bin/hadoop  fs  -ls          /

    printf "\nCreating HDFS folder: 'hive warehouse'...\n"
    ${hadoop_home}/bin/hadoop  fs  -mkdir  -p   /user/hive/warehouse
    ${hadoop_home}/bin/hadoop  fs  -chmod  g+w  /user/hive/warehouse
    ${hadoop_home}/bin/hadoop  fs  -ls          /user/hive


start_hadoop:
    ${hadoop_home}/sbin/start-dfs.sh

start_spark:
    ${spark_home}/sbin/start-all.sh

start_hive_server:
    # This isnt needed as I'm using an embedded Derby Metastore
    ${hive_home}/bin/hiveserver2 --hiveconf hive.server2.enable.doAs=false


hive_cli:
    # Command-line client for HIVE. (deprecated)
    ${hive_home}/bin/hive

beeline_cli:
    # Command-line client for HIVE.
    # Start beeline in "embedded mode" (uses Derby metastore?).
    # This will execute queries against the embedded
    # HiveServer2 instance and Derby metastore.

    $(eval embedded_db := 'jdbc:hive2://')
    ${hive_home}/bin/beeline -u $(embedded_db) --color=true --maxWidth=250

    # Extra options:
    #     --outputformat   = tsv
    #     --maxWidth       = 1000
    #     --showDbInPrompt = true
    #     --autoCommit     = true


stop_hadoop:
    ${hadoop_home}/sbin/stop-dfs.sh

stop_spark:
    ${spark_home}/sbin/stop-all.sh


#-------------------
# Interactive shells
#-------------------

pyspark:
    # export LD_LIBRARY_PATH=${hadoop_home}/lib/native/:$LD_LIBRARY_PATH
    PYSPARK_DRIVER_PYTHON=ipython ${spark_home}/bin/pyspark


spark_shell:
    ${spark_home}/bin/spark-shell


#----------------------------------
# Inject 'bin' folders into "$PATH"
#----------------------------------

activate:
    $(eval script_name := inject_paths.sh)

    printf "\nCreating Bash script... \n\t'$(script_name)'\n"
    printf "\nThis Script will export the 'bin' folders of:\n"
    printf "\tHADDOOP: $(hadoop_home)\n"
    printf "\tHIVE:    $(hive_home)\n"
    printf "\tSPARK:   $(spark_home)\n"
    printf "\n"

    echo 'export PATH=$$PATH:$(hadoop_home)/bin'  > $(script_name)
    echo 'export PATH=$$PATH:$(hive_home)/bin'   >> $(script_name)
    echo 'export PATH=$$PATH:$(spark_home)/bin'  >> $(script_name)
    chmod a+x $(script_name)

    printf "To activate new paths, type:\n"
    printf "\t'source $(script_name)'"
    printf "\n"

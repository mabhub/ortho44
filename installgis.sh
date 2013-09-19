#
# Installation of a WMS structure to serve very large ECW images layer
#
# at first we tried mapnik2:
#   - OGCserver -> too slow
#   - paleoserver -> unusable
#
# Then we tried at first we tried mapserver:
#   - A bit better, but do not scale with large extents
#

#
# git clone https://gist.github.com/6019523.git
# ./installgis.sh

cd $(dirname $0)
wget="wget -c"

export R=/var/makina
export PREFIX=${PREFIX:-$R/circus}
export ROOT=${ROOT:-$PREFIX/apps}
export PATH="$ROOT/bin:$PATH"
if [[ -e $PREFIX/bin/activate ]];then
    . $PREFIX/bin/activate
else
    apt-get install -y python-virtualenv
    virtualenv $PREFIX
    . $PREFIX/bin/activate
fi

export TMP=$PWD
export CFLAGS="-I/usr/include/crunch -I$ROOT/include"
export LDFLAGS="-Wl,-rpath -Wl,$ROOT/lib -L$ROOT/lib -Wl,-rpath -Wl,/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server"
export CPPFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS"
export LD_LIBRARY_PATH=$PREFIX/apps/lib/
export WA=${WA:-/var/lib/tomcat7/webapps}
export DATA=${DATA:-/var/makina/data}
export LAYERS=$DATA/layers
export DATAS=$(ls -1rdt $DATA/*|grep -v ".sav"|grep -v $LAYERS|head -n1)
export GEO_LAYER=orthophotos44
export GEO_LAYER_DIR=$WA/geoserver/data/$GEO_LAYER

apt_setup() {
    apt-get update
    add-apt-repository ppa:ubuntugis/ubuntugis-unstable && apt-get update
    add-apt-repository ppa:marlam/gta && apt-get update
}

libecw() {
    if [[ ! -d libecw ]];then git clone https://github.com/makinacorpus/libecw.git;fi &&\
    cd libecw &&\
        ./configure CFLAGS="-O0" CXXFLAGS="-O0" --enable-shared --enable-static --prefix=$ROOT && make && make install
}

openjpeg() {
    $wget https://openjpeg.googlecode.com/files/openjpeg-2.0.0.tar.gz &&\
    tar xzvf openjpeg-2.0.0.tar.gz &&\
    cd openjpeg-2.0.0 &&\
    cmake -DCMAKE_INSTALL_PREFIX=$ROOT . && make && make install
}


libkml() {
    if [[ ! -d libkml ]];then git clone https://github.com/makinacorpus/libkml.git;fi &&\
    cd libkml &&\
    ./autogen.sh && ./configure --enable-shared --enable-static --prefix=$ROOT && make clean && make && make install
}

base() {
    cook apt_setup
    apt-get install multiwatch libgd2-xpm-dev libfcgi-dev libpoppler-dev libpodofo-dev libopenjpeg-dev libwebp-dev libmysqlclient-dev libmysqld-dev libfreexl-dev libarmadillo-dev libkml-dev liblzma-dev libarchive-dev liburiparser-dev subversion build-essential m4 libtool pkg-config autoconf gettext bzip2 groff man-db automake libsigc++-2.0-dev tcl8.5 git opencl-headers libdap-dev librasqal3-dev rasqal-utils cmake liblcms2-dev liblcms1-dev libepsilon-dev libogdi3.2-dev ogdi-bin libcfitsio3-dev libccfits-dev libcrunch-dev libgta-dev apache2-prefork-dev libaprutil1-dev libapr1-dev libfcgi-dev apt-build openjdk-7-jdk swig openjdk-6-jdk grass-dev grass grass-core grass-gui \
        
    cook libecw|| exit -1 
    cook libkml|| exit -1 
    cook openjpeg|| exit -1 
    cook install_jdk|| exit -1 
}

install_jdk() {
    sudo add-apt-repository ppa:webupd8team/java
    sudo apt-get update
    sudo apt-get install oracle-java7-installer -y
}

gdal() {
    apt-get install -y ant maven2 &&\
    $wget http://download.osgeo.org/gdal/1.10.0/gdal-1.10.0.tar.gz &&\
    tar xzvf gdal-1.10.0.tar.gz &&\
    cd gdal-1.10.0 &&\
    sed -ire "s:^JAVA_HOME.*:JAVA_HOME = /usr/lib/jvm/java-7-openjdk-amd64:g" swig/java/java.opt &&\
    # cd frmts/msg && unzip PublicDecompWTMakefiles.zip && cd ../..
    ./configure --prefix=$ROOT --with-gif=/usr--with-hdf4=/usr --with-hdf5=/usr --with-jasper=/usr --with-openjpeg=$ROOT --with-ecw=$ROOT --with-expat=/usr --with-curl=/usr --with-odbc --with-spatialite=/usr --with-sqlite3=/usr --with-webp=/usr --with-poppler=/usr --with-perl=/usr --with-geos=/usr --with-mysql=/usr/bin/mysql_config --with-armadillo=/usr --with-libkml=$ROOT --with-dods_root=/usr --with-epsilon=/usr --with-java=yes --with-mdb --with-dds=/usr --with-gta=/usr --with-liblzma=yes --with-libtiff=internal --with-geotiff=internal --with-jpeg=internal --with-jpeg12 --without-ogdi --with-python=$PREFIX/bin/python &&\
        make && make install &&\
        pushd swig/python/ && make && make install && popd &&\
        pushd swig/java/ && make &&\
        cp -v *so $ROOT/lib && cp gdal.jar $ROOT && popd

}

mapnik2() {
    # important to note here
    apt-get install -y mapnik-utils libmapnik-dev python-gdal libdap-bin
        add-apt-repository ppa:mapnik/v2.2.0 && apt-get update
    apt-build source libmapnik
    cp -rf /var/cache/apt-build/build/mapnik-2.2.0/ $TOP
    cd mapnik-2.2.0
    ./configure PREFIX="$ROOT"  CUSTOM_CXXFLAGS="$CFLAGS" CUSTOM_LDFLAGS="$LDFLAGS" && make && make install
    cd mapserver-6.2.1
    ./configure --enable-static --enable-shared --with-fribidi-config=/usr/lib/pkgconfig/fribidi.pc --with-freetype--with-png --with-gif --with-libiconv --with-gd --with-proj --with-geos -with-postgis --with-wfs --with-wcs --with-wmsclient --with-wfsclient --with-sos --with-kml --with-xslt --with-cairo --with-libsvg-cairo --with-fastcgi --with-exslt --with-xml-mapfile --with-threads --enable-proj-fastpath --prefix="$ROOT" --with-gdal="$ROOT/bin/gdal-config" --with-ogr="$ROOT/bin/gdal-config" && make && make install
}

mapserver() {
    apt-get install -y mapserver cgi-mapserver mapserver-bin python-mapscript daemontools-run daemontools spawn-fcgi libmapserver-dev
    $wget http://download.osgeo.org/mapserver/mapserver-6.2.1.tar.gz
    tar xzvf mapserver-6.2.1.tar.gz
    vim /etc/nginx/sites-enabled/wms
    vim $PREFIX/map.map
    chmod +x $PREFIX/mapserv-init.sh
    cp mapserv-init.sh $PREFIX
    sed -ire "s:^PREFIX=.*:PREFIX=\"$PREFIX\":g" $PREFIX/mapserv-init.sh
    ln -fs $PREFIX/mapserv-init.sh /etc/init.d/mapserv-init.sh
    /etc/init.d/nginx stop
    /etc/init.d/nginx start
    /etc/init.d/mapserv-init.sh stop
    /etc/init.d/mapserv-init.sh start
    update-rc.d -f mapserv-init.sh defaults 99
    # http://trac.osgeo.org/gdal/wiki/CatalogueForQIS
    $PREFIX/compute-stats.sh
    $PREFIX/apps/bin/gdaltindex --config  GDAL_CACHEMAX 3000000000 $ROOT/map.shp /var/makina/data/Ortho_2012_CG44/*ecw

}

geoserver() {
    apt-get install -y tomcat7
    cd $TMP
    GEOSERVER_VER=2.3.5
    FIC=geoserver-$GEOSERVER_VER-war.zip
    FPFIC=$PWD/$FIC
    if [[ ! -f $FIC ]];then
        $wget http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VER/$FIC
    fi
    GD_FIC=geoserver-$GEOSERVER_VER-gdal-plugin.zip
    GD_FPFIC=$PWD/$GD_FIC
    if [[ ! -f $GD_FIC ]];then
        $wget http://downloads.sourceforge.net/project/geoserver/GeoServer%20Extensions/$GEOSERVER_VER/$GD_FIC
    fi
    if [[ ! -e $WA/geoserver/WEB-INF/lib/gdal-$GEOSERVER_VER.jar ]];then
        unzip -od gdalp_tmp $GD_FPFIC && cp -vf gdalp_tmp/*.jar $GD_$WA/geoserver/WEB-INF/lib && rm -rf gdalp_tmp
    fi
    GD_FIC=geoserver-$GEOSERVER_VER-pyramid-plugin.zip
    GD_FPFIC=$PWD/$GD_FIC
    if [[ ! -f $GD_FIC ]];then
        $wget http://downloads.sourceforge.net/project/geoserver/GeoServer%20Extensions/$GEOSERVER_VER/$GD_FIC
    fi
    if [[ ! -e $WA/geoserver/WEB-INF/lib/gt-imagepyramid-9.5.jar ]];then
        unzip -od gdalp_tmp $GD_FPFIC && cp -vf gdalp_tmp/*.jar $GD_$WA/geoserver/WEB-INF/lib && rm -rf gdalp_tmp
    fi
    if [[ ! -e $WA/geoserver/WEB-INF/lib/gdal-$GEOSERVER_VER.jar ]];then
        unzip -od gdalp_tmp $GD_FPFIC && cp -vf gdalp_tmp/*.jar $GD_$WA/geoserver/WEB-INF/lib && rm -rf gdalp_tmp
    fi
    if [[ ! -e $WA/geoserver/WEB-INF/lib ]];then
        unzip -od $WA $FPFIC geoserver.war
        /etc/init.d/tomcat7 restart
        sleep 4
    fi
    cp -v $ROOT/gdal.jar $WA/geoserver/WEB-INF/lib
    sed -re "s:(\s*LANG=.*)([\\])$:\1export LD_LIBRARY_PATH=\\\"$PREFIX/apps/lib\:\$LD_LIBRARY_PATH\\\" \2:g" -i /etc/init.d/tomcat7
    rsync -av  /var/makina/circus/geoserver/ $WA/geoserver/data/orthophotos44/
    chown -Rf tomcat7:root $WA/geoserver
    /etc/init.d/tomcat7 restart
    # in dev, prevent cookfile to be done
}

cook() {
    cd $TMP
    if [[ ! -f "$TMP/.cook_$1" ]];then
        $1|| exit -1 
        if [[ $? == 0 ]];then
            echo  "Done $1"
            touch "$TMP/.cook_$1"
        fi
    else
        echo "Already done $1"
    fi
}

assemble_map() {
    # geoserver dont want big filenames
    if [[ ! -d $GEO_LAYER_DIR ]];then
        mkdir $GEO_LAYER_DIR
    fi
    cd $GEO_LAYER_DIR || exit -1
    rm *ecw;
    j=0;
    for i in $DATAS/*ecw;do
        j=$((j+1));
        ln -sfv $i $j.ecw;
    done
}

#echo "127.0.0.1 services.makina-corpus.net">>/etc/hsots

assemble_shapefile() {
    pushd $WA/geoserver/data/orthophotos44/
    rm -rf rm orthophotos44.shx orthophotos44.shp orthophotos44.prj orthophotos44.dbf
    time $PREFIX/apps/bin/gdaltindex --config GDAL_CACHEMAX 3000000002 orthophotos44.shp *ecw
    popd
}
# for geoserver wmss
# images must have less thatn 8 chars, with a preference for digit finelames
# they must be local to the data dir, make syminks
# your shapefile must reference them with relative paths !
# in the data dir, you must have only and only the shp(4 files), the properties files and the images files, NOTHING ELSE
buildlayers() {
    if [[ ! -e $LAYERS ]];then
        mkdir $LAYERS
    fi
    #for i in $DATAS/*.ecw;do
    #    gdalinfo $i
    #    exit
    #    zooms=$(gdalinfo $i|grep Overviews|head -n 1|awk -F'Overviews:' '{print $2}'|sed "s/,//g")
    #    for z in $zooms;do
    #        zd="$LAYERS/$z"
    #        if [[ ! -d $zd ]];then
    #            mkdir $zd
    #        fi
    #        echo ln -sfv $i "$zd/$(basename $i)"
    #    done
    #    exit -1
    #done
    cook assemble_shapefile
    ls nonexisting

}


install_atlaslayer() {
sudo apt-get install -y lsb-release ; 
sudo wget http://www.geopublishing.org/sources.list.d/$(lsb_release -cs).list -O-|grep -v webupd8team>/etc/apt/sources.list.d/geopublishing.list

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7450D04751B576FD
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B725097B3ACC3965
sudo apt-get -y update ; sudo apt-get -y install  atlasstyler geopublishing-doc

}
current() {
    for i in base gdal;do
        cook $i|| exit -1 
    done
}


#geoserver
current
install_atlaslayer

# vim: set ft=sh:

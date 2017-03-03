#! /bin/bash
# Check and set environment before every scripts. Golbal vars should be not affect others.

PWD=$(pwd)
SOURCE="${BASH_SOURCE[0]}"
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR=$DIR/../
INIT_ENV_DIR=$DIR

source $DIR/archived/download.sh

# Avoid $DIR overwritten.
DIR=$INIT_ENV_DIR
echo "cd $DIR"
cd $DIR

source $DIR/util/util.sh

setupBasicEnv
os=$( osinfo )

if [[ $os == 'Darwin' ]]; then
	MAKE_CORE_NUM=4
	echo "For Darwin/MacOSX, assume CPU Core:$MAKE_CORE_NUM"
else
	lastCPUID=$(cat /proc/cpuinfo | grep processor | tail -n 1 | awk '{print $3}')
	MAKE_CORE_NUM=$(($lastCPUID + 1))
	echo "CPU Core:$MAKE_CORE_NUM"
fi

USER_INSTALL="$HOME/install"
USER_ARCHIVED="$HOME/archived"
mkdir -p $USER_INSTALL
mkdir -p $USER_INSTALL/include
mkdir -p $USER_INSTALL/lib
mkdir -p $USER_ARCHIVED
rm -rf $USER_ARCHIVED/*

echoGreen "-------- Checking environment. --------"
# Check sudo privilege.
ret=$( sudo -n echo a 2>&1 )
sudoAllowed="0"
if [[ $ret == "a" ]] && [[ $os != "Darwin" ]]; then
	echoBlue "User has sudo privilege without password."
	sudoAllowed="1"
elif [[ $os == 'Darwin' ]]; then
	:
else
	echoRed "WARN: User has no sudo privilege without password. Change /etc/sudoers first."
fi

echoGreen "-------- Copying util configurations -------"
mkdir -p $HOME/.vim/backupfiles
mkdir -p $HOME/.vim/swapfiles
mkdir -p $HOME/bin
mkdir -p $HOME/conf
cp -v $DIR/conf/home/.bash* $HOME/
cp -v $DIR/conf/home/.*rc $HOME/
cp -v $DIR/conf/home/.tmux*.conf $HOME/
cp -v $DIR/conf/home/tmux_dev.sh $HOME/
cp -v $DIR/conf/home/.profile $HOME/
# Do not copy other files for safety.

echoGreen "-------- Refresh bash enviroment -------"
source $HOME/.bash_profile
source $HOME/.bashrc

if [[ $sudoAllowed == "1" ]] || [[ $os == "Darwin" ]]; then
	echoGreen "-------- Installing system tools --------"
	if [[ $os == CentOS* ]]; then
		if [ $(yum grouplist groupinfo 'Development tools' | grep "Installed" | wc -l) == "0" ]; then
			sudo yum -y groupinstall 'Development tools'
		else
			echoBlue "Skip Development tools"
		fi
	fi
	for app in vim jq awk sed man tmux screen git curl wget basename tput gpg tree finger nload telnet cmake dirmngr clang
	do
		checkBinPath $app && echoBlue "Found $app" && continue
		echoBlue "Installing $app."
		if [[ $os == CentOS* ]]; then
			sudo yum -y install $app
		elif [[ $os == Ubuntu* ]]; then
			sudo apt-get -y install $app
		elif [[ $os == "Darwin" ]]; then
			brew install $app
		fi
	done
	# Check unbuffer.
	checkBinPath "unbuffer"
	ret=$?
	if [ $ret == "0" ]; then
		echoBlue "Skip unbuffer."
	else
		if [[ $os == CentOS* ]]; then
			sudo yum -y install expect
		elif [[ $os == Ubuntu* ]]; then
			sudo apt-get -y install expect-dev
		elif [[ $os == "Darwin" ]]; then
			brew install homebrew/dupes/expect
		fi
	fi
	# Other library.
	if [[ $os == CentOS* ]]; then
		sudo yum -y install lapack lapack-devel blas blas-devel libxslt-devel libxslt libxml2-devel libxml2 ImageMagick ImageMagick-devel libpng-devel gcc gcc-java libgcj libgcj-devel gcc-c++ bzip2-devel
	elif [[ $os == Ubuntu* ]]; then
		sudo apt-get -y install liblapack3gf liblapack-dev libblas3gf libblas-dev libxslt1-dev libxslt1.1 libxml2-dev libxml2 gfortran imagemagick imagemagick-dev libpng-dev pdftk libbz2-dev
	elif [[ $os == "Darwin" ]]; then
		brew tap homebrew/science
		brew tap homebrew/python
		brew install python lapack openblas pillow imagemagick graphviz py2cairo qt pyqt mysql-connector-c
		brew install cairo --without-x
		brew install numpy --with-openblas
		brew install scipy --with-openblas
	fi
else
	echoRed "-------- Skip installing system tools --------"
fi

# G++ 6.3
# echoGreen "-------- Checking G++ --------"
# checkNewerBinVersion "g++" "g++ (GCC) 6."
# ret=$?
# if [ $ret == "0" ]; then
# 	echoBlue "Skip G++"
# else
# 	echoBlue "Install G++"
# 	filename=$(basename $( ls $DIR/archived/gcc-* ))
# 	cp -v $DIR/archived/$filename $USER_ARCHIVED/
# 	cd $USER_ARCHIVED
# 	tar -xf $filename
# 	dirname=${filename%.tar.gz}
# 	cd $USER_ARCHIVED/$dirname
# 	echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL > /dev/null"
# 	$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL > /dev/null || abort "configure failed"
# 	echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
# 	make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null
# fi

# Basic settings.
git config --global color.ui auto

echoGreen "-------- Installing RVM --------"
checkExactBinPath "rvm" $HOME/.rvm/bin/rvm
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip RVM."
else
	gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
	curl -sSL https://get.rvm.io | bash -s stable
	if [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
		echoBlue "source $HOME/.rvm/scripts/rvm"
		source "$HOME/.rvm/scripts/rvm"
	fi
fi
assertBinPath "rvm"

isGFWFucked
GFWFucked=$?

RUBY_VER="2.3"
rvm use $RUBY_VER
echoGreen "-------- Installing Ruby $RUBY_VER --------"
checkExactBinPath "ruby" $HOME/.rvm/rubies/ruby-$RUBY_VER*/bin/ruby
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip Ruby."
else
	echoBlue "Update RVM before installing ruby."
	rvm get stable
	# Change rvm source code image to taobao for China.
	if [ $GFWFucked == "1" ]; then
		sed -i.bak 's!http://cache.ruby-lang.org/pub/ruby!https://ruby.taobao.org/mirrors/ruby!' $HOME/.rvm/config/db
		echoBlue "rvm install $RUBY_VER --disable-binary"
		rvm install $RUBY_VER --disable-binary
	else
		echoBlue "rvm install $RUBY_VER"
		rvm install $RUBY_VER
	fi
fi
rvm use $RUBY_VER
checkBinVersion "ruby" $RUBY_VER || abort "Ruby version is still not $RUBY_VER"
# Change rvm image to taobao for China.
if [ $GFWFucked == "1" ]; then
	gem sources --add https://ruby.taobao.org/ --remove https://rubygems.org/
fi

echoGreen "-------- Installing PhantomJS --------"
checkExactBinPath "phantomjs" $USER_INSTALL/bin/phantomjs
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip PhantomJS"
else
	filename=$(basename $( ls $DIR/archived/phantomjs-* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	dirname=${filename%.tar.bz2}
	cd $USER_ARCHIVED/$dirname
	echoBlue "cp -v bin/phantomjs $USER_INSTALL/bin/phantomjs"
	cp -v bin/phantomjs $USER_INSTALL/bin/phantomjs
fi
assertBinPath "phantomjs"

PYTHON_VER="2.7"
echoGreen "-------- Installing Python --------"
if [[ $os != "Darwin" ]]; then
	filename=$(basename $( ls $DIR/archived/Python-* ))
	checkExactBinPath "python" $USER_INSTALL/bin/python
	ret=$?
	if [ $ret == "0" ] || [ $os == "Darwin" ]; then
		echoBlue "Skip Python."
	else
		cp -v $DIR/archived/$filename $USER_ARCHIVED/
		cd $USER_ARCHIVED
		tar -xf $filename
		dirname=${filename%.tgz}
		cd $USER_ARCHIVED/$dirname
		echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null"
		$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null || abort "configure failed"
		echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
		make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null || abort "Make python failed"
	fi
else
	echoBlue "Skip python."
fi
checkBinVersion "python" $PYTHON_VER || abort "Python version is still not $PYTHON_VER"

# Install PIP
echoGreen "-------- Installing PIP and Py lib --------"
if [[ $os != "Darwin" ]]; then
	checkExactBinPath "pip" $USER_INSTALL/bin/pip
	ret=$?
	if [ $ret == "0" ]; then
		echoBlue "Skip pip."
	else
		echoBlue "python $DIR/archived/get-pip.py"
		python $DIR/archived/get-pip.py
	fi
else
	echoBlue "Skip pip."
fi

echoGreen "-------- Installing Node.js --------"
checkExactBinPath "node" $USER_INSTALL/bin/node
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip Nodejs."
else
	# Copy system libs for python
	ln -sf /usr/lib64/python*/lib-dynload/bz2.so $USER_INSTALL/lib/python$PYTHON_VER/
	for filehead in node-v7 node-v6 node-v5 node-v4 node-v0
	do
		filename=$(basename $( ls $DIR/archived/$filehead* ))
		echoBlue "Installing $filename"
		cp -v $DIR/archived/$filename $USER_ARCHIVED/
		cd $USER_ARCHIVED
		tar -xf $filename
		rm $USER_ARCHIVED/$filename
		dirname=$(basename $( ls $USER_ARCHIVED | grep '^node-' ))
		dirname=${dirname%.tar.gz}
		cd $USER_ARCHIVED/$dirname
		echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL > /dev/null"
		$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL > /dev/null || abort "configure failed"
		echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
		make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null
		ret=$?
		if [ $ret == "0" ]; then
			break
		fi
		echoRed "Make failed, skip installing $filename"
		echoBlue "rm -rf $USER_ARCHIVED/$filehead*"
		rm -rf $USER_ARCHIVED/$dirname
	done
fi
assertBinPath "node"
assertBinPath "npm"
echoGreen "-------- Installing npm utilities --------"
for app in tmux-cpu tmux-mem
do
	checkBinPath $app
	ret=$?
	if [ $ret == "0" ]; then
		echoBlue "Skip $app."
	else
		echoBlue "Installing $app."
		npm install -g $app
	fi
done

echoGreen "-------- Installing Java 8 -------"
javaVer=`java -version 2>&1 | grep 'java version'`
echoBlue "Current Java version:$javaVer"
if [[ $javaVer == *1.8.* ]]; then
	echoBlue "Current JAVA:$javaVer"
elif [[ $os == "Darwin" ]]; then
	echoRed "Current JAVA:$javaVer, Java should be manually install on MacOSX."
else
	filename=$(basename $( ls $DIR/archived/jdk-8u* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	rm $filename
fi

MVN_VER="3.3"
echoGreen "-------- Installing Maven --------"
filename=$(basename $( ls $DIR/archived/apache-maven-* ))
checkBinVersion "mvn" $MVN_VER
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip maven"
else
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	rm $filename
	source $HOME/.bashrc
fi
checkBinVersion "mvn" $MVN_VER || abort "Maven version is still not $MVN_VER"

echoGreen "-------- Installing libsodium --------"
if [[ -f $USER_INSTALL/lib/libsodium.dylib && $os == 'Darwin' ]]; then
	echoBlue "Skip libsodium for macOS"
elif [[ -f $USER_INSTALL/lib/libsodium.so ]]; then
	echoBlue "Skip libsodium"
else
	filename=$(basename $( ls $DIR/archived/libsodium-* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	rm $filename
	dirname=${filename%.tar.gz}
	cd $USER_ARCHIVED/$dirname
	echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null"
	$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null || abort "configure failed"
	echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
	make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null || abort "make failed"
fi

echoGreen "-------- Installing ZeroMQ --------"
if [[ -f $USER_INSTALL/lib/libzmq.dylib && $os == 'Darwin' ]]; then
	echoBlue "Skip zeromq for macOS"
elif [[ -f $USER_INSTALL/lib/libzmq.so ]]; then
	echoBlue "Skip zeromq"
else
	filename=$(basename $( ls $DIR/archived/zeromq-* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	rm $filename
	dirname=${filename%.tar.gz}
	cd $USER_ARCHIVED/$dirname
	export sodium_CFLAGS="-I$USER_INSTALL/include"
	export sodium_LIBS="-L$USER_INSTALL/lib"
	export CFLAGS=$(pkg-config --cflags libsodium)
	export LDFLAGS=$(pkg-config --libs libsodium)
	echoBlue "$USER_ARCHIVED/$dirname/autogen.sh > /dev/null"
	$USER_ARCHIVED/$dirname/autogen.sh > /dev/null || abort "autogen failed"
	echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null"
	$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL > /dev/null || abort "configure failed"
	echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
	make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null || abort "make failed"
fi

echoGreen "-------- Installing jzmq --------"
if [[ -f $USER_INSTALL/lib/libjzmq.dylib && $os == 'Darwin' ]]; then
	echoBlue "Skip jzmq for macOS"
elif [[ -f $USER_INSTALL/lib/libjzmq.so ]]; then
	echoBlue "Skip jzmq"
else
	filename=$(basename $( ls $DIR/archived/jzmq-* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	unzip -o $filename
	rm $filename
	dirname=${filename%.zip}/jzmq-jni
	cd $USER_ARCHIVED/$dirname
	export CFLAGS=$(pkg-config --cflags libsodium)
	export LDFLAGS=$(pkg-config --libs libsodium)
	echoBlue "$USER_ARCHIVED/$dirname/autogen.sh > /dev/null"
	$USER_ARCHIVED/$dirname/autogen.sh > /dev/null || abort "autogen failed"
	echoBlue "$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL --with-zeromq=$USER_INSTALL > /dev/null"
	$USER_ARCHIVED/$dirname/configure --prefix=$USER_INSTALL --exec-prefix=$USER_INSTALL --with-zeromq=$USER_INSTALL > /dev/null || abort "configure failed"
	echoBlue "make install -j $MAKE_CORE_NUM > /dev/null"
	make install -j $MAKE_CORE_NUM > /dev/null || make install > /dev/null || abort "make failed"
fi

echoGreen "-------- Installing Nanomsg --------"
checkBinPath "nanocat"
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip nanomsg"
else
	filename=$(basename $( ls $DIR/archived/nanomsg-* ))
	cp -v $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	tar -xf $filename
	rm $filename
	dirname=${filename%.tar.gz}
	cd $USER_ARCHIVED/$dirname
	builddir=$USER_ARCHIVED/$dirname/build
	mkdir $builddir
	cd $builddir
	cmake $USER_ARCHIVED/$dirname > /dev/null || abort "cmake configure failed"
	echoBlue "cmake --build $builddir"
	cmake --build $builddir > /dev/null || abort "cmake build failed"
	echoBlue "ctest $builddir > /dev/null"
	ctest $builddir > /dev/null || abort "ctest failed"
	echoBlue "cmake -DCMAKE_INSTALL_PREFIX:PATH=$USER_INSTALL $builddir"
	cmake -DCMAKE_INSTALL_PREFIX:PATH=$USER_INSTALL $builddir || abort "cmake install failed"
	echoBlue "make all install"
	make all install || abort "make install failed"
	ln -v -sf $USER_INSTALL/lib64/libnanomsg* $USER_INSTALL/lib/
fi

echoGreen "-------- Installing wkhtmltox --------"
checkBinPath "wkhtmltopdf"
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip wkhtmltox"
else
	filename=$(basename $( ls $DIR/archived/wkhtmltox-* ))
	tar xf $DIR/archived/$filename -C $USER_INSTALL --strip 1 wkhtmltox/
fi

echoGreen "-------- Installing pdftk --------"
checkBinPath "pdftk"
ret=$?
if [ $ret == "0" ]; then
	echoBlue "Skip pdftk"
else
	filename=$(basename $( ls $DIR/archived/pdftk-* ))
	cp $DIR/archived/$filename $USER_ARCHIVED/
	cd $USER_ARCHIVED
	unzip -o $USER_ARCHIVED/$filename > /dev/null || abort "Unzip pdftk failed"
	dirname=$(basename $USER_ARCHIVED/pdftk-*-dist)
	cd $USER_ARCHIVED/$dirname/pdftk
	if [[ $os == "CentOS Linux release 7"* ]]; then
		echoRed "Installing pdftk is not implemented on $os."
	elif [[ $os == CentOS* ]]; then
		echoBlue "make -f Makefile.Redhat"
		cd $USER_ARCHIVED/$dirname/pdftk/
		make -f $USER_ARCHIVED/$dirname/pdftk/Makefile.Redhat 2>&1 > /dev/null || abort "Making pdftk failed"
		echo "cp $USER_ARCHIVED/$dirname/pdftk/pdftk $USER_INSTALL/bin/"
		cp $USER_ARCHIVED/$dirname/pdftk/pdftk $USER_INSTALL/bin/
	else
		echoRed "Installing pdftk is not implemented on $os."
	fi
fi

echoGreen "-----------------------------------------------"
echoGreen "Environment set up, reopen bash to take effect."

cd $PWD

echo "Installing OpenCV"
echo "Removing any pre-installed ffmpeg and x264"
sudo apt-get -y remove ffmpeg x264 libx264-dev
echo "Installing Dependenices"
sudo apt-get -y install libopencv-dev
sudo apt-get -y install build-essential checkinstall cmake pkg-config yasm
sudo apt-get -y install libtiff4-dev libjpeg-dev libjasper-dev
sudo apt-get -y install libavcodec-dev libavformat-dev libswscale-dev libdc1394-22-dev libxine-dev libgstreamer0.10-dev libgstreamer-plugins-base0.10-dev libv4l-dev
sudo apt-get -y install python-dev python-numpy
sudo apt-get -y install libtbb-dev
sudo apt-get -y install libqt4-dev libgtk2.0-dev
sudo apt-get -y install libfaac-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev libtheora-dev libvorbis-dev libxvidcore-dev
sudo apt-get -y install x264 v4l-utils ffmpeg
sudo apt-get -y install libgtk2.0-dev
sudo apt-get -y install stow

echo "Checking Whether Alternative OpenCV Package exists"
FILEPKG=$(find . -maxdepth 1 -type f -printf '%f\n' | grep opencv | tail -n 1)
echo $FILEPKG
if [[ -z "$FILEPKG" ]]; then
	if [[ ! -e "opencv" ]]; then
		echo "Cloning lastest opencv from  https://github.com/itseez/opencv"
		git clone https://github.com/itseez/opencv
	else
		echo "Found existing clone of opencv, updating..."
		cd opencv
		git fetch origin master
		git checkout master
		git pull origin master
		cd ..
	fi
	PKGDIR="opencv"
else
	echo "Alternative OpenCV Package Found!"
	PKGDIR=`echo $FILEPKG | sed 's/.zip//g'`
	unzip $FILEPKG -d $PKGDIR
	PKGDIR=${PKGDIR}/$(ls $PKGDIR | tail -n 1)
	sleep 1
fi
echo "Installing OpenCV"
cd $PKGDIR

mkdir build
cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D WITH_TBB=ON -D BUILD_NEW_PYTHON_SUPPORT=ON -D WITH_V4L=ON -D INSTALL_C_EXAMPLES=ON -D INSTALL_PYTHON_EXAMPLES=ON -D BUILD_EXAMPLES=ON -D WITH_QT=ON -D WITH_OPENGL=ON ..
make -j4
sudo make install
sudo sh -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/opencv.conf'
sudo ldconfig
echo "OpenCV is ready to be used"



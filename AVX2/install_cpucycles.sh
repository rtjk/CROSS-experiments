# copy-and-paste into a terminal to install and configure libcpucycles
wget -m https://cpucycles.cr.yp.to/libcpucycles-latest-version.txt
version=$(cat cpucycles.cr.yp.to/libcpucycles-latest-version.txt)
wget -m https://cpucycles.cr.yp.to/libcpucycles-$version.tar.gz
tar -xzf cpucycles.cr.yp.to/libcpucycles-$version.tar.gz
cd libcpucycles-$version
sed -i '/default-mach/d' cpucycles/options
export LD_LIBRARY_PATH="$HOME/lib"
export LIBRARY_PATH="$HOME/lib"
export CPATH="$HOME/include"
export PATH="$HOME/bin:$PATH"
./configure --prefix=$HOME
make -j $(nproc) install
echo '*' > ".gitignore"
cd ..
rm  -rf cpucycles.cr.yp.to
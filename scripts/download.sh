#!/usr/bin/bash
#------------------------------------------------------------------------------
#
#	download.sh
#
#		m68k-elfx toolchain ビルドに必要なファイルをまとめてダウンロード
#
#------------------------------------------------------------------------------
#
#	Copyright (C) 2022 Yosshin(@yosshin4004)
#	Copyright (C) 2023 Yuichi Nakamura (@yunkya2)
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#	    http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
#------------------------------------------------------------------------------

# 共通設定を読み込み

. scripts/common.sh

# ディレクトリ作成
mkdir -p ${DOWNLOAD_DIR}
cd ${DOWNLOAD_DIR}

#-----------------------------------------------------------------------------
# binutils のダウンロード
#-----------------------------------------------------------------------------

if ! [ -f "${BINUTILS_ARCHIVE}" ]; then
    wget ${BINUTILS_URL}
fi
if [ $(sha512sum ${BINUTILS_ARCHIVE} | awk '{print $1}') != ${BINUTILS_SHA512SUM} ]; then
	echo "SHA512SUM verification of ${BINUTILS_ARCHIVE} failed!"
	exit 1
fi

#-----------------------------------------------------------------------------
# gcc のダウンロード
#-----------------------------------------------------------------------------

if ! [ -f "${GCC_ARCHIVE}" ]; then
    wget ${GCC_URL}
fi
if [ $(sha512sum ${GCC_ARCHIVE} | awk '{print $1}') != ${GCC_SHA512SUM} ]; then
	echo "SHA512SUM verification of ${GCC_ARCHIVE} failed!"
	exit 1
fi

# gcc ビルドに必要なライブラリのダウンロード
# gcc ソースコード内にあるダウンロード用スクリプトのみを抽出して実行する

if ! [ -f gmp-* -a -f mpfr-* -a -f mpc-* -a -f isl-* ]; then
	tar xvf ${GCC_ARCHIVE} --wildcards ${GCC_DIR}/contrib/\*prerequisites\* ${GCC_DIR}/gcc/BASE-VER
	echo "Download prerequisites"
	(cd gcc-${GCC_VERSION}; contrib/download_prerequisites) || exit 1
	mv ${GCC_DIR}/*.tar.* .
	rm -rf ${GCC_DIR}
fi

#-----------------------------------------------------------------------------
# newlib のダウンロード
#-----------------------------------------------------------------------------

if ! [ -f "${NEWLIB_ARCHIVE}" ]; then
    wget ${NEWLIB_URL}
fi
if [ $(sha512sum ${NEWLIB_ARCHIVE} | awk '{print $1}') != ${NEWLIB_SHA512SUM} ]; then
	echo "SHA512SUM verification of ${NEWLIB_ARCHIVE} failed!"
	exit 1
fi

#------------------------------------------------------------------------------
# 正常終了
#------------------------------------------------------------------------------

echo ""
echo "-----------------------------------------------------------------------------"
echo "File download is completed successfully."
echo "-----------------------------------------------------------------------------"
echo ""
exit 0

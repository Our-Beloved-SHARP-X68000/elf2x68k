#!/bin/bash
#------------------------------------------------------------------------------
#
#	install-xclib.sh
#
#		XC ライブラリを m68k-xelf toolchainにインストールする
#
#------------------------------------------------------------------------------
#
#	Copyright (C) 2024 Yuichi Nakamura (@yunkya2)
#
#	Based upon xdev68k-utils.sh
#	Copyright (C) 2022 Yosshin(@yosshin4004)
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

#-----------------------------------------------------------------------------
# 設定
#-----------------------------------------------------------------------------

# エラーが起きたらそこで終了させる。
set -e

ROOT_DIR="${PWD}"
INSTALLER_TEMP_DIR="${ROOT_DIR}/installer_temp"
INSTALL_DIR="${ROOT_DIR}/xc-elf"
DOWNLOAD_DIR="${ROOT_DIR}/download"

LHA_ARCHIVE="release-20211125.zip"
LHA_SHA512SUM="e75dc606d7637f2c506072f2f44eda69da075a57ad2dc76f54e41b1d39d34ca01410317cc6538f8ea42f4da81ca14889df1195161f4e305d2d67189ec8e60e24"
LHA_URL="https://github.com/jca02266/lha/archive/refs/tags/${LHA_ARCHIVE}"

XC_ARCHIVE="XC2102_02.LZH"
XC_SHA512SUM="c06339be8bf3251bb0b4a37365aa013a6083294edad17a3c4fafc35ab2cd2656260454642b1fa89645e3d796fe6c0ba67ce7f541d43e0a14b6529ce5aa113ede"
XC_URL="http://retropc.net/x68000/software/sharp/xc21/${XC_ARCHIVE}"

#-----------------------------------------------------------------------------
# 必要なファイルをダウンロードする
#-----------------------------------------------------------------------------

mkdir -p ${DOWNLOAD_DIR}
cd ${DOWNLOAD_DIR}

wget -nc ${LHA_URL}
if [ $(sha512sum ${LHA_ARCHIVE} | awk '{print $1}') != ${LHA_SHA512SUM} ]; then
	echo "SHA512SUM verification of ${LHA_ARCHIVE} failed!"
	exit 1
fi

wget -nc ${XC_URL}
if [ $(sha512sum ${XC_ARCHIVE} | awk '{print $1}') != ${XC_SHA512SUM} ]; then
	echo "SHA512SUM verification of ${XC_ARCHIVE} failed!"
	exit 1
fi

rm -rf ${INSTALLER_TEMP_DIR}
mkdir -p ${INSTALLER_TEMP_DIR}

#-----------------------------------------------------------------------------
# lha コマンドをソースからビルド
#-----------------------------------------------------------------------------

cd ${INSTALLER_TEMP_DIR}
LHA=${DOWNLOAD_DIR}/lha

if ! [ -f ${LHA} ]; then
	unzip ${DOWNLOAD_DIR}/${LHA_ARCHIVE}
	cd lha-release-20211125/
	# MinGW で lha のビルドに失敗する問題の修正
	patch -p1 << EOS
diff --git a/src/header.c b/src/header.c
index ecd585d..2de57e8 100644
--- a/src/header.c
+++ b/src/header.c
@@ -69,6 +69,7 @@ calc_sum(p, len)
 
 static void
 _skip_bytes(len)
+    int len;
 {
     if (len < 0) {
       error("Invalid header: %d", len);
diff --git a/src/lhext.c b/src/lhext.c
index 0c95e09..ce5b99a 100644
--- a/src/lhext.c
+++ b/src/lhext.c
@@ -203,15 +203,7 @@ symlink_with_make_path(realname, name)
     const char     *realname;
     const char     *name;
 {
-    int l_code;
-
-    l_code = symlink(realname, name);
-    if (l_code < 0) {
-        make_parent_path(name);
-        l_code = symlink(realname, name);
-    }
-
-    return l_code;
+    return -1; /* not supported */
 }
 
 /* ------------------------------------------------------------------------ */
EOS
	autoreconf -is
	sh ./configure
	make
	cp -p src/lha ${LHA}
fi

#-----------------------------------------------------------------------------
# C Compiler PRO-68K ver2.1（XC）から include/ lib/ をインストール
#-----------------------------------------------------------------------------

cd ${INSTALLER_TEMP_DIR}
XC=${INSTALLER_TEMP_DIR}/XC

${LHA} -x -w=${XC} ${DOWNLOAD_DIR}/${XC_ARCHIVE}

rm -rf ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}/include
mkdir -p ${INSTALL_DIR}/include.sjis
mkdir -p ${INSTALL_DIR}/lib

# ヘッダファイルのファイル名を小文字に変換
# ヘッダファイル末尾の EOF（文字コード 0x1a）を除去
# ヘッダファイルの文字コードをUTF-8に変換
for f in ${XC}/INCLUDE/* ; do \
	cat $f | tr -d \\032 | iconv -f cp932 -t utf-8 > ${INSTALL_DIR}/include/`basename $f | tr A-Z a-z` ;\
done
# include.sjis/ の文字コードはSJISのまま
for f in ${XC}/INCLUDE/* ; do \
	cat $f | tr -d \\032 > ${INSTALL_DIR}/include.sjis/`basename $f | tr A-Z a-z` ;\
done

# ライブラリファイルののファイル名を XXXLIB.L から libXXX.a に変換
# ライブラリファイルをELF形式に変換
for f in ${XC}/LIB/* ; do \
	${ROOT_DIR}/bin/x68k2elf.py $f ${INSTALL_DIR}/lib/lib`basename $f .L | sed 's/LIB//' | tr A-Z a-z`.a ;\
done

# libdos.a libiocs.a libbas.a は newlib 環境にもインストール
cp ${INSTALL_DIR}/lib/lib{dos,iocs,bas}.a ${ROOT_DIR}/m68k-elf/lib
for f in audio class gpib graph image mouse music music3 sprite stick doslib iocslib basic basic0; do
	cat > ${ROOT_DIR}/m68k-elf/sys-include/${f}.h <<- EOS
	#ifdef __cplusplus
	extern "C" {
	#endif
	EOS
	cat ${INSTALL_DIR}/include/${f}.h >> ${ROOT_DIR}/m68k-elf/sys-include/${f}.h
	cat >> ${ROOT_DIR}/m68k-elf/sys-include/${f}.h <<- EOS
	#ifdef __cplusplus
	}
	#endif
	EOS
done

#-----------------------------------------------------------------------------
# XC 用 specs ファイルをインストール
#-----------------------------------------------------------------------------

cd ${ROOT_DIR}
SPECS_DIR=${ROOT_DIR}/m68k-elf/lib
TMPL=${SPECS_DIR}/xc.specs.tmpl
PATHCONV="s|\${TOOLCHAIN_PATH}|${ROOT_DIR}|"
INPUTCONV="s|\${INPUT_CHARSET}||"
SJISCONV="s|\${SJIS}||"

# MinGW ではフルパスを Windows 形式に変換
if [ "${MSYSTEM}" = "MINGW64" ]; then
	ROOT_DIR_WIN=`cygpath -m "${ROOT_DIR}"`
	PATHCONV="s|\${TOOLCHAIN_PATH}|${ROOT_DIR_WIN}|"
fi

# xc.specs           浮動小数点演算を FLOATn.X で実行する
FLOATCONV="s|\${FLOAT}|floatfnc|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.specs
# xc.floateml.specs  浮動小数点演算をライブラリで実行する
FLOATCONV="s|\${FLOAT}|floateml|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.floateml.specs
# xc.floatdrv.specs  浮動小数点演算をコプロセッサ命令で実行する
FLOATCONV="s|\${FLOAT}|floatdrv|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.floatdrv.specs

# ファイルの文字コードをSJISにしたバージョン
INPUTCONV="s|\${INPUT_CHARSET}|-finput-charset=cp932|"
SJISCONV="s|\${SJIS}|.sjis|"
# xc.sjis.specs           浮動小数点演算を FLOATn.X で実行する
FLOATCONV="s|\${FLOAT}|floatfnc|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.sjis.specs
# xc.sjis.floateml.specs  浮動小数点演算をライブラリで実行する
FLOATCONV="s|\${FLOAT}|floateml|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.sjis.floateml.specs
# xc.sjis.floatdrv.specs  浮動小数点演算をコプロセッサ命令で実行する
FLOATCONV="s|\${FLOAT}|floatdrv|"
cat ${TMPL} | sed -e ${PATHCONV} -e ${FLOATCONV} -e ${INPUTCONV} -e ${SJISCONV} > ${SPECS_DIR}/xc.sjis.floatdrv.specs

#------------------------------------------------------------------------------
# 正常終了
#------------------------------------------------------------------------------
# 作業用テンポラリディレクトリの除去
rm -rf ${INSTALLER_TEMP_DIR}

# 正常終了した旨を TTY 出力
echo ""
echo "-----------------------------------------------------------------------------"
echo "The installation process is completed successfully."
echo "-----------------------------------------------------------------------------"
echo ""

exit 0

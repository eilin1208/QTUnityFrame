#!/bin/sh

printUsage() {
  echo "$0 <sqlitestudio build output directory> <qmake path> [dmg|dist|dist_full]"
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  printUsage
  exit 1
fi

if [ "$#" -eq 3 ] && [ "$3" != "dmg" ] && [ "$3" != "dist" ] && [ "$3" != "dist_plugins" ] && [ "$3" != "dist_full" ]; then
  printUsage
  exit 1
fi

qt_deploy_bin="${2/qmake/macdeployqt}"
$qt_deploy_bin -v >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
  echo "macdeployqt program missing!"
  exit 1
fi

cd $1/SQLiteStudio

rm -rf SQLiteStudio.app/Contents/Frameworks
rm -rf SQLiteStudio.app/Contents/PlugIns
rm -f SQLiteStudio.app/Contents/MacOS/sqlitestudiocli
rm -f SQLiteStudio.app/Contents/Resources/qt.conf

mkdir SQLiteStudio.app/Contents/Frameworks

cp -RP plugins SQLiteStudio.app/Contents
mv SQLiteStudio.app/Contents/plugins SQLiteStudio.app/Contents/PlugIns

cp -RP lib*SQLiteStudio*.dylib SQLiteStudio.app/Contents/Frameworks

qtcore_path=`otool -L sqlitestudiocli | grep QtCore | awk '{print $1;}'`
new_qtcore_path="@loader_path/../Frameworks/QtCore.framework/Versions/5/QtCore"

cp -P sqlitestudiocli SQLiteStudio.app/Contents/MacOS
install_name_tool -change libcoreSQLiteStudio.1.dylib "@loader_path/../Frameworks/libcoreSQLiteStudio.1.dylib" SQLiteStudio.app/Contents/MacOS/sqlitestudiocli
install_name_tool -change $qtcore_path $new_qtcore_path SQLiteStudio.app/Contents/MacOS/sqlitestudiocli

cp -RP ../../../lib/*.dylib SQLiteStudio.app/Contents/Frameworks

if [ "$3" == "dmg" ]; then
    $qt_deploy_bin SQLiteStudio.app -dmg
elif [ "$3" == "dist" ] || [ "$3" == "dist_plugins" ] || [ "$3" == "dist_full" ]; then
    if [ "$3" == "dist" ] || [ "$3" == "dist_full" ]; then
        $qt_deploy_bin SQLiteStudio.app -dmg

        cd $1/SQLiteStudio
        VERSION=`SQLiteStudio.app/Contents/MacOS/sqlitestudiocli -v | awk '{print $2}'`

        mv SQLiteStudio.dmg sqlitestudio-$VERSION.dmg

        # App
        echo "Building incremental update package: sqlitestudio-$VERSION.zip"
        cp -R SQLiteStudio.app app
        cd app/Contents
        if [ "$3" == "dist" ]; then
            rm -rf PlugIns
            rm -rf Frameworks/Qt*.framework
        fi
        find Frameworks -type l -exec rm -f {} \;
        cd ..
        zip -r sqlitestudio-$VERSION.zip *
        mv sqlitestudio-$VERSION.zip ..
        cd ..
        rm -rf app
    else
        $qt_deploy_bin SQLiteStudio.app
    fi

    # Plugins
    mkdir Contents Contents/PlugIns
    SQLiteStudio.app/Contents/MacOS/sqlitestudio --list-plugins | while read line
    do
    PLUGIN=`echo $line | awk '{print $1}'`
    PLUGIN_VER=`echo $line | awk '{print $2}'`
    if [ -f SQLiteStudio.app/Contents/PlugIns/lib$PLUGIN.dylib ]; then
        echo "Building plugin package: $PLUGIN-$PLUGIN_VER.tar.gz"
        cp SQLiteStudio.app/Contents/PlugIns/lib$PLUGIN.dylib Contents/PlugIns
        zip -r $PLUGIN\-$PLUGIN_VER.zip Contents
    fi
    rm -f Contents/PlugIns/*
    done
    rm -rf Contents
    echo "Done."
else
    $qt_deploy_bin SQLiteStudio.app
fi

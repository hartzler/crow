#!/bin/bash
uname | grep -q "Linux"
os_linux=$?
if [ "$os_linux" == "0" ]; then
  rake && ./xulrunner-sdk/bin/xulrunner build/xul/application.ini -jsconsole
else
  rake && ./build/Crow.app/Contents/MacOS/xulrunner -jsconsole
fi

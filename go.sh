#!/bin/sh
#rake && open build/Crow.app --args -jsconsole
rake && ./build/Crow.app/Contents/MacOS/xulrunner -jsconsole
#./build/Crow.app/Contents/MacOS/xulrunner 

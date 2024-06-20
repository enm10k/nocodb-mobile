#!/bin/sh

cd ~/Library/Android/sdk/emulator
./emulator -avd $(emulator -list-avds | head -n 1) &

